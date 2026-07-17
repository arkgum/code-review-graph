import Foundation

/// Persistent bookmark for incremental sync.
///
/// `lastSyncTime` is the high-water mark: the maximum `updatedAt` seen across all synced
/// lifelogs. The next sync asks the API only for entries changed at or after this instant.
/// `lastCursor` is retained for diagnostics / resuming an interrupted first import.
public struct SyncState: Equatable, Sendable {
    public var lastSyncTime: Date?
    public var lastCursor: String?

    public init(lastSyncTime: Date? = nil, lastCursor: String? = nil) {
        self.lastSyncTime = lastSyncTime
        self.lastCursor = lastCursor
    }

    public static let empty = SyncState()
}
