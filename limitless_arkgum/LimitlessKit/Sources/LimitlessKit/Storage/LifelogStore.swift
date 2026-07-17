import Foundation

/// Local persistence contract for lifelogs and sync bookkeeping.
///
/// `SyncManager` depends only on this protocol, so the sync logic can be tested against an
/// in-memory fake and the production GRDB implementation is swappable. All methods are
/// synchronous and expected to be called off the main thread by the caller.
public protocol LifelogStore: Sendable {
    /// Inserts or updates the given lifelogs, keyed by `id`.
    ///
    /// A record is written only when it is new or its `updatedAt` is newer than the stored one.
    /// Any record actually written is flagged `synced = false` so the outbox will push it to the
    /// backend. Returns the ids that were inserted or updated.
    @discardableResult
    func upsert(_ lifelogs: [Lifelog]) throws -> [String]

    /// All lifelogs, newest first, for display.
    func allLifelogs() throws -> [Lifelog]

    /// A single lifelog by id, or `nil`.
    func lifelog(id: String) throws -> Lifelog?

    /// Lifelogs not yet pushed to the backend (`synced = false`), oldest first, capped at `limit`.
    func unsyncedLifelogs(limit: Int) throws -> [Lifelog]

    /// Marks the given ids as pushed to the backend.
    func markSynced(ids: [String]) throws

    /// Loads the sync bookmark, or ``SyncState/empty`` if none was saved.
    func loadSyncState() throws -> SyncState

    /// Persists the sync bookmark.
    func saveSyncState(_ state: SyncState) throws
}
