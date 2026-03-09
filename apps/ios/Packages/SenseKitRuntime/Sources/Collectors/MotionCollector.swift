import Foundation

#if os(iOS) && canImport(CoreMotion)
import CoreMotion

@MainActor
public final class MotionCollector: NSObject, ContextSignalCollector {
    private let activityManager = CMMotionActivityManager()
    private let queue = OperationQueue()
    private let signalHandler: SignalHandler
    private let clock: Clock

    private var lastStationaryAt: Date?
    private var lastActivityKind: String?
    private var walkingTask: Task<Void, Never>?
    private var automotiveTask: Task<Void, Never>?
    private var nonAutomotiveTask: Task<Void, Never>?

    public init(signalHandler: @escaping SignalHandler, clock: Clock = SystemClock()) {
        self.signalHandler = signalHandler
        self.clock = clock
        super.init()
        queue.qualityOfService = .utility
    }

    public func start() async {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activityManager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let self, let activity else { return }
            Task { @MainActor in
                await self.handle(activity: activity)
            }
        }
    }

    public func stop() {
        walkingTask?.cancel()
        automotiveTask?.cancel()
        nonAutomotiveTask?.cancel()
        activityManager.stopActivityUpdates()
    }

    private func handle(activity: CMMotionActivity) async {
        let now = clock.now()
        let kind = activityKind(activity)

        if kind == "stationary" {
            lastStationaryAt = now
        }

        if kind == "walking", lastActivityKind == "stationary", let stationaryAt = lastStationaryAt, now.timeIntervalSince(stationaryAt) >= 10_800 {
            await signalHandler(
                ContextSignal(
                    signalKey: "motion.stationary_to_walking_after_rest",
                    source: "coremotion_activity",
                    weight: 0.35,
                    polarity: .support,
                    observedAt: now,
                    validForSec: 120,
                    payload: ["confidence": .string(activity.confidence.description)]
                )
            )
        }

        if kind == "walking" {
            scheduleWalkingConfirmation(startedAt: now)
        } else {
            walkingTask?.cancel()
        }

        if kind == "automotive" {
            await signalHandler(
                ContextSignal(
                    signalKey: "motion.automotive_entered",
                    source: "coremotion_activity",
                    weight: 0.45,
                    polarity: .support,
                    observedAt: now,
                    validForSec: 180,
                    payload: ["confidence": .string(activity.confidence.description)]
                )
            )
            scheduleAutomotiveConfirmation(startedAt: now)
        } else {
            automotiveTask?.cancel()
            scheduleNonAutomotiveConfirmation(startedAt: now)
        }

        if kind == "walking" || kind == "running" {
            await signalHandler(
                ContextSignal(
                    signalKey: "motion.walking_or_running",
                    source: "coremotion_activity",
                    weight: 0.25,
                    polarity: .oppose,
                    observedAt: now,
                    validForSec: 180,
                    payload: ["kind": .string(kind)]
                )
            )
        }

        lastActivityKind = kind
    }

    private func scheduleWalkingConfirmation(startedAt: Date) {
        walkingTask?.cancel()
        walkingTask = Task {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            await signalHandler(
                ContextSignal(
                    signalKey: "motion.walking_sustained_60s",
                    source: "coremotion_activity",
                    weight: 0.20,
                    polarity: .support,
                    observedAt: startedAt.addingTimeInterval(60),
                    validForSec: 120
                )
            )
        }
    }

    private func scheduleAutomotiveConfirmation(startedAt: Date) {
        automotiveTask?.cancel()
        automotiveTask = Task {
            try? await Task.sleep(for: .seconds(180))
            guard !Task.isCancelled else { return }
            await signalHandler(
                ContextSignal(
                    signalKey: "motion.automotive_sustained_180s",
                    source: "coremotion_activity",
                    weight: 0.20,
                    polarity: .support,
                    observedAt: startedAt.addingTimeInterval(180),
                    validForSec: 180
                )
            )
        }
    }

    private func scheduleNonAutomotiveConfirmation(startedAt: Date) {
        nonAutomotiveTask?.cancel()
        nonAutomotiveTask = Task {
            try? await Task.sleep(for: .seconds(180))
            guard !Task.isCancelled else { return }
            await signalHandler(
                ContextSignal(
                    signalKey: "motion.non_automotive_sustained_180s",
                    source: "coremotion_activity",
                    weight: 0.45,
                    polarity: .support,
                    observedAt: startedAt.addingTimeInterval(180),
                    validForSec: 180
                )
            )
        }
    }

    private func activityKind(_ activity: CMMotionActivity) -> String {
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
