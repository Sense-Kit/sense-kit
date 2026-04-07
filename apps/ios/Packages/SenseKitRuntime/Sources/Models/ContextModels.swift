import Foundation

public enum SignalPolarity: String, Codable, Sendable {
    case support
    case oppose
}

public enum ModeHint: String, Codable, Sendable {
    case textBrief = "text_brief"
    case voiceSafe = "voice_safe"
    case voiceNote = "voice_note"
    case normal = "normal"
}

public enum PlaceType: String, Codable, Sendable {
    case home
    case work
    case other
}

public enum SnapshotFreshness: String, Codable, Sendable {
    case live
    case recent
    case stale
}

public enum WorkoutActivityState: String, Codable, Sendable {
    case inactive
    case active
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
    case event
    case delivery
}

public enum ContextEventType: String, Codable, CaseIterable, Sendable {
    case motionActivityObserved = "motion_activity_observed"
    case healthSnapshotUpdated = "health_snapshot_updated"
    case wakeConfirmed = "wake_confirmed"
    case drivingStarted = "driving_started"
    case drivingStopped = "driving_stopped"
    case arrivedHome = "arrived_home"
    case leftHome = "left_home"
    case arrivedWork = "arrived_work"
    case leftWork = "left_work"
    case workoutStarted = "workout_started"
    case workoutEnded = "workout_ended"
    case focusOn = "focus_on"
    case focusOff = "focus_off"
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
    public let source: String
    public let weight: Double
    public let polarity: SignalPolarity
    public let observedAt: Date
    public let validForSec: Int
    public let payload: [String: JSONValue]

    public init(
        signalID: String = UUID().uuidString,
        signalKey: String,
        source: String,
        weight: Double,
        polarity: SignalPolarity,
        observedAt: Date,
        validForSec: Int,
        payload: [String: JSONValue] = [:]
    ) {
        self.schemaVersion = "sensekit.context_signal.v1"
        self.signalID = signalID
        self.signalKey = signalKey
        self.source = source
        self.weight = weight
        self.polarity = polarity
        self.observedAt = observedAt
        self.validForSec = validForSec
        self.payload = payload
    }

    public var expiresAt: Date {
        observedAt.addingTimeInterval(TimeInterval(validForSec))
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case signalID = "signal_id"
        case signalKey = "signal_key"
        case source
        case weight
        case polarity
        case observedAt = "observed_at"
        case validForSec = "valid_for_sec"
        case payload
    }
}

public struct ContextEvent: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let eventID: String
    public let eventType: ContextEventType
    public let occurredAt: Date
    public let confidence: Double
    public let reasons: [String]
    public let modeHint: ModeHint
    public let cooldownSec: Int
    public let dedupeKey: String

    public init(
        eventID: String = UUID().uuidString,
        eventType: ContextEventType,
        occurredAt: Date,
        confidence: Double,
        reasons: [String],
        modeHint: ModeHint,
        cooldownSec: Int,
        dedupeKey: String
    ) {
        self.schemaVersion = "sensekit.context_event.v1"
        self.eventID = eventID
        self.eventType = eventType
        self.occurredAt = occurredAt
        self.confidence = confidence
        self.reasons = reasons
        self.modeHint = modeHint
        self.cooldownSec = cooldownSec
        self.dedupeKey = dedupeKey
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case eventID = "event_id"
        case eventType = "event_type"
        case occurredAt = "occurred_at"
        case confidence
        case reasons
        case modeHint = "mode_hint"
        case cooldownSec = "cooldown_sec"
        case dedupeKey = "dedupe_key"
    }
}

public struct ContextSnapshot: Codable, Equatable, Sendable {
    public struct Routine: Codable, Equatable, Sendable {
        public var awake: Bool
        public var focus: String?
        public var workout: WorkoutActivityState
    }

    public struct Place: Codable, Equatable, Sendable {
        public struct Coordinate: Codable, Equatable, Sendable {
            public var latitude: Double
            public var longitude: Double

            public init(latitude: Double, longitude: Double) {
                self.latitude = latitude
                self.longitude = longitude
            }
        }

        public var type: PlaceType
        public var freshness: SnapshotFreshness
        public var coordinate: Coordinate?

        public init(type: PlaceType, freshness: SnapshotFreshness, coordinate: Coordinate? = nil) {
            self.type = type
            self.freshness = freshness
            self.coordinate = coordinate
        }
    }

    public struct Calendar: Codable, Equatable, Sendable {
        public var inMeeting: Bool
        public var nextMeetingInMin: Int?
        public var freshness: SnapshotFreshness

        enum CodingKeys: String, CodingKey {
            case inMeeting = "in_meeting"
            case nextMeetingInMin = "next_meeting_in_min"
            case freshness
        }
    }

    public struct Device: Codable, Equatable, Sendable {
        public var batteryPercentBucket: Int
        public var charging: Bool

        enum CodingKeys: String, CodingKey {
            case batteryPercentBucket = "battery_percent_bucket"
            case charging
        }
    }

    public let schemaVersion: String
    public let capturedAt: Date
    public let routine: Routine
    public let place: Place
    public let calendar: Calendar
    public let device: Device
    public let health: HealthSnapshot

    public init(
        capturedAt: Date,
        routine: Routine,
        place: Place,
        calendar: Calendar,
        device: Device,
        health: HealthSnapshot? = nil
    ) {
        self.schemaVersion = "sensekit.context_snapshot.v1"
        self.capturedAt = capturedAt
        self.routine = routine
        self.place = place
        self.calendar = calendar
        self.device = device
        self.health = health ?? .empty(capturedAt: capturedAt)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case capturedAt = "captured_at"
        case routine
        case place
        case calendar
        case device
        case health
    }

    public func withHealth(_ health: HealthSnapshot) -> ContextSnapshot {
        ContextSnapshot(
            capturedAt: capturedAt,
            routine: routine,
            place: place,
            calendar: calendar,
            device: device,
            health: health
        )
    }

    public func withPlace(_ place: Place) -> ContextSnapshot {
        ContextSnapshot(
            capturedAt: capturedAt,
            routine: routine,
            place: place,
            calendar: calendar,
            device: device,
            health: health
        )
    }
}

public struct PolicyDecision: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let eventType: ContextEventType
    public let allowedActions: [String]
    public let blockedActions: [String]
    public let deliveryChannelPreference: [String]
    public let ttlSec: Int

    public init(
        eventType: ContextEventType,
        allowedActions: [String],
        blockedActions: [String],
        deliveryChannelPreference: [String],
        ttlSec: Int
    ) {
        self.schemaVersion = "sensekit.policy_decision.v1"
        self.eventType = eventType
        self.allowedActions = allowedActions
        self.blockedActions = blockedActions
        self.deliveryChannelPreference = deliveryChannelPreference
        self.ttlSec = ttlSec
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case eventType = "event_type"
        case allowedActions = "allowed_actions"
        case blockedActions = "blocked_actions"
        case deliveryChannelPreference = "delivery_channel_preference"
        case ttlSec = "ttl_sec"
    }
}

public struct DeliveryMetadata: Codable, Equatable, Sendable {
    public var attempt: Int
    public var queuedAt: Date

    enum CodingKeys: String, CodingKey {
        case attempt
        case queuedAt = "queued_at"
    }
}

public struct SenseKitEventEnvelope: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let deviceID: String
    public let event: ContextEvent
    public let snapshot: ContextSnapshot
    public let policy: PolicyDecision
    public let delivery: DeliveryMetadata

    public init(deviceID: String, event: ContextEvent, snapshot: ContextSnapshot, policy: PolicyDecision, delivery: DeliveryMetadata) {
        self.schemaVersion = "sensekit.event.v1"
        self.deviceID = deviceID
        self.event = event
        self.snapshot = snapshot
        self.policy = policy
        self.delivery = delivery
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case deviceID = "device_id"
        case event
        case snapshot
        case policy
        case delivery
    }
}

public struct QueuedWebhook: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let eventType: ContextEventType
    public let envelope: SenseKitEventEnvelope
    public var status: QueueStatus
    public var attempt: Int
    public var queuedAt: Date
    public var retryAt: Date?

    public init(
        id: String = UUID().uuidString,
        eventType: ContextEventType,
        envelope: SenseKitEventEnvelope,
        status: QueueStatus = .queued,
        attempt: Int = 1,
        queuedAt: Date,
        retryAt: Date? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.envelope = envelope
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
        try container.encodeIfPresent(homeRegion, forKey: .homeRegion)
        try container.encodeIfPresent(workRegion, forKey: .workRegion)
        try container.encodeIfPresent(openClaw, forKey: .openClaw)
    }
}

public struct RuntimeState: Codable, Equatable, Sendable {
    public var lastEventTimestamps: [String: Date]
    public var currentPlace: PlaceType
    public var isDriving: Bool
    public var isWorkoutActive: Bool
    public var boostTimestamps: [String: Date]
    public var lastWakeAt: Date?

    public init(
        lastEventTimestamps: [String: Date] = [:],
        currentPlace: PlaceType = .other,
        isDriving: Bool = false,
        isWorkoutActive: Bool = false,
        boostTimestamps: [String: Date] = [:],
        lastWakeAt: Date? = nil
    ) {
        self.lastEventTimestamps = lastEventTimestamps
        self.currentPlace = currentPlace
        self.isDriving = isDriving
        self.isWorkoutActive = isWorkoutActive
        self.boostTimestamps = boostTimestamps
        self.lastWakeAt = lastWakeAt
    }

    public func lastEventDate(for eventType: ContextEventType) -> Date? {
        lastEventTimestamps[eventType.rawValue]
    }

    public mutating func setLastEventDate(_ date: Date, for eventType: ContextEventType) {
        lastEventTimestamps[eventType.rawValue] = date
    }
}
