import Foundation

public struct EventConfiguration: Sendable {
    public let eventType: ContextEventType
    public let threshold: Double
    public let cooldownSec: Int
    public let supportSignalKeys: Set<String>
    public let opposeSignalKeys: Set<String>
    public let modeHint: ModeHint

    public init(
        eventType: ContextEventType,
        threshold: Double,
        cooldownSec: Int,
        supportSignalKeys: Set<String>,
        opposeSignalKeys: Set<String> = [],
        modeHint: ModeHint
    ) {
        self.eventType = eventType
        self.threshold = threshold
        self.cooldownSec = cooldownSec
        self.supportSignalKeys = supportSignalKeys
        self.opposeSignalKeys = opposeSignalKeys
        self.modeHint = modeHint
    }
}

public enum EventCatalog {
    public static let configurations: [ContextEventType: EventConfiguration] = [
        .wakeConfirmed: EventConfiguration(
            eventType: .wakeConfirmed,
            threshold: 0.70,
            cooldownSec: 43_200,
            supportSignalKeys: [
                "motion.stationary_to_walking_after_rest",
                "motion.walking_sustained_60s",
                "power.charger_disconnected_recently",
                "shortcut.alarm_dismissed"
            ],
            modeHint: .textBrief
        ),
        .drivingStarted: EventConfiguration(
            eventType: .drivingStarted,
            threshold: 0.65,
            cooldownSec: 900,
            supportSignalKeys: [
                "motion.automotive_entered",
                "motion.automotive_sustained_180s",
                "location.significant_change_while_automotive",
                "location.speed_above_18_kmh"
            ],
            opposeSignalKeys: [
                "motion.walking_or_running",
                "workout.active"
            ],
            modeHint: .voiceSafe
        ),
        .drivingStopped: EventConfiguration(
            eventType: .drivingStopped,
            threshold: 0.60,
            cooldownSec: 300,
            supportSignalKeys: [
                "motion.non_automotive_sustained_180s",
                "location.speed_below_5_kmh_sustained_120s",
                "place.arrived_home_or_work",
                "place.arrived_saved_place",
                "motion.walking_after_automotive"
            ],
            opposeSignalKeys: [
                "motion.automotive_entered"
            ],
            modeHint: .normal
        ),
        .arrivedHome: EventConfiguration(
            eventType: .arrivedHome,
            threshold: 0.85,
            cooldownSec: 600,
            supportSignalKeys: [
                "location.region_enter_home",
                "location.speed_below_8_kmh"
            ],
            opposeSignalKeys: [
                "location.speed_high"
            ],
            modeHint: .normal
        ),
        .leftHome: EventConfiguration(
            eventType: .leftHome,
            threshold: 0.85,
            cooldownSec: 600,
            supportSignalKeys: [
                "location.region_exit_home",
                "location.significant_change_after_exit"
            ],
            modeHint: .normal
        ),
        .arrivedWork: EventConfiguration(
            eventType: .arrivedWork,
            threshold: 0.85,
            cooldownSec: 600,
            supportSignalKeys: [
                "location.region_enter_work",
                "location.speed_below_8_kmh"
            ],
            opposeSignalKeys: [
                "location.speed_high"
            ],
            modeHint: .normal
        ),
        .leftWork: EventConfiguration(
            eventType: .leftWork,
            threshold: 0.85,
            cooldownSec: 600,
            supportSignalKeys: [
                "location.region_exit_work",
                "location.significant_change_after_exit"
            ],
            modeHint: .normal
        ),
        .workoutStarted: EventConfiguration(
            eventType: .workoutStarted,
            threshold: 0.85,
            cooldownSec: 1_800,
            supportSignalKeys: [
                "health.workout_sample_started",
                "shortcut.workout_started"
            ],
            modeHint: .textBrief
        ),
        .workoutEnded: EventConfiguration(
            eventType: .workoutEnded,
            threshold: 0.85,
            cooldownSec: 1_800,
            supportSignalKeys: [
                "health.workout_sample_ended",
                "shortcut.workout_ended"
            ],
            modeHint: .textBrief
        ),
        .focusOn: EventConfiguration(
            eventType: .focusOn,
            threshold: 1.0,
            cooldownSec: 60,
            supportSignalKeys: [
                "shortcut.focus_on"
            ],
            modeHint: .textBrief
        ),
        .focusOff: EventConfiguration(
            eventType: .focusOff,
            threshold: 1.0,
            cooldownSec: 60,
            supportSignalKeys: [
                "shortcut.focus_off"
            ],
            modeHint: .textBrief
        )
    ]

    public static func eventTypes(affectedBy signalKey: String) -> [ContextEventType] {
        configurations.values.compactMap { configuration in
            if configuration.supportSignalKeys.contains(signalKey) || configuration.opposeSignalKeys.contains(signalKey) {
                return configuration.eventType
            }
            return nil
        }
    }
}
