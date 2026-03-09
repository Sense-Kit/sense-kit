import SwiftUI
import SenseKitRuntime

public struct DebugTimelineView: View {
    private let entries: [DebugTimelineEntry]

    public init(entries: [DebugTimelineEntry]) {
        self.entries = entries
    }

    public var body: some View {
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.createdAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(entry.message)
                    .font(.body)
                if let payload = entry.payload, !payload.isEmpty {
                    Text(payload)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Debug Timeline")
    }
}

