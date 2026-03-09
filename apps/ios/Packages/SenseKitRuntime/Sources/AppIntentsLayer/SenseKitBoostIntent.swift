import Foundation

#if os(iOS) && canImport(AppIntents)
import AppIntents

public enum SenseKitBoostType: String, AppEnum {
    case alarmDismissed = "shortcut.alarm_dismissed"
    case workoutStarted = "shortcut.workout_started"
    case workoutEnded = "shortcut.workout_ended"
    case focusOn = "shortcut.focus_on"
    case focusOff = "shortcut.focus_off"

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "SenseKit Boost")
    public static let caseDisplayRepresentations: [SenseKitBoostType: DisplayRepresentation] = [
        .alarmDismissed: "Alarm Dismissed",
        .workoutStarted: "Workout Started",
        .workoutEnded: "Workout Ended",
        .focusOn: "Focus On",
        .focusOff: "Focus Off"
    ]
}

public struct SenseKitBoostIntent: AppIntent {
    public static let title: LocalizedStringResource = "Send SenseKit Boost"
    public static let description = IntentDescription("Injects an optional Shortcuts precision boost into the SenseKit runtime.")

    @Parameter(title: "Boost Type")
    public var boostType: SenseKitBoostType

    public init() {}

    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .senseKitBoostTriggered,
            object: nil,
            userInfo: ["signal_key": boostType.rawValue]
        )
        return .result()
    }
}

public struct SenseKitAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: SenseKitBoostIntent(),
                phrases: ["Run SenseKit boost in \(.applicationName)"],
                shortTitle: "SenseKit Boost",
                systemImageName: "bolt.circle"
            )
        ]
    }
}

public struct SenseKitRuntimeAppIntentsPackage: AppIntentsPackage {}
#endif

public extension Notification.Name {
    static let senseKitBoostTriggered = Notification.Name("sensekit.boost.triggered")
}
