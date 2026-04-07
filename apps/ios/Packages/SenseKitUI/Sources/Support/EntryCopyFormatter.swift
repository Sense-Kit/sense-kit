import Foundation
import SenseKitRuntime

enum EntryCopyFormatter {
    static func auditEntry(_ entry: AuditLogEntry) -> String {
        [
            "type: audit",
            "created_at: \(timestamp(entry.createdAt))",
            "event_type: \(entry.eventType)",
            "status: \(entry.status.rawValue)",
            "destination: \(entry.destination)",
            "payload_summary: \(entry.payloadSummary)",
            "retry_count: \(entry.retryCount)"
        ].joined(separator: "\n")
    }

    static func timelineEntry(_ entry: DebugTimelineEntry) -> String {
        var lines = [
            "type: timeline",
            "created_at: \(timestamp(entry.createdAt))",
            "service: \(TimelineServiceFilter.inferredService(for: entry).rawValue)",
            "category: \(entry.category.rawValue)",
            "message: \(entry.message)"
        ]

        if let payload = entry.payload, !payload.isEmpty {
            lines.append("payload: \(payload)")
        }

        return lines.joined(separator: "\n")
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
