import SwiftUI
import SenseKitRuntime

public struct AuditLogView: View {
    private let entries: [AuditLogEntry]
    private let availableEventTypes: [String]
    @Binding private var selectedEventType: String?
    @State private var copiedEntryID: String?
    @State private var inspectionState = AuditLogInspectionState()

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
        let displayedEntries = inspectionState.displayedEntries(liveEntries: entries)
        let displayedEventTypes = inspectionState.displayedAvailableEventTypes(liveAvailableEventTypes: availableEventTypes)

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Audit is the delivery ledger. It shows which outbound signal batches were queued, delivered, or failed on the way to OpenClaw, and lets you inspect the exact JSON body that was sent.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if inspectionState.isInspectingPayload {
                        Text("Live updates are paused while exact JSON is open.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
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

                        ForEach(displayedEventTypes, id: \.self) { eventType in
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
                .disabled(inspectionState.isInspectingPayload)
            } header: {
                Text("Show Event Type")
            }

            Section {
                if displayedEntries.isEmpty {
                    Text("No outbound signal batches for this filter yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(displayedEntries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
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
                            if let payload = entry.payload, !payload.isEmpty {
                                DisclosureGroup(
                                    "Show exact JSON sent",
                                    isExpanded: payloadDisclosureBinding(for: entry.id)
                                ) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("OpenClaw receives this exact request body.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        ScrollView(.horizontal, showsIndicators: true) {
                                            Text(payload)
                                                .font(.system(.caption, design: .monospaced))
                                                .textSelection(.enabled)
                                                .padding(10)
                                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                .font(.footnote)
                            }
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

    private func payloadDisclosureBinding(for entryID: String) -> Binding<Bool> {
        Binding(
            get: {
                inspectionState.expandedEntryIDs.contains(entryID)
            },
            set: { isExpanded in
                inspectionState.setPayloadExpanded(
                    isExpanded,
                    for: entryID,
                    liveEntries: entries,
                    liveAvailableEventTypes: availableEventTypes
                )
            }
        )
    }
}
