import XCTest
@testable import LimitlessKit

final class AudioTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - FileAudioStore

    func testStoreAndRetrieveAndDelete() throws {
        let store = try FileAudioStore(directory: tempDir)
        XCTAssertFalse(store.hasAudio(for: "log-1"))

        let bytes = Data([0x4F, 0x67, 0x67, 0x53]) // "OggS"
        try store.store(bytes, for: "log-1")
        XCTAssertTrue(store.hasAudio(for: "log-1"))
        XCTAssertEqual(store.totalBytes(), 4)

        try store.delete(for: "log-1")
        XCTAssertFalse(store.hasAudio(for: "log-1"))
    }

    func testSanitizeRejectsPathTraversal() {
        let sanitized = FileAudioStore.sanitize("../../etc/passwd")
        XCTAssertFalse(sanitized.contains("/"))
        XCTAssertFalse(sanitized.contains(".."))
    }

    // MARK: - AudioService

    private func makeClient() -> LimitlessClient {
        LimitlessClient(
            baseURL: URL(string: "https://api.limitless.ai/v1")!,
            keyProvider: StaticAPIKeyProvider("k"),
            session: MockURLProtocol.session()
        )
    }

    func testDownloadsThenCaches() async throws {
        var hits = 0
        MockURLProtocol.handler = { request in
            hits += 1
            XCTAssertTrue(request.url!.path.hasSuffix("/download-audio"))
            return (200, Data([0x4F, 0x67, 0x67, 0x53]), ["Content-Type": "audio/ogg"])
        }
        let store = try FileAudioStore(directory: tempDir)
        let service = AudioService(client: makeClient(), store: store)
        let log = Lifelog(
            id: "log-1", title: "t",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60)
        )

        let url1 = try await service.audioURL(for: log)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url1.path))
        // Second call is served from cache — no extra network hit.
        let url2 = try await service.audioURL(for: log)
        XCTAssertEqual(url1, url2)
        XCTAssertEqual(hits, 1)
    }

    func testRejectsRangeOverTwoHours() async throws {
        let store = try FileAudioStore(directory: tempDir)
        let service = AudioService(client: makeClient(), store: store)
        let log = Lifelog(
            id: "long", title: "t",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3 * 60 * 60) // 3h
        )
        do {
            _ = try await service.audioURL(for: log)
            XCTFail("expected rejection")
        } catch {
            guard case LimitlessAPIError.invalidParameter = error else {
                return XCTFail("wrong error: \(error)")
            }
        }
    }
}
