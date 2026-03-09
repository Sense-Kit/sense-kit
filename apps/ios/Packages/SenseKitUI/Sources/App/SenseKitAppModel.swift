import Foundation
import Observation
import SenseKitRuntime

@Observable
public final class SenseKitAppModel {
    public var selectedFeatures: Set<FeatureFlag>
    public var connectionStatus: String
    public var drivingLocationBoostEnabled: Bool
    public var timelineEntries: [DebugTimelineEntry]
    public var auditEntries: [AuditLogEntry]

    public init(
        selectedFeatures: Set<FeatureFlag> = [.wakeBrief, .drivingMode],
        connectionStatus: String = "Not connected",
        drivingLocationBoostEnabled: Bool = false,
        timelineEntries: [DebugTimelineEntry] = [],
        auditEntries: [AuditLogEntry] = []
    ) {
        self.selectedFeatures = selectedFeatures
        self.connectionStatus = connectionStatus
        self.drivingLocationBoostEnabled = drivingLocationBoostEnabled
        self.timelineEntries = timelineEntries
        self.auditEntries = auditEntries
    }

    public static var preview: SenseKitAppModel {
        SenseKitAppModel(
            selectedFeatures: [.wakeBrief, .drivingMode, .homeWork],
            connectionStatus: "Connected to OpenClaw",
            drivingLocationBoostEnabled: true,
            timelineEntries: [
                DebugTimelineEntry(createdAt: Date(), category: .signal, message: "Received signal motion.automotive_entered"),
                DebugTimelineEntry(createdAt: Date(), category: .event, message: "Emitted driving_started")
            ],
            auditEntries: [
                AuditLogEntry(
                    createdAt: Date(),
                    eventType: "driving_started",
                    destination: "https://gateway.example/hooks/sensekit",
                    status: .delivered,
                    payloadSummary: "HTTP 200",
                    retryCount: 0
                )
            ]
        )
    }
}

