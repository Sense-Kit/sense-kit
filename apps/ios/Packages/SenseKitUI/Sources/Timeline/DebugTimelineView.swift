import SwiftUI
import SenseKitRuntime

public struct DebugTimelineView: View {
    private let entries: [DebugTimelineEntry]
    @State private var copiedEntryID: String?

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
                    Button {
                        ClipboardWriter.copy(EntryCopyFormatter.timelineEntry(entry))
                        copiedEntryID = entry.id
                    } label: {
                        Image(systemName: copiedEntryID == entry.id ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundStyle(copiedEntryID == entry.id ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Copy timeline entry")

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
            .textSelection(.enabled)
            .contextMenu {
                Button("Copy Entry") {
                    ClipboardWriter.copy(EntryCopyFormatter.timelineEntry(entry))
                    copiedEntryID = entry.id
                }
            }
        }
        .navigationTitle("Debug Timeline")
    }
}
