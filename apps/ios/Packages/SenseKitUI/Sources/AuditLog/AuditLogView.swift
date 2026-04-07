import SwiftUI
import SenseKitRuntime

public struct AuditLogView: View {
    private let entries: [AuditLogEntry]
    private let availableEventTypes: [String]
    @Binding private var selectedEventType: String?
    @State private var copiedEntryID: String?

    public init(
        entries: [AuditLogEntry],
        availableEventTypes: [String],
        selectedEventType: Binding<String?>
    ) {
        self.entries = entries
        self.availableEventTypes = availableEventTypes
        _selectedEventType = selectedEventType
    }

    public var body: some View {
        List {
            Section {
                Text("Audit is the delivery ledger. It shows which outbound events were queued, delivered, or failed on the way to OpenClaw.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedEventType == nil,
                            tint: .accentColor
                        ) {
                            selectedEventType = nil
                        }

                        ForEach(availableEventTypes, id: \.self) { eventType in
                            FilterChip(
                                title: AuditEventFilter.title(for: eventType),
                                isSelected: selectedEventType == eventType,
                                tint: .teal
                            ) {
                                selectedEventType = eventType
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Show Event Type")
            }

            Section {
                if entries.isEmpty {
                    Text("No outbound events for this filter yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
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
                }
            }
        }
        .navigationTitle("Audit Log")
    }
}
