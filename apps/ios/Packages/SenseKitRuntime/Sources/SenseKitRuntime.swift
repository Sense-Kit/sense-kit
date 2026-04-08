import Foundation

public actor SenseKitRuntime {
    public let store: RuntimeStore
    public let settingsStore: SettingsStore
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
        let deliveryClient = DeliveryClient()
        self.coordinator = BackgroundWakeCoordinator(
            store: store,
            deliveryClient: deliveryClient,
            settingsStore: settingsStore,
            clock: clock
        )
        self.bootstrapper = RuntimeBootstrap(settingsStore: settingsStore, store: store)
    }
}
