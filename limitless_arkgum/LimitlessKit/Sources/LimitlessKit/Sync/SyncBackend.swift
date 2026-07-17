import Foundation

/// Destination for the outbox: your own backend (e.g. Spring Boot) that receives lifelogs
/// pulled from Limitless. Kept abstract so the sync engine doesn't hard-depend on a transport,
/// and so "no backend configured" is simply a `nil` backend.
public protocol SyncBackend: Sendable {
    /// Uploads a batch of lifelogs. Must throw on failure so the engine keeps them unsynced
    /// and retries on the next run. Should be idempotent on the server (upsert by `id`).
    func upload(_ lifelogs: [Lifelog]) async throws
}
