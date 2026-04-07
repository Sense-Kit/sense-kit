import Foundation

struct MotionActivityObservation: Equatable, Sendable {
    static let signalKey = "motion.activity_observed"

    let primaryKind: String
    let flags: [String]
    let confidence: String

    init(primaryKind: String, flags: [String], confidence: String) {
        let normalizedFlags = Array(Set(flags)).sorted()
        self.primaryKind = primaryKind
        self.flags = normalizedFlags.isEmpty ? ["unknown"] : normalizedFlags
        self.confidence = confidence
    }

    init?(signal: ContextSignal) {
        guard signal.signalKey == Self.signalKey else { return nil }
        guard case .string(let primaryKind)? = signal.payload["primary_kind"] else { return nil }
        guard case .string(let confidence)? = signal.payload["confidence"] else { return nil }

        var flags: [String] = []
        if case .array(let values)? = signal.payload["flags"] {
            flags = values.compactMap { value in
                guard case .string(let flag) = value else { return nil }
                return flag
            }
        }

        self.init(primaryKind: primaryKind, flags: flags, confidence: confidence)
    }

    var reasons: [String] {
        ["motion.primary.\(primaryKind)", "motion.confidence.\(confidence)"] + flags.map { "motion.flag.\($0)" }
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

    func makeSignal(observedAt: Date, signalID: String = UUID().uuidString) -> ContextSignal {
        ContextSignal(
            signalID: signalID,
            signalKey: Self.signalKey,
            source: "coremotion_activity",
            weight: confidenceScore,
            polarity: .support,
            observedAt: observedAt,
            validForSec: 1,
            payload: [
                "primary_kind": .string(primaryKind),
                "confidence": .string(confidence),
                "flags": .array(flags.map(JSONValue.string))
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
            flags: activityFlags(activity),
            confidence: activity.confidence.description
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

    private func activityFlags(_ activity: CMMotionActivity) -> [String] {
        var flags: [String] = []
        if activity.automotive { flags.append("automotive") }
        if activity.walking { flags.append("walking") }
        if activity.running { flags.append("running") }
        if activity.stationary { flags.append("stationary") }
        if activity.cycling { flags.append("cycling") }
        if flags.isEmpty { flags.append("unknown") }
        return flags
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
