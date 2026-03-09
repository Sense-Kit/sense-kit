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
        let evaluations = try await engine.ingest(signal)
        guard !evaluations.isEmpty else { return [] }

        let configuration = try await settingsStore.load()
        var results: [ProcessingResult] = []

        for evaluation in evaluations {
            let state = try await store.loadRuntimeState()
            let snapshot = await snapshotEnricher.buildSnapshot(at: clock.now(), state: state)
            let policy = policyEngine.decide(event: evaluation.event, snapshot: snapshot)
            let envelope = SenseKitEventEnvelope(
                deviceID: configuration.deviceID,
                event: evaluation.event,
                snapshot: snapshot,
                policy: policy,
                delivery: DeliveryMetadata(attempt: 1, queuedAt: clock.now())
            )
            let queued = QueuedWebhook(eventType: evaluation.event.eventType, envelope: envelope, queuedAt: clock.now())
            try await store.enqueue(queued)
            try await store.appendAuditEntry(
                AuditLogEntry(
                    createdAt: clock.now(),
                    eventType: evaluation.event.eventType.rawValue,
                    destination: configuration.openClaw?.endpointURL.absoluteString ?? "unconfigured",
                    status: .queued,
                    payloadSummary: "\(evaluation.event.eventType.rawValue) confidence=\(evaluation.score)",
                    retryCount: 0
                )
            )

            if let openClaw = configuration.openClaw {
                try await attemptImmediateDelivery(item: queued, configuration: openClaw)
            }

            results.append(ProcessingResult(event: evaluation.event, queuedWebhookID: queued.id))
        }

        return results
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

    private func nextRetryDate(attempt: Int, from date: Date) -> Date {
        let offsets: [TimeInterval] = [0, 5, 30, 300, 1_800, 7_200, 43_200]
        let index = min(attempt, offsets.count - 1)
        return date.addingTimeInterval(offsets[index])
    }
}

