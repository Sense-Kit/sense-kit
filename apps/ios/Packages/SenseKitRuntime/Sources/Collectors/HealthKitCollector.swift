import Foundation

#if os(iOS) && canImport(HealthKit)
import HealthKit

@MainActor
public final class HealthKitCollector: NSObject, ContextSignalCollector {
    private let healthStore = HKHealthStore()
    private let signalHandler: SignalHandler
    private var observerQuery: HKObserverQuery?

    public init(signalHandler: @escaping SignalHandler) {
        self.signalHandler = signalHandler
        super.init()
    }

    public func start() async {
        let workoutType = HKObjectType.workoutType()
        observerQuery = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completion, error in
            defer { completion() }
            guard let self, error == nil else { return }
            Task { @MainActor in
                await self.fetchLatestWorkout()
            }
        }

        if let observerQuery {
            healthStore.execute(observerQuery)
            try? await healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate)
        }
    }

    public func stop() {
        if let observerQuery {
            healthStore.stop(observerQuery)
        }
    }

    private func fetchLatestWorkout() async {
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3_600), end: Date(), options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let self, let workout = samples?.first as? HKWorkout else { return }
            let now = Date()
            let signalKey = workout.endDate >= now.addingTimeInterval(-600) ? "health.workout_sample_ended" : "health.workout_sample_started"
            Task {
                await self.signalHandler(
                    ContextSignal(
                        signalKey: signalKey,
                        source: "healthkit_observer",
                        weight: 0.85,
                        polarity: .support,
                        observedAt: now,
                        validForSec: 600
                    )
                )
            }
        }
        healthStore.execute(query)
    }
}
#else
public final class HealthKitCollector: ContextSignalCollector {
    public init(signalHandler: @escaping SignalHandler) {}
    public func start() async {}
    public func stop() {}
}
#endif
