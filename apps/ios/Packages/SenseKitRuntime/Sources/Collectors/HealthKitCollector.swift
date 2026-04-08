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
        guard HKHealthStore.isHealthDataAvailable() else { return }
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
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: now.addingTimeInterval(-86_400), end: now, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let self, let workout = samples?.first as? HKWorkout else { return }
            let observedAt = Date()
            Task {
                await self.signalHandler(
                    ContextSignal(
                        signalKey: "health.workout_sample_observed",
                        collector: .health,
                        source: "healthkit_observer",
                        weight: 1.0,
                        polarity: .support,
                        observedAt: observedAt,
                        receivedAt: observedAt,
                        validForSec: 3_600,
                        payload: self.workoutPayload(from: workout)
                    )
                )
            }
        }
        healthStore.execute(query)
    }

    private func workoutPayload(from workout: HKWorkout) -> [String: JSONValue] {
        var payload: [String: JSONValue] = [
            "uuid": .string(workout.uuid.uuidString),
            "activity_type": .string(String(workout.workoutActivityType.rawValue)),
            "start_at": .string(ISO8601DateFormatter().string(from: workout.startDate)),
            "end_at": .string(ISO8601DateFormatter().string(from: workout.endDate)),
            "duration_sec": .number(workout.duration)
        ]

        if let totalEnergy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
            payload["total_energy_kcal"] = .number(totalEnergy)
        }

        if let totalDistance = workout.totalDistance?.doubleValue(for: .meter()) {
            payload["total_distance_m"] = .number(totalDistance)
        }

        if let metadata = workout.metadata, !metadata.isEmpty {
            payload["metadata_keys"] = .array(metadata.keys.sorted().map(JSONValue.string))
        }

        return payload
    }
}
#else
public final class HealthKitCollector: ContextSignalCollector {
    public init(signalHandler: @escaping SignalHandler) {}
    public func start() async {}
    public func stop() {}
}
#endif
