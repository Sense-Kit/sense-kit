import Foundation

struct MotionActivityObservation: Equatable, Sendable {
    static let signalKey = "motion.activity_observed"

    let primaryKind: String
    let confidence: String
    let automotive: Bool
    let walking: Bool
    let running: Bool
    let stationary: Bool
    let cycling: Bool

    init(
        primaryKind: String,
        confidence: String,
        automotive: Bool,
        walking: Bool,
        running: Bool,
        stationary: Bool,
        cycling: Bool
    ) {
        self.primaryKind = primaryKind
        self.confidence = confidence
        self.automotive = automotive
        self.walking = walking
        self.running = running
        self.stationary = stationary
        self.cycling = cycling
    }

    init?(signal: ContextSignal) {
        guard signal.signalKey == Self.signalKey else { return nil }
        guard case .string(let primaryKind)? = signal.payload["primary_kind"] else { return nil }
        guard case .string(let confidence)? = signal.payload["confidence"] else { return nil }
        let automotive = signal.payload.boolValue(for: "automotive")
        let walking = signal.payload.boolValue(for: "walking")
        let running = signal.payload.boolValue(for: "running")
        let stationary = signal.payload.boolValue(for: "stationary")
        let cycling = signal.payload.boolValue(for: "cycling")

        self.init(
            primaryKind: primaryKind,
            confidence: confidence,
            automotive: automotive,
            walking: walking,
            running: running,
            stationary: stationary,
            cycling: cycling
        )
    }

    var reasons: [String] {
        [
            "motion.primary.\(primaryKind)",
            "motion.confidence.\(confidence)"
        ] + flags.map { "motion.flag.\($0)" }
    }

    var confidenceScore: Double {
        switch confidence {
        case "high":
            return 1.0
        case "medium":
            return 0.67
        case "low":
            return 0.34
        default:
            return 0.5
        }
    }

    var flags: [String] {
        var flags: [String] = []
        if automotive { flags.append("automotive") }
        if walking { flags.append("walking") }
        if running { flags.append("running") }
        if stationary { flags.append("stationary") }
        if cycling { flags.append("cycling") }
        if flags.isEmpty { flags.append("unknown") }
        return flags
    }

    func makeSignal(observedAt: Date, signalID: String = UUID().uuidString) -> ContextSignal {
        ContextSignal(
            signalID: signalID,
            signalKey: Self.signalKey,
            collector: .motion,
            source: "coremotion_activity",
            weight: confidenceScore,
            polarity: .support,
            observedAt: observedAt,
            receivedAt: observedAt,
            validForSec: 1,
            payload: [
                "primary_kind": .string(primaryKind),
                "confidence": .string(confidence),
                "flags": .array(flags.map(JSONValue.string)),
                "automotive": .bool(automotive),
                "walking": .bool(walking),
                "running": .bool(running),
                "stationary": .bool(stationary),
                "cycling": .bool(cycling)
            ]
        )
    }
}

#if os(iOS) && canImport(CoreMotion)
import CoreMotion

@MainActor
public final class MotionCollector: NSObject, ContextSignalCollector {
    private let activityManager = CMMotionActivityManager()
    private let signalHandler: SignalHandler
    private let clock: Clock

    private var lastObservation: MotionActivityObservation?

    public init(signalHandler: @escaping SignalHandler, clock: Clock = SystemClock()) {
        self.signalHandler = signalHandler
        self.clock = clock
        super.init()
    }

    public func start() async {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            self.handle(activity: activity)
        }
    }

    public func stop() {
        activityManager.stopActivityUpdates()
    }

    private func handle(activity: CMMotionActivity) {
        let now = clock.now()
        let observation = MotionActivityObservation(
            primaryKind: primaryKind(activity),
            confidence: activity.confidence.description,
            automotive: activity.automotive,
            walking: activity.walking,
            running: activity.running,
            stationary: activity.stationary,
            cycling: activity.cycling
        )
        guard observation != lastObservation else { return }
        lastObservation = observation

        Task {
            await signalHandler(observation.makeSignal(observedAt: now))
        }
    }

    private func primaryKind(_ activity: CMMotionActivity) -> String {
        if activity.automotive { return "automotive" }
        if activity.walking { return "walking" }
        if activity.running { return "running" }
        if activity.stationary { return "stationary" }
        if activity.cycling { return "cycling" }
        return "unknown"
    }

}

private extension CMMotionActivityConfidence {
    var description: String {
        switch self {
        case .low: "low"
        case .medium: "medium"
        case .high: "high"
        @unknown default: "unknown"
        }
    }
}
#else
public final class MotionCollector: ContextSignalCollector {
    public init(signalHandler: @escaping SignalHandler, clock: Clock = SystemClock()) {}
    public func start() async {}
    public func stop() {}
}
#endif

private extension Dictionary where Key == String, Value == JSONValue {
    func boolValue(for key: String) -> Bool {
        guard case .bool(let value)? = self[key] else {
            return false
        }
        return value
    }
}
