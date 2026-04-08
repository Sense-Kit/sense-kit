import Foundation

#if os(iOS) && canImport(HealthKit)
import HealthKit
#endif

public enum HealthAuthorizationState: String, Codable, Equatable, Sendable {
    case notDetermined = "not_determined"
    case authorized
    case denied
    case unavailable
}

public enum HealthCollectorStatus: String, Codable, Equatable, Sendable {
    case inactive
    case permissionRequired = "permission_required"
    case permissionDenied = "permission_denied"
    case unavailable
    case running
}

@MainActor
protocol HealthCollectorBuilding: AnyObject {
    func makeHealthCollector(signalHandler: @escaping SignalHandler) -> any ContextSignalCollector
}

@MainActor
protocol HealthAuthorizationProviding: AnyObject {
    func status() -> HealthAuthorizationState
    func requestAuthorization() async
}

@MainActor
final class DefaultHealthCollectorFactory: HealthCollectorBuilding {
    func makeHealthCollector(signalHandler: @escaping SignalHandler) -> any ContextSignalCollector {
        HealthKitCollector(signalHandler: signalHandler)
    }
}

@MainActor
final class DefaultHealthAuthorizationProvider: HealthAuthorizationProviding {
    #if os(iOS) && canImport(HealthKit)
    private let healthStore = HKHealthStore()
    #endif

    func status() -> HealthAuthorizationState {
        #if os(iOS) && canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }

        switch healthStore.authorizationStatus(for: HKObjectType.workoutType()) {
        case .notDetermined:
            return .notDetermined
        case .sharingAuthorized:
            return .authorized
        case .sharingDenied:
            return .denied
        @unknown default:
            return .notDetermined
        }
        #else
        return .unavailable
        #endif
    }

    func requestAuthorization() async {
        #if os(iOS) && canImport(HealthKit)
        let types: Set = [HKObjectType.workoutType()]
        try? await healthStore.requestAuthorization(toShare: [], read: types)
        #endif
    }
}

@MainActor
public final class HealthRuntimeController {
    private let store: RuntimeStore
    private let settingsStore: SettingsStore
    private let deliveryClient: DeliveryClient
    private let clock: Clock
    private let healthCollectorFactory: HealthCollectorBuilding
    private let healthAuthorizationProvider: HealthAuthorizationProviding

    private var healthCollector: (any ContextSignalCollector)?
    private var activeConfiguration: RuntimeConfiguration?

    public init(
        store: RuntimeStore,
        settingsStore: SettingsStore,
        deliveryClient: DeliveryClient = DeliveryClient(),
        clock: Clock = SystemClock()
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.deliveryClient = deliveryClient
        self.clock = clock
        self.healthCollectorFactory = DefaultHealthCollectorFactory()
        self.healthAuthorizationProvider = DefaultHealthAuthorizationProvider()
    }

    init(
        store: RuntimeStore,
        settingsStore: SettingsStore,
        deliveryClient: DeliveryClient = DeliveryClient(),
        clock: Clock = SystemClock(),
        healthCollectorFactory: HealthCollectorBuilding = DefaultHealthCollectorFactory(),
        healthAuthorizationProvider: HealthAuthorizationProviding = DefaultHealthAuthorizationProvider()
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.deliveryClient = deliveryClient
        self.clock = clock
        self.healthCollectorFactory = healthCollectorFactory
        self.healthAuthorizationProvider = healthAuthorizationProvider
    }

    public func refresh(configuration: RuntimeConfiguration) async throws -> HealthCollectorStatus {
        guard configuration.enabledFeatures.contains(.workoutFollowUp) else {
            stopCollector()
            activeConfiguration = nil
            return .inactive
        }

        switch healthAuthorizationProvider.status() {
        case .unavailable:
            stopCollector()
            activeConfiguration = nil
            return .unavailable
        case .denied:
            stopCollector()
            activeConfiguration = nil
            return .permissionDenied
        case .notDetermined:
            await healthAuthorizationProvider.requestAuthorization()
            stopCollector()
            activeConfiguration = nil
            return .permissionRequired
        case .authorized:
            try await startCollectorIfNeeded(configuration: configuration)
            return .running
        }
    }

    private func startCollectorIfNeeded(configuration: RuntimeConfiguration) async throws {
        guard healthCollector == nil || activeConfiguration != configuration else { return }

        stopCollector()
        healthCollector = healthCollectorFactory.makeHealthCollector(signalHandler: makeSignalHandler(configuration: configuration))
        activeConfiguration = configuration
        await healthCollector?.start()
        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .evaluation,
                message: "Health collector started"
            )
        )
    }

    private func stopCollector() {
        healthCollector?.stop()
        healthCollector = nil
    }

    private func makeSignalHandler(configuration: RuntimeConfiguration) -> SignalHandler {
        let coordinator = makeCoordinator(configuration: configuration)
        return { signal in
            _ = try? await coordinator.handleWake(signal: signal)
        }
    }

    private func makeCoordinator(configuration: RuntimeConfiguration) -> BackgroundWakeCoordinator {
        return BackgroundWakeCoordinator(
            store: store,
            deliveryClient: deliveryClient,
            settingsStore: settingsStore,
            clock: clock
        )
    }
}
