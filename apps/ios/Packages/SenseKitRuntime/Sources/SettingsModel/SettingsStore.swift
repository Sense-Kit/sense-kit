import Foundation

public protocol SettingsStore: Sendable {
    func load() async throws -> RuntimeConfiguration
    func save(_ configuration: RuntimeConfiguration) async throws
}

public actor InMemorySettingsStore: SettingsStore {
    private var configuration: RuntimeConfiguration

    public init(configuration: RuntimeConfiguration) {
        self.configuration = configuration
    }

    public func load() async throws -> RuntimeConfiguration {
        configuration
    }

    public func save(_ configuration: RuntimeConfiguration) async throws {
        self.configuration = configuration
    }
}

public actor UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "sensekit.runtime.configuration") {
        self.defaults = defaults
        self.key = key
    }

    public func load() async throws -> RuntimeConfiguration {
        guard let data = defaults.data(forKey: key) else {
            return RuntimeConfiguration(deviceID: UUID().uuidString)
        }
        return try JSONCoding.decoder.decode(RuntimeConfiguration.self, from: data)
    }

    public func save(_ configuration: RuntimeConfiguration) async throws {
        let data = try JSONCoding.encoder.encode(configuration)
        defaults.set(data, forKey: key)
    }
}
