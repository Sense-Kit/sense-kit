import Foundation

public struct PolicyEngine: Sendable {
    public init() {}

    public func decide(event: ContextEvent, snapshot: ContextSnapshot) -> PolicyDecision {
        switch event.eventType {
        case .motionActivityObserved:
            return PolicyDecision(
                eventType: .motionActivityObserved,
                allowedActions: ["update_context"],
                blockedActions: ["send_short_text", "send_voice_note", "send_tts", "send_long_markdown"],
                deliveryChannelPreference: ["short_text"],
                ttlSec: 300
            )
        case .healthSnapshotUpdated:
            return PolicyDecision(
                eventType: .healthSnapshotUpdated,
                allowedActions: ["update_context"],
                blockedActions: ["send_short_text", "send_voice_note", "send_tts", "send_long_markdown"],
                deliveryChannelPreference: ["short_text"],
                ttlSec: 300
            )
        case .wakeConfirmed:
            return PolicyDecision(
                eventType: .wakeConfirmed,
                allowedActions: ["send_short_text", "send_brief_markdown"],
                blockedActions: [],
                deliveryChannelPreference: ["short_text", "markdown"],
                ttlSec: 1_800
            )
        case .drivingStarted:
            return PolicyDecision(
                eventType: .drivingStarted,
                allowedActions: ["send_voice_note", "send_tts", "send_short_text"],
                blockedActions: ["send_long_markdown"],
                deliveryChannelPreference: ["voice_note", "tts", "short_text"],
                ttlSec: 1_800
            )
        case .drivingStopped:
            return PolicyDecision(
                eventType: .drivingStopped,
                allowedActions: ["resume_default_delivery"],
                blockedActions: [],
                deliveryChannelPreference: ["short_text"],
                ttlSec: 600
            )
        case .workoutEnded:
            return PolicyDecision(
                eventType: .workoutEnded,
                allowedActions: ["send_short_text", "send_recovery_followup"],
                blockedActions: [],
                deliveryChannelPreference: ["short_text"],
                ttlSec: 1_800
            )
        default:
            return PolicyDecision(
                eventType: event.eventType,
                allowedActions: ["send_short_text"],
                blockedActions: [],
                deliveryChannelPreference: ["short_text"],
                ttlSec: 1_800
            )
        }
    }
}
