import Foundation

public protocol SnapshotProvider: Sendable {
    func currentSnapshot(at date: Date, state: RuntimeState) async -> ContextSnapshot
}

public protocol HealthSnapshotProviding: Sendable {
    func currentHealthSnapshot(at date: Date, state: RuntimeState) async -> HealthSnapshot
}

public struct DefaultSnapshotProvider: SnapshotProvider {
    public init() {}

    public func currentSnapshot(at date: Date, state: RuntimeState) async -> ContextSnapshot {
        ContextSnapshot(
            capturedAt: date,
            routine: .init(
                awake: state.lastWakeAt != nil,
                focus: nil,
                workout: state.isWorkoutActive ? .active : .inactive
            ),
            place: .init(type: state.currentPlace, freshness: .recent),
            calendar: .init(inMeeting: false, nextMeetingInMin: nil, freshness: .stale),
            device: .init(batteryPercentBucket: 100, charging: false)
        )
    }
}

public struct DefaultHealthSnapshotProvider: HealthSnapshotProviding {
    public init() {}

    public func currentHealthSnapshot(at date: Date, state: RuntimeState) async -> HealthSnapshot {
        .empty(capturedAt: date)
    }
}

public actor SnapshotEnricher {
    private let provider: SnapshotProvider
    private let healthProvider: HealthSnapshotProviding

    public init(
        provider: SnapshotProvider = DefaultSnapshotProvider(),
        healthProvider: HealthSnapshotProviding = DefaultHealthSnapshotProvider()
    ) {
        self.provider = provider
        self.healthProvider = healthProvider
    }

    public func buildSnapshot(at date: Date, state: RuntimeState) async -> ContextSnapshot {
        let snapshot = await provider.currentSnapshot(at: date, state: state)
        let health = await healthProvider.currentHealthSnapshot(at: date, state: state)
        return snapshot.withHealth(health)
    }
}
