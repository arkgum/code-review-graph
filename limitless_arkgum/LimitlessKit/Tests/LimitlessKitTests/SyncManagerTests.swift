import XCTest
@testable import LimitlessKit

final class SyncManagerTests: XCTestCase {
    private let baseURL = URL(string: "https://api.limitless.ai/v1")!

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    /// Builds a lifelogs JSON page envelope.
    private func page(_ logs: [(id: String, updated: String)], nextCursor: String?) -> Data {
        let items = logs.map { log in
            """
            {"id":"\(log.id)","title":"t-\(log.id)","markdown":"m",
             "startTime":"2026-07-17T09:00:00.000Z","updatedAt":"\(log.updated)","contents":[]}
            """
        }.joined(separator: ",")
        let cursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"data":{"lifelogs":[\(items)]},"meta":{"lifelogs":{"nextCursor":\(cursor),"count":\(logs.count)}}}
        """
        return Data(json.utf8)
    }

    private func makeClient() -> LimitlessClient {
        LimitlessClient(
            baseURL: baseURL,
            keyProvider: StaticAPIKeyProvider("test-key"),
            session: MockURLProtocol.session()
        )
    }

    /// Actor collecting uploads pushed to the fake backend.
    private actor RecordingBackend: SyncBackend {
        private(set) var uploaded: [String] = []
        func upload(_ lifelogs: [Lifelog]) async throws {
            uploaded.append(contentsOf: lifelogs.map(\.id))
        }
    }

    func testFullSyncPaginatesUpsertsAndUploads() async throws {
        // Two pages, then end.
        MockURLProtocol.handler = { [self] request in
            let cursor = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "cursor" })?.value
            // Assert the API key header is attached.
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-KEY"), "test-key")
            switch cursor {
            case nil:
                return (200, page([("a", "2026-07-17T09:00:00.000Z"),
                                   ("b", "2026-07-17T09:05:00.000Z")], nextCursor: "c2"), [:])
            case "c2":
                return (200, page([("c", "2026-07-17T09:10:00.000Z")], nextCursor: nil), [:])
            default:
                return (500, Data("unexpected".utf8), [:])
            }
        }

        let store = InMemoryLifelogStore()
        let backend = RecordingBackend()
        let manager = SyncManager(client: makeClient(), store: store, backend: backend)

        let report = try await manager.sync()

        XCTAssertEqual(report.fetched, 3)
        XCTAssertEqual(report.upserted, 3)
        XCTAssertEqual(report.uploaded, 3)
        XCTAssertEqual(try store.allLifelogs().count, 3)
        let uploaded = await backend.uploaded
        XCTAssertEqual(Set(uploaded), ["a", "b", "c"])

        // High-water mark advanced to the newest updatedAt.
        let state = try store.loadSyncState()
        XCTAssertNotNil(state.lastSyncTime)
    }

    func testSecondSyncSendsStartAndOnlyPullsDelta() async throws {
        let store = InMemoryLifelogStore()
        // Seed a prior bookmark.
        try store.saveSyncState(SyncState(
            lastSyncTime: LimitlessClient.formatter.date(from: "2026-07-17T09:05:00.000Z")
        ))

        var sawStart: String??
        MockURLProtocol.handler = { [self] request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            sawStart = items?.first(where: { $0.name == "start" })?.value
            return (200, page([("d", "2026-07-17T09:20:00.000Z")], nextCursor: nil), [:])
        }

        let manager = SyncManager(client: makeClient(), store: store)
        let report = try await manager.sync()

        XCTAssertEqual(report.upserted, 1)
        // A `start` query param must have been sent (delta, not full pull).
        let start = try XCTUnwrap(sawStart)
        XCTAssertNotNil(start)
    }

    func testUpsertIsIdempotentOnRepeatedData() async throws {
        MockURLProtocol.handler = { [self] _ in
            (200, page([("x", "2026-07-17T09:00:00.000Z")], nextCursor: nil), [:])
        }
        let store = InMemoryLifelogStore()
        let manager = SyncManager(client: makeClient(), store: store)

        _ = try await manager.sync()
        let secondReport = try await manager.sync()

        // Same version re-fetched via overlap window must not re-write.
        XCTAssertEqual(secondReport.upserted, 0)
        XCTAssertEqual(try store.allLifelogs().count, 1)
    }
}
