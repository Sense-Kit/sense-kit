import SwiftUI
import SenseKitRuntime

public struct AuditLogView: View {
    private let entries: [AuditLogEntry]
    @State private var copiedEntryID: String?

    public init(entries: [AuditLogEntry]) {
        self.entries = entries
    }

    public var body: some View {
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.eventType)
                        .font(.headline)
                    Spacer()
                    Button {
                        ClipboardWriter.copy(EntryCopyFormatter.auditEntry(entry))
                        copiedEntryID = entry.id
                    } label: {
                        Image(systemName: copiedEntryID == entry.id ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundStyle(copiedEntryID == entry.id ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Copy audit entry")

                    Text(entry.status.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(entry.destination)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.payloadSummary)
                    .font(.footnote)
                Text(entry.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .textSelection(.enabled)
            .contextMenu {
                Button("Copy Entry") {
                    ClipboardWriter.copy(EntryCopyFormatter.auditEntry(entry))
                    copiedEntryID = entry.id
                }
            }
        }
        .navigationTitle("Audit Log")
    }
}
