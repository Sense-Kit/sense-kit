import Foundation

enum RuntimeStateReducer {
    static func apply(_ eventType: ContextEventType, at date: Date, to state: inout RuntimeState) {
        state.setLastEventDate(date, for: eventType)

        switch eventType {
        case .motionActivityObserved:
            break
        case .healthSnapshotUpdated:
            break
        case .wakeConfirmed:
            state.lastWakeAt = date
        case .drivingStarted:
            state.isDriving = true
        case .drivingStopped:
            state.isDriving = false
        case .arrivedPlace:
            state.currentPlace = .custom
        case .leftPlace:
            state.currentPlace = .other
            state.currentPlaceIdentifier = nil
            state.currentPlaceName = nil
        case .arrivedHome:
            state.currentPlace = .home
            state.currentPlaceIdentifier = "home"
            state.currentPlaceName = "Home"
        case .leftHome:
            state.currentPlace = .other
            state.currentPlaceIdentifier = nil
            state.currentPlaceName = nil
        case .arrivedWork:
            state.currentPlace = .work
            state.currentPlaceIdentifier = "work"
            state.currentPlaceName = "Work"
        case .leftWork:
            state.currentPlace = .other
            state.currentPlaceIdentifier = nil
            state.currentPlaceName = nil
        case .workoutStarted:
            state.isWorkoutActive = true
        case .workoutEnded:
            state.isWorkoutActive = false
        case .focusOn, .focusOff:
            break
        }
    }
}
