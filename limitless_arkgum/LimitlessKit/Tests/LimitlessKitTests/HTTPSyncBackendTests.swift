import XCTest
@testable import LimitlessKit

final class HTTPSyncBackendTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func backend() -> HTTPSyncBackend {
        HTTPSyncBackend(
            baseURL: URL(string: "https://backend.example")!,
            token: "secret",
            session: MockURLProtocol.session()
        )
    }

    func testPostsToApiLifelogsWithTokenAndArrayBody() async throws {
        var capturedURL: URL?
        var capturedToken: String?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedURL = request.url
            capturedToken = request.value(forHTTPHeaderField: "X-Sync-Token")
            // URLProtocol strips httpBody into stream; read from bodyStream if needed.
            capturedBody = request.httpBody ?? request.httpBodyStreamData()
            return (200, Data(#"{"received":1}"#.utf8), [:])
        }

        try await backend().upload([Lifelog(id: "a", title: "t", isStarred: true)])

        XCTAssertEqual(capturedURL?.absoluteString, "https://backend.example/api/lifelogs")
        XCTAssertEqual(capturedToken, "secret")
        let body = try XCTUnwrap(capturedBody)
        let json = String(data: body, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"id\":\"a\""), "body was: \(json)")
    }

    func testUnauthorizedMapsToError() async {
        MockURLProtocol.handler = { _ in (401, Data(), [:]) }
        do {
            try await backend().upload([Lifelog(id: "a", title: "t")])
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? LimitlessAPIError, .unauthorized)
        }
    }

    func testEmptyBatchIsNoOp() async throws {
        MockURLProtocol.handler = { _ in
            XCTFail("should not hit network for empty batch")
            return (200, Data(), [:])
        }
        try await backend().upload([])
    }
}

private extension URLRequest {
    /// Reads a body delivered as a stream (URLProtocol converts httpBody to httpBodyStream).
    func httpBodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }
}
