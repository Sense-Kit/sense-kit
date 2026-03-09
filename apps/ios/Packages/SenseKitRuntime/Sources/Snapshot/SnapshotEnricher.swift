import Foundation

public protocol SnapshotProvider: Sendable {
    func currentSnapshot(at date: Date, state: RuntimeState) async -> ContextSnapshot
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

public actor SnapshotEnricher {
    private let provider: SnapshotProvider

    public init(provider: SnapshotProvider = DefaultSnapshotProvider()) {
        self.provider = provider
    }

    public func buildSnapshot(at date: Date, state: RuntimeState) async -> ContextSnapshot {
        await provider.currentSnapshot(at: date, state: state)
    }
}

