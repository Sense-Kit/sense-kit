import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public protocol RuntimeStore: Sendable {
    func saveSignal(_ signal: ContextSignal) async throws
    func activeSignals(signalKeys: Set<String>, at date: Date) async throws -> [ContextSignal]
    func pruneExpiredSignals(before date: Date) async throws
    func loadRuntimeState() async throws -> RuntimeState
    func saveRuntimeState(_ state: RuntimeState) async throws
    func appendDebugEntry(_ entry: DebugTimelineEntry) async throws
    func appendAuditEntry(_ entry: AuditLogEntry) async throws
    func enqueue(_ item: QueuedWebhook) async throws
    func dueQueueItems(at date: Date, limit: Int) async throws -> [QueuedWebhook]
    func updateQueueItem(_ item: QueuedWebhook) async throws
    func timelineEntries(limit: Int) async throws -> [DebugTimelineEntry]
    func auditEntries(limit: Int) async throws -> [AuditLogEntry]
}

public actor SQLiteRuntimeStore: RuntimeStore {
    private let connection: SQLiteConnection
    private let path: String

    public init(path: String) throws {
        self.path = path
        var db: OpaquePointer?
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw RuntimeStoreError.openFailed(path: path)
        }
        guard let db else {
            throw RuntimeStoreError.openFailed(path: path)
        }
        self.connection = SQLiteConnection(handle: db)
        try Self.createTables(in: db)
    }

    public func saveSignal(_ signal: ContextSignal) async throws {
        let sql = """
        INSERT OR REPLACE INTO signals (id, signal_key, observed_at, expires_at, json)
        VALUES (?, ?, ?, ?, ?);
        """
        let json = try encode(signal)
        try withStatement(sql) { statement in
            bindText(signal.signalID, at: 1, in: statement)
            bindText(signal.signalKey, at: 2, in: statement)
            sqlite3_bind_double(statement, 3, signal.observedAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 4, signal.expiresAt.timeIntervalSince1970)
            bindText(json, at: 5, in: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw RuntimeStoreError.statementFailed(message: lastErrorMessage())
            }
        }
    }

    public func activeSignals(signalKeys: Set<String>, at date: Date) async throws -> [ContextSignal] {
        guard !signalKeys.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: signalKeys.count).joined(separator: ", ")
        let sql = """
        SELECT json
        FROM signals
        WHERE signal_key IN (\(placeholders)) AND expires_at >= ?
        ORDER BY observed_at DESC;
        """
        let keys = Array(signalKeys)
        var signals: [ContextSignal] = []
        try withStatement(sql) { statement in
            for (index, key) in keys.enumerated() {
                bindText(key, at: Int32(index + 1), in: statement)
            }
            sqlite3_bind_double(statement, Int32(keys.count + 1), date.timeIntervalSince1970)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let raw = sqlite3_column_text(statement, 0) else { continue }
                let json = String(cString: raw)
                signals.append(try decode(ContextSignal.self, from: json))
            }
        }
        return signals
    }

    public func pruneExpiredSignals(before date: Date) async throws {
        let sql = "DELETE FROM signals WHERE expires_at < ?;"
        try withStatement(sql) { statement in
            sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw RuntimeStoreError.statementFailed(message: lastErrorMessage())
            }
        }
    }

    public func loadRuntimeState() async throws -> RuntimeState {
        let sql = "SELECT json FROM runtime_state WHERE key = 'global' LIMIT 1;"
        var state = RuntimeState()
        try withStatement(sql) { statement in
            if sqlite3_step(statement) == SQLITE_ROW, let raw = sqlite3_column_text(statement, 0) {
                state = try decode(RuntimeState.self, from: String(cString: raw))
            }
        }
        return state
    }

    public func saveRuntimeState(_ state: RuntimeState) async throws {
        let sql = """
        INSERT OR REPLACE INTO runtime_state (key, json, updated_at)
        VALUES ('global', ?, ?);
        """
        let json = try encode(state)
        try withStatement(sql) { statement in
            bindText(json, at: 1, in: statement)
            sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw RuntimeStoreError.statementFailed(message: lastErrorMessage())
            }
        }
    }

    public func appendDebugEntry(_ entry: DebugTimelineEntry) async throws {
        let sql = """
        INSERT INTO debug_timeline (id, created_at, category, message, payload)
        VALUES (?, ?, ?, ?, ?);
        """
        try withStatement(sql) { statement in
            bindText(entry.id, at: 1, in: statement)
            sqlite3_bind_double(statement, 2, entry.createdAt.timeIntervalSince1970)
            bindText(entry.category.rawValue, at: 3, in: statement)
            bindText(entry.message, at: 4, in: statement)
            bindText(entry.payload, at: 5, in: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw RuntimeStoreError.statementFailed(message: lastErrorMessage())
            }
        }
    }

    public func appendAuditEntry(_ entry: AuditLogEntry) async throws {
        let sql = """
        INSERT INTO audit_log (id, created_at, event_type, destination, status, payload_summary, payload, retry_count)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        try withStatement(sql) { statement in
            bindText(entry.id, at: 1, in: statement)
            sqlite3_bind_double(statement, 2, entry.createdAt.timeIntervalSince1970)
            bindText(entry.eventType, at: 3, in: statement)
            bindText(entry.destination, at: 4, in: statement)
            bindText(entry.status.rawValue, at: 5, in: statement)
            bindText(entry.payloadSummary, at: 6, in: statement)
            bindText(entry.payload, at: 7, in: statement)
            sqlite3_bind_int(statement, 8, Int32(entry.retryCount))
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw RuntimeStoreError.statementFailed(message: lastErrorMessage())
            }
        }
    }

    public func enqueue(_ item: QueuedWebhook) async throws {
        let sql = """
        INSERT OR REPLACE INTO delivery_queue (id, event_type, status, attempt, queued_at, retry_at, json)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        let json = try encode(item)
        try withStatement(sql) { statement in
            bindText(item.id, at: 1, in: statement)
            bindText(item.eventType, at: 2, in: statement)
            bindText(item.status.rawValue, at: 3, in: statement)
            sqlite3_bind_int(statement, 4, Int32(item.attempt))
            sqlite3_bind_double(statement, 5, item.queuedAt.timeIntervalSince1970)
            if let retryAt = item.retryAt {
                sqlite3_bind_double(statement, 6, retryAt.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(statement, 6)
            }
            bindText(json, at: 7, in: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw RuntimeStoreError.statementFailed(message: lastErrorMessage())
            }
        }
    }

    public func dueQueueItems(at date: Date, limit: Int) async throws -> [QueuedWebhook] {
        let sql = """
        SELECT json
        FROM delivery_queue
        WHERE status IN ('queued', 'retry_wait') AND (retry_at IS NULL OR retry_at <= ?)
        ORDER BY queued_at ASC
        LIMIT ?;
        """
        var items: [QueuedWebhook] = []
        try withStatement(sql) { statement in
            sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
            sqlite3_bind_int(statement, 2, Int32(limit))
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let raw = sqlite3_column_text(statement, 0) else { continue }
                items.append(try decode(QueuedWebhook.self, from: String(cString: raw)))
            }
        }
        return items
    }

    public func updateQueueItem(_ item: QueuedWebhook) async throws {
        try await enqueue(item)
    }

    public func timelineEntries(limit: Int) async throws -> [DebugTimelineEntry] {
        let sql = """
        SELECT id, created_at, category, message, payload
        FROM debug_timeline
        ORDER BY created_at DESC
        LIMIT ?;
        """
        var entries: [DebugTimelineEntry] = []
        try withStatement(sql) { statement in
            sqlite3_bind_int(statement, 1, Int32(limit))
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = stringValue(from: statement, column: 0) ?? UUID().uuidString
                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                let rawCategory = stringValue(from: statement, column: 2) ?? ""
                let category = rawCategory == "event"
                    ? .scenario
                    : TimelineCategory(rawValue: rawCategory) ?? .evaluation
                let message = stringValue(from: statement, column: 3) ?? ""
                let payload = stringValue(from: statement, column: 4)
                entries.append(
                    DebugTimelineEntry(
                        id: id,
                        createdAt: createdAt,
                        category: category,
                        message: message,
                        payload: payload
                    )
                )
            }
        }
        return entries
    }

    public func auditEntries(limit: Int) async throws -> [AuditLogEntry] {
        let sql = """
        SELECT id, created_at, event_type, destination, status, payload_summary, payload, retry_count
        FROM audit_log
        ORDER BY created_at DESC
        LIMIT ?;
        """
        var entries: [AuditLogEntry] = []
        try withStatement(sql) { statement in
            sqlite3_bind_int(statement, 1, Int32(limit))
            while sqlite3_step(statement) == SQLITE_ROW {
                let entry = AuditLogEntry(
                    id: stringValue(from: statement, column: 0) ?? UUID().uuidString,
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                    eventType: stringValue(from: statement, column: 2) ?? "",
                    destination: stringValue(from: statement, column: 3) ?? "",
                    status: AuditStatus(rawValue: stringValue(from: statement, column: 4) ?? "") ?? .queued,
                    payloadSummary: stringValue(from: statement, column: 5) ?? "",
                    payload: stringValue(from: statement, column: 6),
                    retryCount: Int(sqlite3_column_int(statement, 7))
                )
                entries.append(entry)
            }
        }
        return entries
    }

    private static func createTables(in database: OpaquePointer) throws {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS runtime_state (
                key TEXT PRIMARY KEY,
                json TEXT NOT NULL,
                updated_at REAL NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS signals (
                id TEXT PRIMARY KEY,
                signal_key TEXT NOT NULL,
                observed_at REAL NOT NULL,
                expires_at REAL NOT NULL,
                json TEXT NOT NULL
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_signals_key_expires
            ON signals (signal_key, expires_at);
            """,
            """
            CREATE TABLE IF NOT EXISTS delivery_queue (
                id TEXT PRIMARY KEY,
                event_type TEXT NOT NULL,
                status TEXT NOT NULL,
                attempt INTEGER NOT NULL,
                queued_at REAL NOT NULL,
                retry_at REAL,
                json TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS audit_log (
                id TEXT PRIMARY KEY,
                created_at REAL NOT NULL,
                event_type TEXT NOT NULL,
                destination TEXT NOT NULL,
                status TEXT NOT NULL,
                payload_summary TEXT NOT NULL,
                payload TEXT,
                retry_count INTEGER NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS debug_timeline (
                id TEXT PRIMARY KEY,
                created_at REAL NOT NULL,
                category TEXT NOT NULL,
                message TEXT NOT NULL,
                payload TEXT
            );
            """
        ]

        for sql in statements {
            guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
                throw RuntimeStoreError.statementFailed(message: String(cString: sqlite3_errmsg(database)))
            }
        }

        try ensureColumn(named: "payload", type: "TEXT", in: "audit_log", database: database)
    }

    private static func ensureColumn(
        named columnName: String,
        type: String,
        in tableName: String,
        database: OpaquePointer
    ) throws {
        let sql = "PRAGMA table_info(\(tableName));"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw RuntimeStoreError.statementFailed(message: String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let rawName = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: rawName) == columnName {
                return
            }
        }

        let alterStatement = "ALTER TABLE \(tableName) ADD COLUMN \(columnName) \(type);"
        guard sqlite3_exec(database, alterStatement, nil, nil, nil) == SQLITE_OK else {
            throw RuntimeStoreError.statementFailed(message: String(cString: sqlite3_errmsg(database)))
        }
    }

    private func withStatement(_ sql: String, body: (OpaquePointer) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection.handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw RuntimeStoreError.statementFailed(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        try body(statement)
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONCoding.encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw RuntimeStoreError.encodingFailed
        }
        return string
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONCoding.decoder.decode(T.self, from: data)
    }

    private func bindText(_ value: String?, at index: Int32, in statement: OpaquePointer) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        _ = value.withCString { pointer in
            sqlite3_bind_text(statement, index, pointer, -1, sqliteTransient)
        }
    }

    private func stringValue(from statement: OpaquePointer, column: Int32) -> String? {
        guard let raw = sqlite3_column_text(statement, column) else {
            return nil
        }
        return String(cString: raw)
    }

    private func lastErrorMessage() -> String {
        guard let message = sqlite3_errmsg(connection.handle) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }
}

private final class SQLiteConnection: @unchecked Sendable {
    let handle: OpaquePointer

    init(handle: OpaquePointer) {
        self.handle = handle
    }

    deinit {
        sqlite3_close(handle)
    }
}

public enum RuntimeStoreError: Error, Sendable {
    case openFailed(path: String)
    case statementFailed(message: String)
    case encodingFailed
    case decodingFailed
}
