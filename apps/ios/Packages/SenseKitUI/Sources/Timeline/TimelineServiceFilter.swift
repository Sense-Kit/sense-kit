import Foundation
import SenseKitRuntime

public enum TimelineServiceFilter: String, CaseIterable, Sendable {
    case all
    case runtime
    case settings
    case motion
    case location
    case rules
    case delivery

    public var title: String {
        switch self {
        case .all:
            return "All"
        case .runtime:
            return "Runtime"
        case .settings:
            return "Settings"
        case .motion:
            return "Motion"
        case .location:
            return "Location"
        case .rules:
            return "Rules"
        case .delivery:
            return "Delivery"
        }
    }

    public func includes(_ entry: DebugTimelineEntry) -> Bool {
        switch self {
        case .all:
            return true
        case .runtime:
            return Self.inferredService(for: entry) == .runtime
        case .settings:
            return Self.inferredService(for: entry) == .settings
        case .motion:
            return Self.inferredService(for: entry) == .motion
        case .location:
            return Self.inferredService(for: entry) == .location
        case .rules:
            return Self.inferredService(for: entry) == .rules
        case .delivery:
            return Self.inferredService(for: entry) == .delivery
        }
    }

    public static func availableFilters(for entries: [DebugTimelineEntry]) -> [TimelineServiceFilter] {
        let present = Set(entries.map(inferredService))
        return [.all] + [.runtime, .settings, .motion, .location, .rules, .delivery].filter { present.contains($0) }
    }

    static func inferredService(for entry: DebugTimelineEntry) -> TimelineServiceFilter {
        let message = entry.message.lowercased()
        let payload = entry.payload?.lowercased() ?? ""
        let combined = "\(message) \(payload)"

        if combined.contains("saved runtime configuration")
            || combined.contains("captured current location")
            || combined.contains("resolved address") {
            return .settings
        }

        if combined.contains("motion")
            || combined.contains("walking")
            || combined.contains("running")
            || combined.contains("stationary")
            || combined.contains("automotive")
            || combined.contains("cycling") {
            return .motion
        }

        if combined.contains("location")
            || combined.contains("home")
            || combined.contains("work")
            || combined.contains("region")
            || combined.contains("place.") {
            return .location
        }

        if entry.category == .delivery || combined.contains("http ") || combined.contains("queued") || combined.contains("delivered") {
            return .delivery
        }

        if entry.category == .event || entry.category == .evaluation {
            return .rules
        }

        return .runtime
    }
}
