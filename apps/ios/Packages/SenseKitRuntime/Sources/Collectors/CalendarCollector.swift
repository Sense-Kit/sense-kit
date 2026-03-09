import Foundation

#if canImport(EventKit)
import EventKit

public actor CalendarSnapshotProvider: SnapshotProvider {
    private let store = EKEventStore()

    public init() {}

    public func currentSnapshot(at date: Date, state: RuntimeState) async -> ContextSnapshot {
        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: date, end: date.addingTimeInterval(4 * 3_600), calendars: calendars)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        let currentEvent = events.first(where: { $0.startDate <= date && $0.endDate >= date })
        let nextEvent = events.first(where: { $0.startDate > date })
        let nextMeetingMinutes = nextEvent.map { Int($0.startDate.timeIntervalSince(date) / 60) }

        return ContextSnapshot(
            capturedAt: date,
            routine: .init(awake: state.lastWakeAt != nil, focus: nil, workout: state.isWorkoutActive ? .active : .inactive),
            place: .init(type: state.currentPlace, freshness: .recent),
            calendar: .init(inMeeting: currentEvent != nil, nextMeetingInMin: nextMeetingMinutes, freshness: .live),
            device: .init(batteryPercentBucket: 100, charging: false)
        )
    }
}
#endif

