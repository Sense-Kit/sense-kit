import Foundation

public struct EventEvaluation: Sendable {
    public let event: ContextEvent
    public let score: Double
}

public actor CorroborationEngine {
    private let store: RuntimeStore
    private let configuration: RuntimeConfiguration
    private let clock: Clock

    public init(store: RuntimeStore, configuration: RuntimeConfiguration, clock: Clock = SystemClock()) {
        self.store = store
        self.configuration = configuration
        self.clock = clock
    }

    public func ingest(_ signal: ContextSignal) async throws -> [EventEvaluation] {
        try await store.saveSignal(signal)
        try await store.pruneExpiredSignals(before: clock.now())
        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .signal,
                message: "Received signal \(signal.signalKey)",
                payload: try payloadString(signal)
            )
        )

        var state = try await store.loadRuntimeState()
        var evaluations: [EventEvaluation] = []

        for eventType in EventCatalog.eventTypes(affectedBy: signal.signalKey) {
            if let evaluation = try await evaluate(eventType: eventType, state: &state) {
                evaluations.append(evaluation)
            }
        }

        try await store.saveRuntimeState(state)
        return evaluations
    }

    private func evaluate(eventType: ContextEventType, state: inout RuntimeState) async throws -> EventEvaluation? {
        guard let config = EventCatalog.configurations[eventType] else { return nil }
        let signals = try await store.activeSignals(signalKeys: config.supportSignalKeys.union(config.opposeSignalKeys), at: clock.now())

        guard cooldownOK(for: eventType, config: config, state: state) else {
            try await store.appendDebugEntry(
                DebugTimelineEntry(
                    createdAt: clock.now(),
                    category: .evaluation,
                    message: "Cooldown blocked \(eventType.rawValue)"
                )
            )
            return nil
        }

        guard !hardBlocked(eventType: eventType, state: state) else {
            return nil
        }

        let supportScore = mergedSignals(signals, matching: config.supportSignalKeys, polarity: .support).values.reduce(0, +)
        let opposeScore = mergedSignals(signals, matching: config.opposeSignalKeys, polarity: .oppose).values.reduce(0, +)
        let derivedSupport = derivedSupportScore(for: eventType, state: state)
        let derivedOppose = derivedOpposeScore(for: eventType)
        let score = max(0, min(1, supportScore - opposeScore + derivedSupport - derivedOppose))

        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .evaluation,
                message: "Evaluated \(eventType.rawValue) at score \(String(format: "%.2f", score))",
                payload: "support=\(supportScore + derivedSupport), oppose=\(opposeScore + derivedOppose)"
            )
        )

        guard score >= config.threshold else {
            return nil
        }

        let reasons = Array(mergedSignals(signals, matching: config.supportSignalKeys, polarity: .support).keys).sorted()
        let event = ContextEvent(
            eventType: eventType,
            occurredAt: clock.now(),
            confidence: score,
            reasons: reasons.isEmpty ? ["derived.state"] : reasons,
            modeHint: config.modeHint,
            cooldownSec: config.cooldownSec,
            dedupeKey: dedupeKey(for: eventType, at: clock.now())
        )

        RuntimeStateReducer.apply(eventType, at: clock.now(), to: &state)

        try await store.appendDebugEntry(
            DebugTimelineEntry(
                createdAt: clock.now(),
                category: .event,
                message: "Emitted \(eventType.rawValue)",
                payload: try payloadString(event)
            )
        )

        return EventEvaluation(event: event, score: score)
    }

    private func mergedSignals(_ signals: [ContextSignal], matching keys: Set<String>, polarity: SignalPolarity) -> [String: Double] {
        var result: [String: Double] = [:]
        for signal in signals where keys.contains(signal.signalKey) && signal.polarity == polarity {
            result[signal.signalKey] = max(result[signal.signalKey] ?? 0, signal.weight)
        }
        return result
    }

    private func cooldownOK(for eventType: ContextEventType, config: EventConfiguration, state: RuntimeState) -> Bool {
        guard let lastDate = state.lastEventDate(for: eventType) else {
            return true
        }
        return clock.now().timeIntervalSince(lastDate) >= TimeInterval(config.cooldownSec)
    }

    private func hardBlocked(eventType: ContextEventType, state: RuntimeState) -> Bool {
        switch eventType {
        case .motionActivityObserved:
            return false
        case .healthSnapshotUpdated:
            return false
        case .wakeConfirmed:
            return state.lastWakeAt.map { clock.now().timeIntervalSince($0) < 43_200 } ?? false
        case .drivingStarted:
            return state.isDriving
        case .drivingStopped:
            return !state.isDriving
        case .arrivedPlace, .leftPlace:
            return false
        case .arrivedHome:
            return state.currentPlace == .home
        case .leftHome:
            return state.currentPlace != .home
        case .arrivedWork:
            return state.currentPlace == .work
        case .leftWork:
            return state.currentPlace != .work
        case .workoutStarted:
            return state.isWorkoutActive
        case .workoutEnded:
            return !state.isWorkoutActive
        case .focusOn, .focusOff:
            return false
        }
    }

    private func derivedSupportScore(for eventType: ContextEventType, state: RuntimeState) -> Double {
        switch eventType {
        case .motionActivityObserved:
            return 0
        case .healthSnapshotUpdated:
            return 0
        case .wakeConfirmed:
            return (isWithinWakeWindow(clock.now()) ? 0.15 : 0) + (state.lastWakeAt == nil || clock.now().timeIntervalSince(state.lastWakeAt!) >= 43_200 ? 0.10 : 0)
        case .drivingStarted:
            return state.isDriving ? 0 : 0.05
        case .drivingStopped:
            return state.isDriving ? 0.15 : 0
        case .arrivedPlace, .leftPlace:
            return 0
        case .arrivedHome:
            return state.currentPlace == .home ? 0 : 0.10
        case .leftHome:
            return state.currentPlace == .home ? 0.10 : 0
        case .arrivedWork:
            return state.currentPlace == .work ? 0 : 0.10
        case .leftWork:
            return state.currentPlace == .work ? 0.10 : 0
        case .workoutStarted:
            return state.isWorkoutActive ? 0 : 0
        case .workoutEnded:
            return state.isWorkoutActive ? 0 : 0
        case .focusOn, .focusOff:
            return 0
        }
    }

    private func derivedOpposeScore(for eventType: ContextEventType) -> Double {
        switch eventType {
        case .motionActivityObserved:
            return 0
        case .healthSnapshotUpdated:
            return 0
        case .wakeConfirmed:
            return isWithinWakeWindow(clock.now()) ? 0 : 0.30
        default:
            return 0
        }
    }

    private func isWithinWakeWindow(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= configuration.wakeWindowStartHour && hour < configuration.wakeWindowEndHour
    }

    private func dedupeKey(for eventType: ContextEventType, at date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        let minutePrefix = formatter.string(from: date).prefix(16)
        return "\(configuration.deviceID):\(eventType.rawValue):\(minutePrefix)"
    }

    private func payloadString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONCoding.encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
