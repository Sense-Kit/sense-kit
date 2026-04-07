import Foundation

#if os(iOS) && canImport(CoreLocation)
import CoreLocation
#endif

public enum LocationAuthorizationMode: String, Codable, Equatable, Sendable {
    case whenInUse = "when_in_use"
    case always
}

public enum LocationAuthorizationState: String, Codable, Equatable, Sendable {
    case notDetermined = "not_determined"
    case authorizedWhenInUse = "authorized_when_in_use"
    case authorizedAlways = "authorized_always"
    case denied
    case restricted
    case unavailable
}

public enum LocationCollectorStatus: String, Codable, Equatable, Sendable {
    case inactive
    case configurationRequired = "configuration_required"
    case permissionRequired = "permission_required"
    case permissionDenied = "permission_denied"
    case unavailable
    case running
}

@MainActor
protocol LocationSignalCollecting: ContextSignalCollector {
    func restoreRegionStates()
}

@MainActor
protocol LocationCollectorBuilding: AnyObject {
    func makeLocationCollector(configuration: RuntimeConfiguration, signalHandler: @escaping SignalHandler) -> any LocationSignalCollecting
}

@MainActor
protocol LocationAuthorizationProviding: AnyObject {
    func status() -> LocationAuthorizationState
    func requestAuthorization(mode: LocationAuthorizationMode)
}

@MainActor
final class DefaultLocationCollectorFactory: LocationCollectorBuilding {
    func makeLocationCollector(configuration: RuntimeConfiguration, signalHandler: @escaping SignalHandler) -> any LocationSignalCollecting {
        LocationCollector(configuration: configuration, signalHandler: signalHandler)
    }
}

@MainActor
final class DefaultLocationAuthorizationProvider: LocationAuthorizationProviding {
    #if os(iOS) && canImport(CoreLocation)
    private let manager = CLLocationManager()
    #endif

    func status() -> LocationAuthorizationState {
        #if os(iOS) && canImport(CoreLocation)
        guard CLLocationManager.locationServicesEnabled() else {
            return .unavailable
        }

        switch manager.authorizationStatus {
        case .authorizedAlways:
            return .authorizedAlways
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
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

    func requestAuthorization(mode: LocationAuthorizationMode) {
        #if os(iOS) && canImport(CoreLocation)
        switch mode {
        case .whenInUse:
            manager.requestWhenInUseAuthorization()
        case .always:
            manager.requestAlwaysAuthorization()
        }
        #endif
    }
}

@MainActor
public final class LocationRuntimeController {
    private let store: RuntimeStore
    private let settingsStore: SettingsStore
    private let snapshotEnricher: SnapshotEnricher
    private let policyEngine: PolicyEngine
    private let deliveryClient: DeliveryClient
    private let clock: Clock
    private let locationCollectorFactory: LocationCollectorBuilding
    private let locationAuthorizationProvider: LocationAuthorizationProviding

    private var locationCollector: (any LocationSignalCollecting)?
    private var activeConfiguration: RuntimeConfiguration?

    public init(
        store: RuntimeStore,
        settingsStore: SettingsStore,
        snapshotEnricher: SnapshotEnricher = SnapshotEnricher(),
        policyEngine: PolicyEngine = PolicyEngine(),
        deliveryClient: DeliveryClient = DeliveryClient(),
        clock: Clock = SystemClock()
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.snapshotEnricher = snapshotEnricher
        self.policyEngine = policyEngine
        self.deliveryClient = deliveryClient
        self.clock = clock
        self.locationCollectorFactory = DefaultLocationCollectorFactory()
        self.locationAuthorizationProvider = DefaultLocationAuthorizationProvider()
    }

    init(
        store: RuntimeStore,
        settingsStore: SettingsStore,
        snapshotEnricher: SnapshotEnricher = SnapshotEnricher(),
        policyEngine: PolicyEngine = PolicyEngine(),
        deliveryClient: DeliveryClient = DeliveryClient(),
        clock: Clock = SystemClock(),
        locationCollectorFactory: LocationCollectorBuilding = DefaultLocationCollectorFactory(),
        locationAuthorizationProvider: LocationAuthorizationProviding = DefaultLocationAuthorizationProvider()
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.snapshotEnricher = snapshotEnricher
        self.policyEngine = policyEngine
        self.deliveryClient = deliveryClient
        self.clock = clock
        self.locationCollectorFactory = locationCollectorFactory
        self.locationAuthorizationProvider = locationAuthorizationProvider
    }

    public func refresh(configuration: RuntimeConfiguration) async throws -> LocationCollectorStatus {
        let requirement = locationRequirement(for: configuration)

        switch requirement {
        case .inactive:
            stopCollector()
            activeConfiguration = nil
            return .inactive
        case .configurationRequired:
            stopCollector()
            activeConfiguration = nil
            return .configurationRequired
        case .active(let mode):
            switch locationAuthorizationProvider.status() {
            case .unavailable:
                stopCollector()
                activeConfiguration = nil
                return .unavailable
            case .denied, .restricted:
                stopCollector()
                activeConfiguration = nil
                return .permissionDenied
            case .notDetermined:
                locationAuthorizationProvider.requestAuthorization(mode: mode)
                stopCollector()
                activeConfiguration = nil
                return .permissionRequired
            case .authorizedWhenInUse:
                guard mode == .whenInUse else {
                    locationAuthorizationProvider.requestAuthorization(mode: .always)
                    stopCollector()
                    activeConfiguration = nil
                    return .permissionRequired
                }
                try await startCollectorIfNeeded(configuration: configuration)
                return .running
            case .authorizedAlways:
                try await startCollectorIfNeeded(configuration: configuration)
                return .running
            }
        }
    }

    public func currentStatus(configuration: RuntimeConfiguration) -> LocationCollectorStatus {
        switch locationRequirement(for: configuration) {
        case .inactive:
            return .inactive
        case .configurationRequired:
            return .configurationRequired
        case .active(let mode):
            switch locationAuthorizationProvider.status() {
            case .authorizedAlways:
                return locationCollector == nil ? .permissionRequired : .running
            case .authorizedWhenInUse:
                return mode == .whenInUse && locationCollector != nil ? .running : .permissionRequired
            case .notDetermined:
                return .permissionRequired
            case .denied, .restricted:
                return .permissionDenied
            case .unavailable:
                return .unavailable
            }
        }
    }

    private func startCollectorIfNeeded(configuration: RuntimeConfiguration) async throws {
        guard locationCollector == nil || activeConfiguration != configuration else { return }

        stopCollector()
        locationCollector = locationCollectorFactory.makeLocationCollector(
            configuration: configuration,
            signalHandler: makeSignalHandler(configuration: configuration)
        )
        activeConfiguration = configuration
        await locationCollector?.start()
        locationCollector?.restoreRegionStates()
        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .evaluation,
                message: "Location collector started"
            )
        )
    }

    private func stopCollector() {
        locationCollector?.stop()
        locationCollector = nil
    }

    private func makeSignalHandler(configuration: RuntimeConfiguration) -> SignalHandler {
        let coordinator = makeCoordinator(configuration: configuration)
        return { signal in
            _ = try? await coordinator.handleWake(signal: signal)
        }
    }

    private func makeCoordinator(configuration: RuntimeConfiguration) -> BackgroundWakeCoordinator {
        let engine = CorroborationEngine(store: store, configuration: configuration, clock: clock)
        return BackgroundWakeCoordinator(
            store: store,
            engine: engine,
            snapshotEnricher: snapshotEnricher,
            policyEngine: policyEngine,
            deliveryClient: deliveryClient,
            settingsStore: settingsStore,
            clock: clock
        )
    }

    private func locationRequirement(for configuration: RuntimeConfiguration) -> LocationRequirement {
        let homeWorkEnabled = configuration.enabledFeatures.contains(.homeWork)
        let hasRegions = configuration.homeRegion != nil || configuration.workRegion != nil

        if homeWorkEnabled && !hasRegions {
            return .configurationRequired
        }

        if homeWorkEnabled {
            return .active(.always)
        }

        if configuration.drivingLocationBoostEnabled {
            return .active(.whenInUse)
        }

        return .inactive
    }
}

private enum LocationRequirement: Equatable {
    case inactive
    case configurationRequired
    case active(LocationAuthorizationMode)
}
