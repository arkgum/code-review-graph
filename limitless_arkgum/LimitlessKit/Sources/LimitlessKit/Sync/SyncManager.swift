import Foundation

/// Drives incremental synchronization: pull the delta from Limitless into the local store,
/// then push anything not yet on the backend (outbox).
///
/// Call ``sync()`` when the app becomes active. The operation is idempotent and resumable:
/// the high-water mark (`lastSyncTime`) and the `synced` flag are persisted, so an interrupted
/// run simply resumes on the next call without duplicating or losing data.
public actor SyncManager {
    private let client: LimitlessClient
    private let store: LifelogStore
    private let backend: SyncBackend?
    private let pageLimit: Int
    private let uploadBatchSize: Int
    /// Small overlap subtracted from `lastSyncTime` so entries updated in the same second as the
    /// previous run aren't missed. Upsert dedupes any resulting re-fetch by `updatedAt`.
    private let overlap: TimeInterval

    private var isRunning = false

    public struct Report: Equatable, Sendable {
        public var fetched: Int
        public var upserted: Int
        public var uploaded: Int
        public init(fetched: Int = 0, upserted: Int = 0, uploaded: Int = 0) {
            self.fetched = fetched
            self.upserted = upserted
            self.uploaded = uploaded
        }
    }

    public init(
        client: LimitlessClient,
        store: LifelogStore,
        backend: SyncBackend? = nil,
        pageLimit: Int = 25,
        uploadBatchSize: Int = 25,
        overlap: TimeInterval = 1
    ) {
        self.client = client
        self.store = store
        self.backend = backend
        self.pageLimit = pageLimit
        self.uploadBatchSize = uploadBatchSize
        self.overlap = overlap
    }

    /// Runs one full sync cycle: pull delta, then flush the outbox. Concurrent calls are
    /// coalesced — a second call while one is in flight returns an empty report immediately.
    @discardableResult
    public func sync() async throws -> Report {
        guard !isRunning else { return Report() }
        isRunning = true
        defer { isRunning = false }

        var report = Report()
        try await pullDelta(into: &report)
        try await flushOutbox(into: &report)
        return report
    }

    // MARK: - Pull

    private func pullDelta(into report: inout Report) async throws {
        let state = try store.loadSyncState()
        let start = state.lastSyncTime.map { $0.addingTimeInterval(-overlap) }

        let query = LimitlessClient.LifelogQuery(
            start: start,
            direction: .asc,           // ascending so the last page carries the newest updatedAt
            includeMarkdown: true,
            includeHeadings: true,
            limit: pageLimit
        )

        var maxUpdatedAt = state.lastSyncTime
        // Fetch page by page and persist as we go, so an interruption still advances the store.
        for try await page in client.lifelogPages(query) {
            guard !page.isEmpty else { continue }
            report.fetched += page.count
            let written = try store.upsert(page)
            report.upserted += written.count
            for log in page {
                if let updated = log.updatedAt {
                    if maxUpdatedAt == nil || updated > maxUpdatedAt! { maxUpdatedAt = updated }
                }
            }
        }

        if maxUpdatedAt != state.lastSyncTime {
            try store.saveSyncState(SyncState(lastSyncTime: maxUpdatedAt, lastCursor: nil))
        }
    }

    // MARK: - Push (outbox)

    private func flushOutbox(into report: inout Report) async throws {
        guard let backend else { return }
        while true {
            let batch = try store.unsyncedLifelogs(limit: uploadBatchSize)
            guard !batch.isEmpty else { break }
            try await backend.upload(batch)
            try store.markSynced(ids: batch.map(\.id))
            report.uploaded += batch.count
            if batch.count < uploadBatchSize { break }
        }
    }
}
