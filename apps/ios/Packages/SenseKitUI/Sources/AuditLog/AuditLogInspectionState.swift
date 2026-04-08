import SenseKitRuntime

struct AuditLogInspectionState {
    private(set) var expandedEntryIDs: Set<String> = []
    private(set) var frozenEntries: [AuditLogEntry]?
    private(set) var frozenAvailableEventTypes: [String]?

    var isInspectingPayload: Bool {
        !expandedEntryIDs.isEmpty
    }

    func displayedEntries(liveEntries: [AuditLogEntry]) -> [AuditLogEntry] {
        frozenEntries ?? liveEntries
    }

    func displayedAvailableEventTypes(liveAvailableEventTypes: [String]) -> [String] {
        frozenAvailableEventTypes ?? liveAvailableEventTypes
    }

    mutating func setPayloadExpanded(
        _ isExpanded: Bool,
        for entryID: String,
        liveEntries: [AuditLogEntry],
        liveAvailableEventTypes: [String]
    ) {
        if isExpanded {
            if expandedEntryIDs.isEmpty {
                frozenEntries = liveEntries
                frozenAvailableEventTypes = liveAvailableEventTypes
            }
            expandedEntryIDs.insert(entryID)
            return
        }

        expandedEntryIDs.remove(entryID)
        if expandedEntryIDs.isEmpty {
            frozenEntries = nil
            frozenAvailableEventTypes = nil
        }
    }
}
