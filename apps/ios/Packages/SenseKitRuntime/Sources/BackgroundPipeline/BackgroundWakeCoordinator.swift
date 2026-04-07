import Foundation

public struct ProcessingResult: Sendable {
    public let event: ContextEvent
    public let queuedWebhookID: String
}

public actor BackgroundWakeCoordinator {
    private let store: RuntimeStore
    private let engine: CorroborationEngine
    private let snapshotEnricher: SnapshotEnricher
    private let policyEngine: PolicyEngine
    private let deliveryClient: DeliveryClient
    private let settingsStore: SettingsStore
    private let clock: Clock

    public init(
        store: RuntimeStore,
        engine: CorroborationEngine,
        snapshotEnricher: SnapshotEnricher,
        policyEngine: PolicyEngine,
        deliveryClient: DeliveryClient,
        settingsStore: SettingsStore,
        clock: Clock = SystemClock()
    ) {
        self.store = store
        self.engine = engine
        self.snapshotEnricher = snapshotEnricher
        self.policyEngine = policyEngine
        self.deliveryClient = deliveryClient
        self.settingsStore = settingsStore
        self.clock = clock
    }

    @discardableResult
    public func handleWake(signal: ContextSignal) async throws -> [ProcessingResult] {
        if let change = HealthSnapshotChange(signal: signal) {
            return [try await processHealthSnapshotChange(change, signal: signal)]
        }

        if let observation = MotionActivityObservation(signal: signal) {
            return [try await processMotionObservation(observation, signal: signal)]
        }

        if let transition = PlaceTransition(signal: signal) {
            if let result = try await processPlaceTransition(transition, signal: signal) {
                return [result]
            }
            return []
        }

        let evaluations = try await engine.ingest(signal)
        guard !evaluations.isEmpty else { return [] }

        let configuration = try await settingsStore.load()
        var results: [ProcessingResult] = []

        for evaluation in evaluations {
            results.append(
                try await process(
                    event: evaluation.event,
                    configuration: configuration,
                    payloadSummary: "\(evaluation.event.eventType.rawValue) confidence=\(evaluation.score)"
                )
            )
        }

        return results
    }

    @discardableResult
    public func sendTestEvent(_ eventType: ContextEventType) async throws -> ProcessingResult {
        let configuration = try await settingsStore.load()
        let eventConfiguration = EventCatalog.configurations[eventType] ?? EventConfiguration(
            eventType: eventType,
            threshold: 1.0,
            cooldownSec: 0,
            supportSignalKeys: [],
            modeHint: .normal
        )

        var state = try await store.loadRuntimeState()
        if !applyManualPlaceState(for: eventType, configuration: configuration, state: &state) {
            RuntimeStateReducer.apply(eventType, at: clock.now(), to: &state)
        }
        try await store.saveRuntimeState(state)

        let event = ContextEvent(
            eventType: eventType,
            occurredAt: clock.now(),
            confidence: 1.0,
            reasons: ["manual.test_button"],
            modeHint: eventConfiguration.modeHint,
            cooldownSec: eventConfiguration.cooldownSec,
            dedupeKey: "\(configuration.deviceID):\(eventType.rawValue):manual:\(UUID().uuidString)"
        )

        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .event,
                message: "Manual test event \(eventType.rawValue)",
                payload: try payloadString(event)
            )
        )

        return try await process(
            event: event,
            configuration: configuration,
            payloadSummary: "\(event.eventType.rawValue) confidence=1.0 source=manual_test"
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

    private func attemptImmediateDelivery(item: QueuedWebhook, configuration: OpenClawConfiguration) async throws {
        do {
            let result = try await deliveryClient.deliver(item.envelope, configuration: configuration)
            var delivered = item
            delivered.status = .delivered
            delivered.retryAt = nil
            try await store.updateQueueItem(delivered)
            try await store.appendAuditEntry(
                AuditLogEntry(
                    createdAt: clock.now(),
                    eventType: item.eventType.rawValue,
                    destination: configuration.endpointURL.absoluteString,
                    status: .delivered,
                    payloadSummary: "HTTP \(result.statusCode)",
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
                    eventType: item.eventType.rawValue,
                    destination: configuration.endpointURL.absoluteString,
                    status: .failed,
                    payloadSummary: String(describing: error),
                    retryCount: retrying.attempt - 1
                )
            )
        }
    }

    private func processMotionObservation(
        _ observation: MotionActivityObservation,
        signal: ContextSignal
    ) async throws -> ProcessingResult {
        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .signal,
                message: "Received raw motion activity \(observation.primaryKind)",
                payload: try payloadString(signal)
            )
        )

        let configuration = try await settingsStore.load()
        let event = ContextEvent(
            eventType: .motionActivityObserved,
            occurredAt: signal.observedAt,
            confidence: observation.confidenceScore,
            reasons: observation.reasons,
            modeHint: .normal,
            cooldownSec: 0,
            dedupeKey: "\(configuration.deviceID):motion_activity_observed:\(signal.signalID)"
        )

        return try await process(
            event: event,
            configuration: configuration,
            payloadSummary: "motion_activity_observed primary=\(observation.primaryKind) confidence=\(observation.confidence)"
        )
    }

    private func processHealthSnapshotChange(
        _ change: HealthSnapshotChange,
        signal: ContextSignal
    ) async throws -> ProcessingResult {
        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .signal,
                message: "Received health snapshot change",
                payload: try payloadString(signal)
            )
        )

        let configuration = try await settingsStore.load()
        let event = ContextEvent(
            eventType: .healthSnapshotUpdated,
            occurredAt: signal.observedAt,
            confidence: signal.weight,
            reasons: change.reasons,
            modeHint: .normal,
            cooldownSec: 300,
            dedupeKey: "\(configuration.deviceID):health_snapshot_updated:\(signal.signalID)"
        )

        return try await process(
            event: event,
            configuration: configuration,
            payloadSummary: "health_snapshot_updated domains=\(change.domains.joined(separator: ","))"
        )
    }

    private func processPlaceTransition(
        _ transition: PlaceTransition,
        signal: ContextSignal
    ) async throws -> ProcessingResult? {
        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .signal,
                message: "Received signal \(signal.signalKey)",
                payload: try payloadString(signal)
            )
        )

        let configuration = try await settingsStore.load()
        let eventType: ContextEventType = transition.kind == .enter ? .arrivedPlace : .leftPlace
        let placeName = transition.name ?? configuration.region(for: transition.identifier)?.displayName ?? transition.identifier
        var state = try await store.loadRuntimeState()

        guard placeCooldownOK(for: eventType, placeIdentifier: transition.identifier, state: state) else {
            try await store.appendDebugEntry(
                DebugTimelineEntry(
                    createdAt: clock.now(),
                    category: .evaluation,
                    message: "Cooldown blocked \(eventType.rawValue) for \(placeName)"
                )
            )
            return nil
        }

        switch transition.kind {
        case .enter:
            guard state.currentPlaceIdentifier != transition.identifier else {
                return nil
            }
            state.currentPlace = .custom
            state.currentPlaceIdentifier = transition.identifier
            state.currentPlaceName = placeName
        case .exit:
            guard state.currentPlaceIdentifier == transition.identifier else {
                return nil
            }
            state.currentPlace = .other
            state.currentPlaceIdentifier = nil
            state.currentPlaceName = nil
        }

        state.setLastEventDate(clock.now(), for: eventType, scope: transition.identifier)
        try await store.saveRuntimeState(state)

        let event = ContextEvent(
            eventType: eventType,
            occurredAt: signal.observedAt,
            confidence: signal.weight,
            reasons: [
                signal.signalKey,
                "place.\(transition.identifier)"
            ],
            modeHint: .normal,
            cooldownSec: 600,
            dedupeKey: dedupeKey(
                for: eventType,
                deviceID: configuration.deviceID,
                scope: transition.identifier,
                at: clock.now()
            )
        )

        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .event,
                message: "Emitted \(eventType.rawValue)",
                payload: try payloadString(event)
            )
        )

        return try await process(
            event: event,
            configuration: configuration,
            payloadSummary: "\(eventType.rawValue) place=\(placeName) confidence=\(signal.weight)"
        )
    }

    private func process(
        event: ContextEvent,
        configuration: RuntimeConfiguration,
        payloadSummary: String
    ) async throws -> ProcessingResult {
        let state = try await store.loadRuntimeState()
        let baseSnapshot = await snapshotEnricher.buildSnapshot(at: clock.now(), state: state)
        let snapshot = applyPlaceSharing(to: baseSnapshot, configuration: configuration)
        let policy = policyEngine.decide(event: event, snapshot: snapshot)
        let envelope = SenseKitEventEnvelope(
            deviceID: configuration.deviceID,
            event: event,
            snapshot: snapshot,
            policy: policy,
            delivery: DeliveryMetadata(attempt: 1, queuedAt: clock.now())
        )
        let queued = QueuedWebhook(eventType: event.eventType, envelope: envelope, queuedAt: clock.now())
        try await store.enqueue(queued)
        try await store.appendAuditEntry(
            AuditLogEntry(
                createdAt: clock.now(),
                eventType: event.eventType.rawValue,
                destination: configuration.openClaw?.endpointURL.absoluteString ?? "unconfigured",
                status: .queued,
                payloadSummary: payloadSummary,
                retryCount: 0
            )
        )

        if let openClaw = configuration.openClaw {
            try await attemptImmediateDelivery(item: queued, configuration: openClaw)
        }

        return ProcessingResult(event: event, queuedWebhookID: queued.id)
    }

    private func payloadString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONCoding.encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    private func nextRetryDate(attempt: Int, from date: Date) -> Date {
        let offsets: [TimeInterval] = [0, 5, 30, 300, 1_800, 7_200, 43_200]
        let index = min(attempt, offsets.count - 1)
        return date.addingTimeInterval(offsets[index])
    }

    private func placeCooldownOK(for eventType: ContextEventType, placeIdentifier: String, state: RuntimeState) -> Bool {
        guard let lastDate = state.lastEventDate(for: eventType, scope: placeIdentifier) else {
            return true
        }

        return clock.now().timeIntervalSince(lastDate) >= 600
    }

    private func applyManualPlaceState(
        for eventType: ContextEventType,
        configuration: RuntimeConfiguration,
        state: inout RuntimeState
    ) -> Bool {
        switch eventType {
        case .arrivedPlace:
            guard let place = configuration.monitoredRegions.first else {
                return false
            }
            state.currentPlace = placeType(for: place.identifier, configuration: configuration)
            state.currentPlaceIdentifier = place.identifier
            state.currentPlaceName = place.displayName ?? legacyPlaceName(for: place.identifier)
            state.setLastEventDate(clock.now(), for: eventType, scope: place.identifier)
            return true
        case .leftPlace:
            let placeIdentifier = state.currentPlaceIdentifier
            RuntimeStateReducer.apply(eventType, at: clock.now(), to: &state)
            if let placeIdentifier {
                state.setLastEventDate(clock.now(), for: eventType, scope: placeIdentifier)
            }
            return true
        default:
            return false
        }
    }

    private func applyPlaceSharing(to snapshot: ContextSnapshot, configuration: RuntimeConfiguration) -> ContextSnapshot {
        guard configuration.placeSharingMode == .preciseCoordinates else {
            return snapshot
        }

        let coordinate = placeCoordinate(
            from: configuration.region(for: snapshot.place.identifier)
                ?? legacyPlaceRegion(for: snapshot.place.type, configuration: configuration)
        )

        guard let coordinate else {
            return snapshot
        }

        var place = snapshot.place
        place.coordinate = coordinate
        return snapshot.withPlace(place)
    }

    private func placeCoordinate(from region: RegionConfiguration?) -> ContextSnapshot.Place.Coordinate? {
        guard let region else {
            return nil
        }

        return ContextSnapshot.Place.Coordinate(
            latitude: region.latitude,
            longitude: region.longitude
        )
    }

    private func dedupeKey(for eventType: ContextEventType, deviceID: String, scope: String, at date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        let minutePrefix = formatter.string(from: date).prefix(16)
        return "\(deviceID):\(eventType.rawValue):\(scope):\(minutePrefix)"
    }

    private func legacyPlaceRegion(for placeType: PlaceType, configuration: RuntimeConfiguration) -> RegionConfiguration? {
        switch placeType {
        case .home:
            return configuration.homeRegion
        case .work:
            return configuration.workRegion
        case .custom, .other:
            return nil
        }
    }

    private func legacyPlaceName(for identifier: String) -> String? {
        switch identifier {
        case "home":
            return "Home"
        case "work":
            return "Work"
        default:
            return nil
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
}

private struct HealthSnapshotChange {
    static let signalKey = "health.snapshot_changed"

    let domains: [String]

    init?(signal: ContextSignal) {
        guard signal.signalKey == Self.signalKey else { return nil }
        if case .array(let values)? = signal.payload["domains"] {
            self.domains = values.compactMap {
                guard case .string(let domain) = $0 else { return nil }
                return domain
            }
        } else {
            self.domains = []
        }
    }

    var reasons: [String] {
        guard !domains.isEmpty else {
            return ["health.snapshot_changed"]
        }
        return domains.map { "health_domain.\($0)" }
    }
}

private struct PlaceTransition {
    enum Kind {
        case enter
        case exit
    }

    let kind: Kind
    let identifier: String
    let name: String?

    init?(signal: ContextSignal) {
        switch signal.signalKey {
        case "location.region_enter_place":
            kind = .enter
        case "location.region_exit_place":
            kind = .exit
        default:
            return nil
        }

        guard case .string(let identifier)? = signal.payload["place_identifier"] else {
            return nil
        }

        self.identifier = identifier
        if case .string(let name)? = signal.payload["place_name"] {
            self.name = name
        } else {
            self.name = nil
        }
    }
}
