import Foundation
import SenseKitRuntime

public enum AuditEventFilter: String, Sendable, CaseIterable {
    case all

    public var title: String {
        switch self {
        case .all:
            return "All"
        }
    }

    public static func title(for eventType: String) -> String {
        eventType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public static func availableEventTypes(for entries: [AuditLogEntry]) -> [String] {
        Array(Set(entries.map(\.eventType))).sorted()
    }
}
