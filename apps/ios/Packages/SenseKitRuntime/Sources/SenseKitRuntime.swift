import Foundation

public actor SenseKitRuntime {
    public let store: RuntimeStore
    public let settingsStore: SettingsStore
    public let engine: CorroborationEngine
    public let coordinator: BackgroundWakeCoordinator
    public let bootstrapper: RuntimeBootstrap

    public init(
        store: RuntimeStore,
        settingsStore: SettingsStore,
        configuration: RuntimeConfiguration,
        clock: Clock = SystemClock()
    ) {
        self.store = store
        self.settingsStore = settingsStore
        let engine = CorroborationEngine(store: store, configuration: configuration, clock: clock)
        let snapshotEnricher = SnapshotEnricher()
        let policyEngine = PolicyEngine()
        let deliveryClient = DeliveryClient()
        self.engine = engine
        self.coordinator = BackgroundWakeCoordinator(
            store: store,
            engine: engine,
            snapshotEnricher: snapshotEnricher,
            policyEngine: policyEngine,
            deliveryClient: deliveryClient,
            settingsStore: settingsStore,
            clock: clock
        )
        self.bootstrapper = RuntimeBootstrap(settingsStore: settingsStore, store: store)
    }
}
