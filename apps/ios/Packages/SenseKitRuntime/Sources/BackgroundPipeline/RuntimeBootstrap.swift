import Foundation

public struct RuntimeBootstrapResult: Sendable {
    public let configuration: RuntimeConfiguration
    public let state: RuntimeState
}

public actor RuntimeBootstrap {
    private let settingsStore: SettingsStore
    private let store: RuntimeStore

    public init(settingsStore: SettingsStore, store: RuntimeStore) {
        self.settingsStore = settingsStore
        self.store = store
    }

    public func bootstrap() async throws -> RuntimeBootstrapResult {
        let configuration = try await settingsStore.load()
        let state = try await store.loadRuntimeState()

        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: Date(),
                category: .evaluation,
                message: "Runtime bootstrap completed for \(configuration.deviceID)"
            )
        )

        return RuntimeBootstrapResult(configuration: configuration, state: state)
    }
}

