import SwiftUI
import SenseKitRuntime

public struct AuditLogView: View {
    private let entries: [AuditLogEntry]

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
        }
        .navigationTitle("Audit Log")
    }
}

