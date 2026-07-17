import Foundation
@testable import LimitlessKit

/// A thread-safe in-memory ``LifelogStore`` for tests — mirrors the GRDB semantics
/// (upsert-by-newer-updatedAt, `synced` flag, single sync bookmark) without SQLite.
final class InMemoryLifelogStore: LifelogStore, @unchecked Sendable {
    private struct Entry {
        var log: Lifelog
        var synced: Bool
        var fetchedAt: Date
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var state = SyncState.empty
    private var clock = Date(timeIntervalSince1970: 0)

    private func tick() -> Date {
        clock = clock.addingTimeInterval(1)
        return clock
    }

    @discardableResult
    func upsert(_ lifelogs: [Lifelog]) throws -> [String] {
        lock.lock(); defer { lock.unlock() }
        var written: [String] = []
        for log in lifelogs {
            if let existing = entries[log.id],
               let existingUpdated = existing.log.updatedAt,
               let incoming = log.updatedAt,
               incoming <= existingUpdated {
                continue
            }
            entries[log.id] = Entry(log: log, synced: false, fetchedAt: tick())
            written.append(log.id)
        }
        return written
    }

    func allLifelogs() throws -> [Lifelog] {
        lock.lock(); defer { lock.unlock() }
        return entries.values
            .sorted { ($0.log.startTime ?? $0.fetchedAt) > ($1.log.startTime ?? $1.fetchedAt) }
            .map(\.log)
    }

    func lifelog(id: String) throws -> Lifelog? {
        lock.lock(); defer { lock.unlock() }
        return entries[id]?.log
    }

    func unsyncedLifelogs(limit: Int) throws -> [Lifelog] {
        lock.lock(); defer { lock.unlock() }
        return entries.values
            .filter { !$0.synced }
            .sorted { $0.fetchedAt < $1.fetchedAt }
            .prefix(limit)
            .map(\.log)
    }

    func markSynced(ids: [String]) throws {
        lock.lock(); defer { lock.unlock() }
        for id in ids { entries[id]?.synced = true }
    }

    func loadSyncState() throws -> SyncState {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    func saveSyncState(_ newState: SyncState) throws {
        lock.lock(); defer { lock.unlock() }
        state = newState
    }
}
