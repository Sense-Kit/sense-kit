import Foundation

#if os(iOS) && canImport(CoreMotion)
import CoreMotion
#endif

public enum MotionAuthorizationState: String, Codable, Equatable, Sendable {
    case notDetermined = "not_determined"
    case authorized
    case denied
    case restricted
    case unavailable
}

public enum WakeCollectorStatus: String, Codable, Equatable, Sendable {
    case inactive
    case permissionRequired = "permission_required"
    case permissionDenied = "permission_denied"
    case unavailable
    case running
}

@MainActor
protocol MotionCollectorBuilding: AnyObject {
    func makeMotionCollector(signalHandler: @escaping SignalHandler, clock: Clock) -> any ContextSignalCollector
}

@MainActor
protocol PowerCollectorBuilding: AnyObject {
    func makePowerCollector(signalHandler: @escaping SignalHandler) -> any ContextSignalCollector
}

@MainActor
protocol MotionAuthorizationProviding: AnyObject {
    func status() -> MotionAuthorizationState
}

@MainActor
final class DefaultMotionCollectorFactory: MotionCollectorBuilding {
    func makeMotionCollector(signalHandler: @escaping SignalHandler, clock: Clock) -> any ContextSignalCollector {
        MotionCollector(signalHandler: signalHandler, clock: clock)
    }
}

@MainActor
final class DefaultPowerCollectorFactory: PowerCollectorBuilding {
    func makePowerCollector(signalHandler: @escaping SignalHandler) -> any ContextSignalCollector {
        DevicePowerCollector(signalHandler: signalHandler)
    }
}

@MainActor
final class DefaultMotionAuthorizationProvider: MotionAuthorizationProviding {
    func status() -> MotionAuthorizationState {
        #if os(iOS) && canImport(CoreMotion)
        guard CMMotionActivityManager.isActivityAvailable() else {
            return .unavailable
        }

        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
        #else
        return .unavailable
        #endif
    }
}

@MainActor
public final class PassiveWakeRuntimeController {
    private let store: RuntimeStore
    private let settingsStore: SettingsStore
    private let deliveryClient: DeliveryClient
    private let clock: Clock
    private let motionCollectorFactory: MotionCollectorBuilding
    private let powerCollectorFactory: PowerCollectorBuilding
    private let motionAuthorizationProvider: MotionAuthorizationProviding

    private var motionCollector: (any ContextSignalCollector)?
    private var powerCollector: (any ContextSignalCollector)?
    private var activeConfiguration: RuntimeConfiguration?
    private var collectorStatus: WakeCollectorStatus = .inactive

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
        self.motionCollectorFactory = DefaultMotionCollectorFactory()
        self.powerCollectorFactory = DefaultPowerCollectorFactory()
        self.motionAuthorizationProvider = DefaultMotionAuthorizationProvider()
    }

    init(
        store: RuntimeStore,
        settingsStore: SettingsStore,
        deliveryClient: DeliveryClient = DeliveryClient(),
        clock: Clock = SystemClock(),
        motionCollectorFactory: MotionCollectorBuilding = DefaultMotionCollectorFactory(),
        powerCollectorFactory: PowerCollectorBuilding = DefaultPowerCollectorFactory(),
        motionAuthorizationProvider: MotionAuthorizationProviding = DefaultMotionAuthorizationProvider()
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.deliveryClient = deliveryClient
        self.clock = clock
        self.motionCollectorFactory = motionCollectorFactory
        self.powerCollectorFactory = powerCollectorFactory
        self.motionAuthorizationProvider = motionAuthorizationProvider
    }

    public func refresh(configuration: RuntimeConfiguration) async throws -> WakeCollectorStatus {
        guard isMotionCollectionEnabled(configuration) else {
            stopCollector()
            collectorStatus = .inactive
            activeConfiguration = nil
            return collectorStatus
        }

        let authorization = motionAuthorizationProvider.status()
        switch authorization {
        case .unavailable:
            stopCollector()
            collectorStatus = .unavailable
            activeConfiguration = nil
            return collectorStatus
        case .denied, .restricted:
            stopCollector()
            collectorStatus = .permissionDenied
            activeConfiguration = nil
            return collectorStatus
        case .authorized, .notDetermined:
            if motionCollector == nil || activeConfiguration != configuration {
                stopCollector()
                motionCollector = motionCollectorFactory.makeMotionCollector(
                    signalHandler: makeSignalHandler(configuration: configuration),
                    clock: clock
                )
                powerCollector = powerCollectorFactory.makePowerCollector(
                    signalHandler: makeSignalHandler(configuration: configuration)
                )
                activeConfiguration = configuration
                await motionCollector?.start()
                await powerCollector?.start()
                try await store.appendDebugEntry(
                    DebugTimelineEntry(
                        createdAt: clock.now(),
                        category: .evaluation,
                        message: "Passive wake collectors started"
                        )
                )
            }

            collectorStatus = authorization == .authorized ? .running : .permissionRequired
            return collectorStatus
        }
    }

    public func currentStatus(configuration: RuntimeConfiguration) -> WakeCollectorStatus {
        guard isMotionCollectionEnabled(configuration) else {
            return .inactive
        }

        switch motionAuthorizationProvider.status() {
        case .authorized:
            return motionCollector == nil ? .permissionRequired : .running
        case .notDetermined:
            return .permissionRequired
        case .denied, .restricted:
            return .permissionDenied
        case .unavailable:
            return .unavailable
        }
    }

    private func stopCollector() {
        motionCollector?.stop()
        motionCollector = nil
        powerCollector?.stop()
        powerCollector = nil
    }

    private func isMotionCollectionEnabled(_ configuration: RuntimeConfiguration) -> Bool {
        configuration.enabledFeatures.contains(.wakeBrief) || configuration.enabledFeatures.contains(.drivingMode)
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
