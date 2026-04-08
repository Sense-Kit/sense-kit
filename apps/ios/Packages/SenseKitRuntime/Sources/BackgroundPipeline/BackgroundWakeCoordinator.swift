import Foundation

public struct ProcessingResult: Sendable {
    public let deliveryLabel: String
    public let signalBatch: SenseKitSignalBatch
    public let queuedWebhookID: String
}

public actor BackgroundWakeCoordinator {
    private let store: RuntimeStore
    private let deliveryClient: DeliveryClient
    private let settingsStore: SettingsStore
    private let clock: Clock

    public init(
        store: RuntimeStore,
        deliveryClient: DeliveryClient,
        settingsStore: SettingsStore,
        clock: Clock = SystemClock()
    ) {
        self.store = store
        self.deliveryClient = deliveryClient
        self.settingsStore = settingsStore
        self.clock = clock
    }

    @discardableResult
    public func handleWake(signal: ContextSignal) async throws -> [ProcessingResult] {
        let configuration = try await settingsStore.load()
        return [
            try await processSignals(
                [signal],
                configuration: configuration,
                deliveryLabel: signal.signalKey
            )
        ]
    }

    @discardableResult
    public func sendTestScenario(_ scenario: SignalTestScenario) async throws -> ProcessingResult {
        let configuration = try await settingsStore.load()
        let signals = makeManualSignals(for: scenario, configuration: configuration, observedAt: clock.now())

        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .scenario,
                message: "Manual test scenario \(scenario.rawValue)",
                payload: try payloadString(signals)
            )
        )

        return try await processSignals(
            signals,
            configuration: configuration,
            deliveryLabel: "manual.\(scenario.rawValue)"
        )
    }

    public func drainQueue(limit: Int = 10) async throws {
        let configuration = try await settingsStore.load()
        guard let openClaw = configuration.openClaw else { return }
        let dueItems = try await store.dueQueueItems(at: clock.now(), limit: limit)
        for item in dueItems {
            try await attemptImmediateDelivery(item: item, configuration: openClaw)
        }
    }

    private func processSignals(
        _ signals: [ContextSignal],
        configuration: RuntimeConfiguration,
        deliveryLabel: String
    ) async throws -> ProcessingResult {
        guard !signals.isEmpty else {
            throw CocoaError(.coderInvalidValue)
        }

        var state = try await store.loadRuntimeState()

        for signal in signals {
            try await store.saveSignal(signal)
            applySideEffects(of: signal, to: &state)
            try await store.appendDebugEntry(
                DebugTimelineEntry(
                    createdAt: clock.now(),
                    category: .signal,
                    message: "Received raw signal \(signal.signalKey)",
                    payload: try payloadString(signal)
                )
            )
        }

        try await store.pruneExpiredSignals(before: clock.now())
        try await store.saveRuntimeState(state)

        let batch = SenseKitSignalBatch(
            sentAt: clock.now(),
            device: SignalBatchDevice(
                deviceID: configuration.deviceID,
                placeSharingMode: configuration.placeSharingMode
            ),
            signals: signals,
            delivery: DeliveryMetadata(attempt: 1, queuedAt: clock.now())
        )
        let auditPayload = try prettyPrintedPayloadString(batch)

        let queued = QueuedWebhook(
            eventType: deliveryLabel,
            signalBatch: batch,
            queuedAt: clock.now()
        )
        try await store.enqueue(queued)
        try await store.appendAuditEntry(
            AuditLogEntry(
                createdAt: clock.now(),
                eventType: deliveryLabel,
                destination: configuration.openClaw?.endpointURL.absoluteString ?? "unconfigured",
                status: .queued,
                payloadSummary: "signals=\(signals.map(\.signalKey).joined(separator: ","))",
                payload: auditPayload,
                retryCount: 0
            )
        )

        if let openClaw = configuration.openClaw {
            try await attemptImmediateDelivery(item: queued, configuration: openClaw)
        }

        return ProcessingResult(
            deliveryLabel: deliveryLabel,
            signalBatch: batch,
            queuedWebhookID: queued.id
        )
    }

    private func attemptImmediateDelivery(item: QueuedWebhook, configuration: OpenClawConfiguration) async throws {
        guard let signalBatch = item.signalBatch else {
            var expired = item
            expired.status = .expired
            expired.retryAt = nil
            try await store.updateQueueItem(expired)
            try await store.appendAuditEntry(
                AuditLogEntry(
                    createdAt: clock.now(),
                    eventType: item.eventType,
                    destination: configuration.endpointURL.absoluteString,
                    status: .expired,
                    payloadSummary: "Skipped legacy queued payload without raw signal batch",
                    retryCount: item.attempt - 1
                )
            )
            return
        }

        let deliveryBatch = SenseKitSignalBatch(
            batchID: signalBatch.batchID,
            sentAt: clock.now(),
            device: signalBatch.device,
            signals: signalBatch.signals,
            delivery: DeliveryMetadata(attempt: item.attempt, queuedAt: item.queuedAt)
        )
        let auditPayload = try prettyPrintedPayloadString(deliveryBatch)

        do {
            let result = try await deliveryClient.deliver(deliveryBatch, configuration: configuration)
            var delivered = item
            delivered.status = .delivered
            delivered.retryAt = nil
            try await store.updateQueueItem(delivered)
            try await store.appendAuditEntry(
                AuditLogEntry(
                    createdAt: clock.now(),
                    eventType: item.eventType,
                    destination: configuration.endpointURL.absoluteString,
                    status: .delivered,
                    payloadSummary: "HTTP \(result.statusCode)",
                    payload: auditPayload,
                    retryCount: item.attempt - 1
                )
            )
        } catch {
            var retrying = item
            retrying.status = .retryWait
            retrying.attempt += 1
            retrying.retryAt = nextRetryDate(attempt: retrying.attempt, from: clock.now())
            try await store.updateQueueItem(retrying)
            try await store.appendAuditEntry(
                AuditLogEntry(
                    createdAt: clock.now(),
                    eventType: item.eventType,
                    destination: configuration.endpointURL.absoluteString,
                    status: .failed,
                    payloadSummary: String(describing: error),
                    payload: auditPayload,
                    retryCount: retrying.attempt - 1
                )
            )
        }
    }

    private func makeManualSignals(
        for scenario: SignalTestScenario,
        configuration: RuntimeConfiguration,
        observedAt: Date
    ) -> [ContextSignal] {
        switch scenario {
        case .wakeSignals:
            return [
                ContextSignal(
                    signalKey: "motion.activity_observed",
                    collector: .manual,
                    source: "manual_test",
                    weight: 1.0,
                    polarity: .support,
                    observedAt: observedAt,
                    receivedAt: observedAt,
                    validForSec: 60,
                    payload: [
                        "primary_kind": .string("walking"),
                        "confidence": .string("high"),
                        "automotive": .bool(false),
                        "walking": .bool(true),
                        "running": .bool(false),
                        "stationary": .bool(false),
                        "cycling": .bool(false)
                    ]
                ),
                ContextSignal(
                    signalKey: "power.battery_state_changed",
                    collector: .manual,
                    source: "manual_test",
                    weight: 1.0,
                    polarity: .support,
                    observedAt: observedAt,
                    receivedAt: observedAt,
                    validForSec: 120,
                    payload: [
                        "previous_state": .string("charging"),
                        "current_state": .string("unplugged"),
                        "battery_level": .number(0.82),
                        "battery_level_percent": .number(82),
                        "is_charging": .bool(false)
                    ]
                )
            ]
        case .drivingSignals:
            return [
                ContextSignal(
                    signalKey: "motion.activity_observed",
                    collector: .manual,
                    source: "manual_test",
                    weight: 1.0,
                    polarity: .support,
                    observedAt: observedAt,
                    receivedAt: observedAt,
                    validForSec: 60,
                    payload: [
                        "primary_kind": .string("automotive"),
                        "confidence": .string("high"),
                        "automotive": .bool(true),
                        "walking": .bool(false),
                        "running": .bool(false),
                        "stationary": .bool(false),
                        "cycling": .bool(false)
                    ]
                ),
                manualLocationSignal(
                    configuration: configuration,
                    observedAt: observedAt,
                    latitude: 47.3769,
                    longitude: 8.5417,
                    speedKilometersPerHour: 42.0
                )
            ]
        case .placeArrival:
            let region = configuration.fixedPlaces.first
                ?? configuration.homeRegion
                ?? configuration.workRegion
                ?? RegionConfiguration(
                    identifier: "place-manual",
                    displayName: "Manual Place",
                    latitude: 47.3769,
                    longitude: 8.5417,
                    radiusMeters: 150
                )
            return [
                manualRegionSignal(
                    configuration: configuration,
                    observedAt: observedAt,
                    region: region,
                    transition: "enter"
                )
            ]
        case .workoutFinished:
            return [
                ContextSignal(
                    signalKey: "health.workout_sample_observed",
                    collector: .manual,
                    source: "manual_test",
                    weight: 1.0,
                    polarity: .support,
                    observedAt: observedAt,
                    receivedAt: observedAt,
                    validForSec: 3_600,
                    payload: [
                        "uuid": .string(UUID().uuidString),
                        "activity_type": .string("traditional_strength_training"),
                        "start_at": .string(iso8601(observedAt.addingTimeInterval(-2_700))),
                        "end_at": .string(iso8601(observedAt)),
                        "duration_sec": .number(2_700),
                        "total_energy_kcal": .number(320),
                        "total_distance_m": .number(0)
                    ]
                )
            ]
        }
    }

    private func manualLocationSignal(
        configuration: RuntimeConfiguration,
        observedAt: Date,
        latitude: Double,
        longitude: Double,
        speedKilometersPerHour: Double
    ) -> ContextSignal {
        let speedMetersPerSecond = speedKilometersPerHour / 3.6
        var payload: [String: JSONValue] = [
            "horizontal_accuracy_m": .number(20),
            "vertical_accuracy_m": .number(10),
            "speed_mps": .number(speedMetersPerSecond),
            "speed_kmh": .number(speedKilometersPerHour),
            "course_deg": .number(90),
            "altitude_m": .number(408),
            "timestamp": .string(iso8601(observedAt))
        ]

        if configuration.placeSharingMode == .preciseCoordinates {
            payload["latitude"] = .number(latitude)
            payload["longitude"] = .number(longitude)
        }

        return ContextSignal(
            signalKey: "location.location_observed",
            collector: .manual,
            source: "manual_test",
            weight: 1.0,
            polarity: .support,
            observedAt: observedAt,
            receivedAt: observedAt,
            validForSec: 300,
            payload: payload
        )
    }

    private func manualRegionSignal(
        configuration: RuntimeConfiguration,
        observedAt: Date,
        region: RegionConfiguration,
        transition: String
    ) -> ContextSignal {
        var payload: [String: JSONValue] = [
            "transition": .string(transition),
            "place_identifier": .string(region.identifier),
            "place_type": .string(placeType(for: region.identifier, configuration: configuration).rawValue),
            "radius_m": .number(region.radiusMeters)
        ]

        if let displayName = region.displayName, !displayName.isEmpty {
            payload["place_name"] = .string(displayName)
        }

        if configuration.placeSharingMode == .preciseCoordinates {
            payload["latitude"] = .number(region.latitude)
            payload["longitude"] = .number(region.longitude)
        }

        return ContextSignal(
            signalKey: "location.region_state_changed",
            collector: .manual,
            source: "manual_test",
            weight: 1.0,
            polarity: .support,
            observedAt: observedAt,
            receivedAt: observedAt,
            validForSec: 180,
            payload: payload
        )
    }

    private func applySideEffects(of signal: ContextSignal, to state: inout RuntimeState) {
        guard signal.signalKey == "location.region_state_changed" else {
            return
        }

        guard case .string(let transition)? = signal.payload["transition"] else {
            return
        }
        guard case .string(let identifier)? = signal.payload["place_identifier"] else {
            return
        }

        let placeType: PlaceType
        if case .string(let rawPlaceType)? = signal.payload["place_type"] {
            placeType = PlaceType(rawValue: rawPlaceType) ?? .custom
        } else {
            placeType = .custom
        }

        let placeName: String?
        if case .string(let rawPlaceName)? = signal.payload["place_name"] {
            placeName = rawPlaceName
        } else {
            placeName = nil
        }

        switch transition {
        case "enter":
            state.currentPlace = placeType
            state.currentPlaceIdentifier = identifier
            state.currentPlaceName = placeName
        case "exit":
            if state.currentPlaceIdentifier == identifier {
                state.currentPlace = .other
                state.currentPlaceIdentifier = nil
                state.currentPlaceName = nil
            }
        default:
            break
        }
    }

    private func placeType(for identifier: String, configuration: RuntimeConfiguration) -> PlaceType {
        if identifier == configuration.homeRegion?.identifier {
            return .home
        }

        if identifier == configuration.workRegion?.identifier {
            return .work
        }

        return .custom
    }

    private func nextRetryDate(attempt: Int, from date: Date) -> Date {
        let offsets: [TimeInterval] = [0, 5, 30, 300, 1_800, 7_200, 43_200]
        let index = min(attempt, offsets.count - 1)
        return date.addingTimeInterval(offsets[index])
    }

    private func payloadString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONCoding.encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    private func prettyPrintedPayloadString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONCoding.encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: prettyData, as: UTF8.self)
    }

    private func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
