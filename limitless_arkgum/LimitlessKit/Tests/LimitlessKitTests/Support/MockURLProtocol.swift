import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Intercepts URLSession requests in tests and returns canned responses.
///
/// Set ``handler`` to map an incoming request to a status code + body. Install via a
/// `URLSessionConfiguration.ephemeral` whose `protocolClasses` includes this type.
final class MockURLProtocol: URLProtocol {
    /// Returns (statusCode, body, headers) for a given request. Set before each test.
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data, [String: String]))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, body, headers) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
