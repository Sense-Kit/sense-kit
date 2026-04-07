import Foundation

enum RuntimeStateReducer {
    static func apply(_ eventType: ContextEventType, at date: Date, to state: inout RuntimeState) {
        state.setLastEventDate(date, for: eventType)

        switch eventType {
        case .wakeConfirmed:
            state.lastWakeAt = date
        case .drivingStarted:
            state.isDriving = true
        case .drivingStopped:
            state.isDriving = false
        case .arrivedHome:
            state.currentPlace = .home
        case .leftHome:
            state.currentPlace = .other
        case .arrivedWork:
            state.currentPlace = .work
        case .leftWork:
            state.currentPlace = .other
        case .workoutStarted:
            state.isWorkoutActive = true
        case .workoutEnded:
            state.isWorkoutActive = false
        case .focusOn, .focusOff:
            break
        }
    }
}
