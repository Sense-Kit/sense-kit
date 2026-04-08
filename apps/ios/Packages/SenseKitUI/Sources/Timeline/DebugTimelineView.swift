import SwiftUI
import SenseKitRuntime

public struct DebugTimelineView: View {
    private let entries: [DebugTimelineEntry]
    private let availableFilters: [TimelineServiceFilter]
    @Binding private var selectedFilter: TimelineServiceFilter
    @State private var copiedEntryID: String?

    public init(
        entries: [DebugTimelineEntry],
        availableFilters: [TimelineServiceFilter],
        selectedFilter: Binding<TimelineServiceFilter>
    ) {
        self.entries = entries
        self.availableFilters = availableFilters
        _selectedFilter = selectedFilter
    }

    public var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableFilters, id: \.self) { filter in
                            FilterChip(
                                title: filter.title,
                                isSelected: filter == selectedFilter,
                                tint: serviceTint(for: filter)
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Show Service")
            }

            Section {
                if entries.isEmpty {
                    Text("No timeline entries for this filter yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(TimelineServiceFilter.inferredService(for: entry).title)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(serviceTint(for: TimelineServiceFilter.inferredService(for: entry)).opacity(0.14))
                                    .clipShape(Capsule())

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
                }
            }
        }
        .navigationTitle("Debug Timeline")
    }

    private func serviceTint(for filter: TimelineServiceFilter) -> Color {
        switch filter {
        case .all:
            return .accentColor
        case .runtime:
            return .gray
        case .settings:
            return .blue
        case .motion:
            return .green
        case .location:
            return .orange
        case .processing:
            return .mint
        case .delivery:
            return .teal
        }
    }
}
