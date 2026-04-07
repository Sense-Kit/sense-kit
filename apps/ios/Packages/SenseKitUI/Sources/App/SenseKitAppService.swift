import Foundation
import SenseKitRuntime

public struct SenseKitLoadedState: Sendable {
    public let configuration: RuntimeConfiguration
    public let timelineEntries: [DebugTimelineEntry]
    public let auditEntries: [AuditLogEntry]

    public init(
        configuration: RuntimeConfiguration,
        timelineEntries: [DebugTimelineEntry] = [],
        auditEntries: [AuditLogEntry] = []
    ) {
        self.configuration = configuration
        self.timelineEntries = timelineEntries
        self.auditEntries = auditEntries
    }
}

public protocol SenseKitAppService: Sendable {
    func loadState() async throws -> SenseKitLoadedState
    func saveConfiguration(_ configuration: RuntimeConfiguration) async throws
    func sendTestEvent(_ eventType: ContextEventType) async throws
}

public actor LiveSenseKitAppService: SenseKitAppService {
    private let store: RuntimeStore
    private let settingsStore: SettingsStore
    private let clock: Clock
    private let snapshotEnricher: SnapshotEnricher
    private let policyEngine: PolicyEngine
    private let deliveryClient: DeliveryClient
    private var hasBootstrapped = false

    public init(
        store: RuntimeStore,
        settingsStore: SettingsStore,
        clock: Clock = SystemClock(),
        snapshotEnricher: SnapshotEnricher = SnapshotEnricher(),
        policyEngine: PolicyEngine = PolicyEngine(),
        deliveryClient: DeliveryClient = DeliveryClient()
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.clock = clock
        self.snapshotEnricher = snapshotEnricher
        self.policyEngine = policyEngine
        self.deliveryClient = deliveryClient
    }

    public func loadState() async throws -> SenseKitLoadedState {
        try await bootstrapIfNeeded()
        let configuration = try await settingsStore.load()
        let timelineEntries = try await store.timelineEntries(limit: 100)
        let auditEntries = try await store.auditEntries(limit: 100)
        return SenseKitLoadedState(
            configuration: configuration,
            timelineEntries: timelineEntries,
            auditEntries: auditEntries
        )
    }

    public func saveConfiguration(_ configuration: RuntimeConfiguration) async throws {
        try await settingsStore.save(configuration)
        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .evaluation,
                message: "Saved runtime configuration",
                payload: configuration.openClaw?.endpointURL.absoluteString
            )
        )
    }

    public func sendTestEvent(_ eventType: ContextEventType) async throws {
        let configuration = try await settingsStore.load()
        let coordinator = makeCoordinator(configuration: configuration)
        _ = try await coordinator.sendTestEvent(eventType)
    }

    private func bootstrapIfNeeded() async throws {
        guard !hasBootstrapped else { return }
        _ = try await RuntimeBootstrap(settingsStore: settingsStore, store: store).bootstrap()
        hasBootstrapped = true
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
}

public enum SenseKitAppEnvironment {
    public static func makeLiveService() throws -> LiveSenseKitAppService {
        let fileManager = FileManager.default
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let senseKitDirectory = root.appendingPathComponent("SenseKit", isDirectory: true)
        try fileManager.createDirectory(at: senseKitDirectory, withIntermediateDirectories: true)
        let databaseURL = senseKitDirectory.appendingPathComponent("sensekit.sqlite")

        let store = try SQLiteRuntimeStore(path: databaseURL.path)
        let settingsStore = UserDefaultsSettingsStore()
        return LiveSenseKitAppService(store: store, settingsStore: settingsStore)
    }
}
