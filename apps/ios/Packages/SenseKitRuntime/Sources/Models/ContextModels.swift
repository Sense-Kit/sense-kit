import Foundation

public enum SignalPolarity: String, Codable, Sendable {
    case support
    case oppose
}

public enum SignalCollectorKind: String, Codable, Sendable {
    case motion
    case location
    case power
    case health
    case manual
    case unknown
}

public enum PlaceType: String, Codable, Sendable {
    case home
    case work
    case custom
    case other
}

public enum QueueStatus: String, Codable, Sendable {
    case queued
    case retryWait = "retry_wait"
    case inFlight = "in_flight"
    case delivered
    case expired
}

public enum AuditStatus: String, Codable, Sendable {
    case queued
    case delivered
    case failed
    case expired
}

public enum TimelineCategory: String, Codable, Sendable {
    case signal
    case evaluation
    case scenario
    case delivery
}

public enum SignalTestScenario: String, Codable, CaseIterable, Sendable {
    case wakeSignals = "wake_signals"
    case drivingSignals = "driving_signals"
    case placeArrival = "place_arrival"
    case workoutFinished = "workout_finished"
}

public enum FeatureFlag: String, Codable, CaseIterable, Sendable {
    case wakeBrief = "wake_brief"
    case drivingMode = "driving_mode"
    case homeWork = "home_work"
    case workoutFollowUp = "workout_follow_up"
}

public enum PlaceSharingMode: String, Codable, CaseIterable, Sendable {
    case labelsOnly = "labels_only"
    case preciseCoordinates = "precise_coordinates"
}

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public struct ContextSignal: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let signalID: String
    public let signalKey: String
    public let collector: SignalCollectorKind
    public let source: String
    public let weight: Double
    public let polarity: SignalPolarity
    public let observedAt: Date
    public let receivedAt: Date
    public let validForSec: Int
    public let payload: [String: JSONValue]

    public init(
        signalID: String = UUID().uuidString,
        signalKey: String,
        collector: SignalCollectorKind? = nil,
        source: String,
        weight: Double,
        polarity: SignalPolarity,
        observedAt: Date,
        receivedAt: Date? = nil,
        validForSec: Int,
        payload: [String: JSONValue] = [:]
    ) {
        self.schemaVersion = "sensekit.context_signal.v1"
        self.signalID = signalID
        self.signalKey = signalKey
        self.collector = collector ?? Self.inferredCollector(for: signalKey)
        self.source = source
        self.weight = weight
        self.polarity = polarity
        self.observedAt = observedAt
        self.receivedAt = receivedAt ?? observedAt
        self.validForSec = validForSec
        self.payload = payload
    }

    public var expiresAt: Date {
        observedAt.addingTimeInterval(TimeInterval(validForSec))
    }

    public static func inferredCollector(for signalKey: String) -> SignalCollectorKind {
        if signalKey.hasPrefix("motion.") {
            return .motion
        }
        if signalKey.hasPrefix("location.") {
            return .location
        }
        if signalKey.hasPrefix("power.") {
            return .power
        }
        if signalKey.hasPrefix("health.") {
            return .health
        }
        if signalKey.hasPrefix("manual.") {
            return .manual
        }
        return .unknown
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case signalID = "signal_id"
        case signalKey = "signal_key"
        case collector
        case source
        case weight
        case polarity
        case observedAt = "observed_at"
        case receivedAt = "received_at"
        case validForSec = "valid_for_sec"
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let signalKey = try container.decode(String.self, forKey: .signalKey)
        let observedAt = try container.decode(Date.self, forKey: .observedAt)
        self.schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion) ?? "sensekit.context_signal.v1"
        self.signalID = try container.decode(String.self, forKey: .signalID)
        self.signalKey = signalKey
        self.collector = try container.decodeIfPresent(SignalCollectorKind.self, forKey: .collector) ?? Self.inferredCollector(for: signalKey)
        self.source = try container.decode(String.self, forKey: .source)
        self.weight = try container.decode(Double.self, forKey: .weight)
        self.polarity = try container.decode(SignalPolarity.self, forKey: .polarity)
        self.observedAt = observedAt
        self.receivedAt = try container.decodeIfPresent(Date.self, forKey: .receivedAt) ?? observedAt
        self.validForSec = try container.decode(Int.self, forKey: .validForSec)
        self.payload = try container.decodeIfPresent([String: JSONValue].self, forKey: .payload) ?? [:]
    }
}

public struct DeliveryMetadata: Codable, Equatable, Sendable {
    public var attempt: Int
    public var queuedAt: Date

    public init(attempt: Int, queuedAt: Date) {
        self.attempt = attempt
        self.queuedAt = queuedAt
    }

    enum CodingKeys: String, CodingKey {
        case attempt
        case queuedAt = "queued_at"
    }
}

public struct SignalBatchDevice: Codable, Equatable, Sendable {
    public let deviceID: String
    public let platform: String
    public let placeSharingMode: PlaceSharingMode

    public init(deviceID: String, platform: String = "ios", placeSharingMode: PlaceSharingMode) {
        self.deviceID = deviceID
        self.platform = platform
        self.placeSharingMode = placeSharingMode
    }

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case platform
        case placeSharingMode = "place_sharing_mode"
    }
}

public struct SenseKitSignalBatch: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let batchID: String
    public let sentAt: Date
    public let device: SignalBatchDevice
    public let signals: [ContextSignal]
    public let delivery: DeliveryMetadata

    public init(
        batchID: String = UUID().uuidString,
        sentAt: Date,
        device: SignalBatchDevice,
        signals: [ContextSignal],
        delivery: DeliveryMetadata
    ) {
        self.schemaVersion = "sensekit.signal_batch.v1"
        self.batchID = batchID
        self.sentAt = sentAt
        self.device = device
        self.signals = signals
        self.delivery = delivery
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case batchID = "batch_id"
        case sentAt = "sent_at"
        case device
        case signals
        case delivery
    }
}

public struct QueuedWebhook: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let eventType: String
    public let signalBatch: SenseKitSignalBatch?
    public var status: QueueStatus
    public var attempt: Int
    public var queuedAt: Date
    public var retryAt: Date?

    public init(
        id: String = UUID().uuidString,
        eventType: String,
        signalBatch: SenseKitSignalBatch,
        status: QueueStatus = .queued,
        attempt: Int = 1,
        queuedAt: Date,
        retryAt: Date? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.signalBatch = signalBatch
        self.status = status
        self.attempt = attempt
        self.queuedAt = queuedAt
        self.retryAt = retryAt
    }
}

public struct AuditLogEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let createdAt: Date
    public let eventType: String
    public let destination: String
    public let status: AuditStatus
    public let payloadSummary: String
    public let retryCount: Int

    public init(
        id: String = UUID().uuidString,
        createdAt: Date,
        eventType: String,
        destination: String,
        status: AuditStatus,
        payloadSummary: String,
        retryCount: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.eventType = eventType
        self.destination = destination
        self.status = status
        self.payloadSummary = payloadSummary
        self.retryCount = retryCount
    }
}

public struct DebugTimelineEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let createdAt: Date
    public let category: TimelineCategory
    public let message: String
    public let payload: String?

    public init(
        id: String = UUID().uuidString,
        createdAt: Date,
        category: TimelineCategory,
        message: String,
        payload: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.category = category
        self.message = message
        self.payload = payload
    }
}

public struct RegionConfiguration: Codable, Equatable, Sendable {
    public var identifier: String
    public var displayName: String?
    public var latitude: Double
    public var longitude: Double
    public var radiusMeters: Double

    public init(
        identifier: String,
        displayName: String? = nil,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
    }
}

public struct OpenClawConfiguration: Codable, Equatable, Sendable {
    public var endpointURL: URL
    public var bearerToken: String
    public var hmacSecret: String

    public init(endpointURL: URL, bearerToken: String, hmacSecret: String) {
        self.endpointURL = endpointURL
        self.bearerToken = bearerToken
        self.hmacSecret = hmacSecret
    }
}

public struct RuntimeConfiguration: Codable, Equatable, Sendable {
    public var deviceID: String
    public var enabledFeatures: Set<FeatureFlag>
    public var wakeWindowStartHour: Int
    public var wakeWindowEndHour: Int
    public var drivingLocationBoostEnabled: Bool
    public var placeSharingMode: PlaceSharingMode
    public var fixedPlaces: [RegionConfiguration]
    public var homeRegion: RegionConfiguration?
    public var workRegion: RegionConfiguration?
    public var openClaw: OpenClawConfiguration?

    public init(
        deviceID: String,
        enabledFeatures: Set<FeatureFlag> = [],
        wakeWindowStartHour: Int = 4,
        wakeWindowEndHour: Int = 11,
        drivingLocationBoostEnabled: Bool = false,
        placeSharingMode: PlaceSharingMode = .labelsOnly,
        fixedPlaces: [RegionConfiguration] = [],
        homeRegion: RegionConfiguration? = nil,
        workRegion: RegionConfiguration? = nil,
        openClaw: OpenClawConfiguration? = nil
    ) {
        self.deviceID = deviceID
        self.enabledFeatures = enabledFeatures
        self.wakeWindowStartHour = wakeWindowStartHour
        self.wakeWindowEndHour = wakeWindowEndHour
        self.drivingLocationBoostEnabled = drivingLocationBoostEnabled
        self.placeSharingMode = placeSharingMode
        self.fixedPlaces = fixedPlaces
        self.homeRegion = homeRegion
        self.workRegion = workRegion
        self.openClaw = openClaw
    }

    enum CodingKeys: String, CodingKey {
        case deviceID
        case enabledFeatures
        case wakeWindowStartHour
        case wakeWindowEndHour
        case drivingLocationBoostEnabled
        case placeSharingMode
        case fixedPlaces
        case homeRegion
        case workRegion
        case openClaw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decode(String.self, forKey: .deviceID)
        enabledFeatures = try container.decodeIfPresent(Set<FeatureFlag>.self, forKey: .enabledFeatures) ?? []
        wakeWindowStartHour = try container.decodeIfPresent(Int.self, forKey: .wakeWindowStartHour) ?? 4
        wakeWindowEndHour = try container.decodeIfPresent(Int.self, forKey: .wakeWindowEndHour) ?? 11
        drivingLocationBoostEnabled = try container.decodeIfPresent(Bool.self, forKey: .drivingLocationBoostEnabled) ?? false
        placeSharingMode = try container.decodeIfPresent(PlaceSharingMode.self, forKey: .placeSharingMode) ?? .labelsOnly
        fixedPlaces = try container.decodeIfPresent([RegionConfiguration].self, forKey: .fixedPlaces) ?? []
        homeRegion = try container.decodeIfPresent(RegionConfiguration.self, forKey: .homeRegion)
        workRegion = try container.decodeIfPresent(RegionConfiguration.self, forKey: .workRegion)
        openClaw = try container.decodeIfPresent(OpenClawConfiguration.self, forKey: .openClaw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(enabledFeatures, forKey: .enabledFeatures)
        try container.encode(wakeWindowStartHour, forKey: .wakeWindowStartHour)
        try container.encode(wakeWindowEndHour, forKey: .wakeWindowEndHour)
        try container.encode(drivingLocationBoostEnabled, forKey: .drivingLocationBoostEnabled)
        try container.encode(placeSharingMode, forKey: .placeSharingMode)
        try container.encode(fixedPlaces, forKey: .fixedPlaces)
        try container.encodeIfPresent(homeRegion, forKey: .homeRegion)
        try container.encodeIfPresent(workRegion, forKey: .workRegion)
        try container.encodeIfPresent(openClaw, forKey: .openClaw)
    }

    public var monitoredRegions: [RegionConfiguration] {
        var regions = fixedPlaces

        if let homeRegion, !regions.contains(where: { $0.identifier == homeRegion.identifier }) {
            regions.append(homeRegion)
        }

        if let workRegion, !regions.contains(where: { $0.identifier == workRegion.identifier }) {
            regions.append(workRegion)
        }

        return regions
    }

    public func region(for identifier: String?) -> RegionConfiguration? {
        guard let identifier else {
            return nil
        }

        return monitoredRegions.first { $0.identifier == identifier }
    }
}

public struct RuntimeState: Codable, Equatable, Sendable {
    public var currentPlace: PlaceType
    public var currentPlaceIdentifier: String?
    public var currentPlaceName: String?

    public init(
        currentPlace: PlaceType = .other,
        currentPlaceIdentifier: String? = nil,
        currentPlaceName: String? = nil
    ) {
        self.currentPlace = currentPlace
        self.currentPlaceIdentifier = currentPlaceIdentifier
        self.currentPlaceName = currentPlaceName
    }
}
