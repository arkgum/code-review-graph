import Foundation
import GRDB

/// GRDB-backed ``LifelogStore`` (SQLite, WAL mode).
///
/// Schema (see `migrator`):
/// - `lifelog`     — one row per lifelog; `contents` stored as JSON text; `synced` = outbox flag.
/// - `sync_state`  — single row (id = 1) holding the incremental bookmark.
public final class GRDBLifelogStore: LifelogStore {
    private let dbQueue: DatabaseQueue

    /// Opens (and migrates) a store at `path`. Pass `":memory:"` for an ephemeral store.
    public init(path: String) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        self.dbQueue = try DatabaseQueue(path: path, configuration: config)
        try Self.migrator.migrate(dbQueue)
    }

    // MARK: - Migrations

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_create_lifelog") { db in
            try db.create(table: "lifelog") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("markdown", .text)
                t.column("start_time", .datetime)
                t.column("end_time", .datetime)
                t.column("is_starred", .boolean).notNull().defaults(to: false)
                t.column("updated_at", .datetime)
                t.column("contents_json", .text).notNull().defaults(to: "[]")
                t.column("synced", .boolean).notNull().defaults(to: false)
                t.column("fetched_at", .datetime).notNull()
            }
            try db.create(index: "lifelog_on_synced", on: "lifelog", columns: ["synced"])
            try db.create(index: "lifelog_on_updated_at", on: "lifelog", columns: ["updated_at"])

            try db.create(table: "sync_state") { t in
                t.column("id", .integer).primaryKey()
                t.column("last_sync_time", .datetime)
                t.column("last_cursor", .text)
            }
        }
        return migrator
    }

    // MARK: - LifelogStore

    @discardableResult
    public func upsert(_ lifelogs: [Lifelog]) throws -> [String] {
        guard !lifelogs.isEmpty else { return [] }
        return try dbQueue.write { db in
            var written: [String] = []
            let now = Date()
            for log in lifelogs {
                let existing = try Row.fetchOne(
                    db,
                    sql: "SELECT updated_at FROM lifelog WHERE id = ?",
                    arguments: [log.id]
                )
                // Skip if we already have this version or newer.
                if let existing,
                   let existingUpdated: Date = existing["updated_at"],
                   let incoming = log.updatedAt,
                   incoming <= existingUpdated {
                    continue
                }
                let contentsJSON = try Self.encodeContents(log.contents)
                try db.execute(
                    sql: """
                    INSERT INTO lifelog
                      (id, title, markdown, start_time, end_time, is_starred,
                       updated_at, contents_json, synced, fetched_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
                    ON CONFLICT(id) DO UPDATE SET
                      title = excluded.title,
                      markdown = excluded.markdown,
                      start_time = excluded.start_time,
                      end_time = excluded.end_time,
                      is_starred = excluded.is_starred,
                      updated_at = excluded.updated_at,
                      contents_json = excluded.contents_json,
                      synced = 0
                    """,
                    arguments: [
                        log.id, log.title, log.markdown,
                        log.startTime, log.endTime, log.isStarred,
                        log.updatedAt, contentsJSON, now
                    ]
                )
                written.append(log.id)
            }
            return written
        }
    }

    public func allLifelogs() throws -> [Lifelog] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM lifelog ORDER BY COALESCE(start_time, fetched_at) DESC"
            )
            return try rows.map(Self.lifelog(from:))
        }
    }

    public func lifelog(id: String) throws -> Lifelog? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db, sql: "SELECT * FROM lifelog WHERE id = ?", arguments: [id]
            ) else { return nil }
            return try Self.lifelog(from: row)
        }
    }

    public func unsyncedLifelogs(limit: Int) throws -> [Lifelog] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM lifelog WHERE synced = 0 ORDER BY fetched_at ASC LIMIT ?",
                arguments: [limit]
            )
            return try rows.map(Self.lifelog(from:))
        }
    }

    public func markSynced(ids: [String]) throws {
        guard !ids.isEmpty else { return }
        try dbQueue.write { db in
            let placeholders = databaseQuestionMarks(count: ids.count)
            try db.execute(
                sql: "UPDATE lifelog SET synced = 1 WHERE id IN (\(placeholders))",
                arguments: StatementArguments(ids)
            )
        }
    }

    public func loadSyncState() throws -> SyncState {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db, sql: "SELECT last_sync_time, last_cursor FROM sync_state WHERE id = 1"
            ) else { return .empty }
            return SyncState(lastSyncTime: row["last_sync_time"], lastCursor: row["last_cursor"])
        }
    }

    public func saveSyncState(_ state: SyncState) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO sync_state (id, last_sync_time, last_cursor)
                VALUES (1, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  last_sync_time = excluded.last_sync_time,
                  last_cursor = excluded.last_cursor
                """,
                arguments: [state.lastSyncTime, state.lastCursor]
            )
        }
    }

    // MARK: - Row <-> model

    private static func lifelog(from row: Row) throws -> Lifelog {
        Lifelog(
            id: row["id"],
            title: row["title"],
            markdown: row["markdown"],
            startTime: row["start_time"],
            endTime: row["end_time"],
            isStarred: row["is_starred"],
            updatedAt: row["updated_at"],
            contents: try decodeContents(row["contents_json"])
        )
    }

    private static func encodeContents(_ nodes: [ContentNode]) throws -> String {
        let data = try JSONEncoder().encode(nodes)
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeContents(_ json: String?) throws -> [ContentNode] {
        guard let json, let data = json.data(using: .utf8), !data.isEmpty else { return [] }
        return try JSONDecoder().decode([ContentNode].self, from: data)
    }
}
