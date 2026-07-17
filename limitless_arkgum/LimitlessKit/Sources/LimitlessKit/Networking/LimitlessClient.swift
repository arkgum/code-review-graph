import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Async client for the Limitless Developer API (`https://api.limitless.ai/v1`).
///
/// Responsibilities:
/// - Attach the `X-API-KEY` header from an ``APIKeyProvider``.
/// - Build URLs safely via `URLComponents`.
/// - Decode the `LifelogsResponse` envelope with a tolerant ISO-8601 date strategy.
/// - Paginate through `nextCursor`.
/// - Retry on HTTP 429 with backoff, honoring `Retry-After` when present.
public struct LimitlessClient: Sendable {
    /// Query parameters for `GET /v1/lifelogs`.
    public struct LifelogQuery: Sendable {
        public var timezone: String?
        public var date: String?          // YYYY-MM-DD
        public var start: Date?
        public var end: Date?
        public var cursor: String?
        public var direction: Direction?
        public var includeMarkdown: Bool?
        public var includeHeadings: Bool?
        public var limit: Int?
        public var isStarred: Bool?

        public enum Direction: String, Sendable { case asc, desc }

        public init(
            timezone: String? = nil,
            date: String? = nil,
            start: Date? = nil,
            end: Date? = nil,
            cursor: String? = nil,
            direction: Direction? = nil,
            includeMarkdown: Bool? = nil,
            includeHeadings: Bool? = nil,
            limit: Int? = nil,
            isStarred: Bool? = nil
        ) {
            self.timezone = timezone
            self.date = date
            self.start = start
            self.end = end
            self.cursor = cursor
            self.direction = direction
            self.includeMarkdown = includeMarkdown
            self.includeHeadings = includeHeadings
            self.limit = limit
            self.isStarred = isStarred
        }
    }

    private let baseURL: URL
    private let keyProvider: APIKeyProvider
    private let session: URLSession
    private let maxRetries: Int

    public init(
        baseURL: URL = URL(string: "https://api.limitless.ai/v1")!,
        keyProvider: APIKeyProvider,
        session: URLSession = .shared,
        maxRetries: Int = 3
    ) {
        self.baseURL = baseURL
        self.keyProvider = keyProvider
        self.session = session
        self.maxRetries = maxRetries
    }

    // MARK: - Public API

    /// Fetches a single page of lifelogs.
    public func fetchLifelogs(_ query: LifelogQuery = .init()) async throws -> LifelogsResponse {
        let request = try makeRequest(path: "lifelogs", query: query)
        let data = try await performWithRetry(request)
        do {
            return try Self.decoder.decode(LifelogsResponse.self, from: data)
        } catch {
            throw LimitlessAPIError.decoding(String(describing: error))
        }
    }

    /// Fetches every lifelog matching `query`, transparently following `nextCursor`.
    ///
    /// The `cursor` field of the passed query is used as the starting point; callers normally
    /// leave it `nil`. Pages are fetched sequentially to respect the rate limit.
    public func fetchAllLifelogs(_ query: LifelogQuery = .init()) async throws -> [Lifelog] {
        var all: [Lifelog] = []
        var page = query
        while true {
            let response = try await fetchLifelogs(page)
            all.append(contentsOf: response.lifelogs)
            guard let next = response.nextCursor, !next.isEmpty else { break }
            page.cursor = next
        }
        return all
    }

    /// Streams lifelogs page-by-page so callers can persist incrementally instead of buffering
    /// everything in memory. Each yielded array is one API page.
    public func lifelogPages(_ query: LifelogQuery = .init()) -> AsyncThrowingStream<[Lifelog], Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var page = query
                do {
                    while true {
                        let response = try await fetchLifelogs(page)
                        continuation.yield(response.lifelogs)
                        guard let next = response.nextCursor, !next.isEmpty else { break }
                        page.cursor = next
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Request building

    private func makeRequest(path: String, query: LifelogQuery) throws -> URLRequest {
        guard let key = keyProvider.currentAPIKey(), !key.isEmpty else {
            throw LimitlessAPIError.missingAPIKey
        }
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw LimitlessAPIError.invalidURL
        }

        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) {
            if let value { items.append(URLQueryItem(name: name, value: value)) }
        }
        add("timezone", query.timezone)
        add("date", query.date)
        add("start", query.start.map(Self.formatter.string(from:)))
        add("end", query.end.map(Self.formatter.string(from:)))
        add("cursor", query.cursor)
        add("direction", query.direction?.rawValue)
        add("includeMarkdown", query.includeMarkdown.map(String.init))
        add("includeHeadings", query.includeHeadings.map(String.init))
        add("limit", query.limit.map(String.init))
        add("isStarred", query.isStarred.map(String.init))
        if !items.isEmpty { components.queryItems = items }

        guard let url = components.url else { throw LimitlessAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    // MARK: - Transport with retry

    private func performWithRetry(_ request: URLRequest) async throws -> Data {
        var attempt = 0
        while true {
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw LimitlessAPIError.transport(error.localizedDescription)
            }
            guard let http = response as? HTTPURLResponse else {
                throw LimitlessAPIError.transport("Non-HTTP response")
            }

            switch http.statusCode {
            case 200...299:
                return data
            case 401, 403:
                throw LimitlessAPIError.unauthorized
            case 429:
                let retryAfter = Self.retryAfterSeconds(from: http)
                if attempt < maxRetries {
                    attempt += 1
                    let backoff = retryAfter ?? Self.backoffSeconds(for: attempt)
                    try await Self.sleep(seconds: backoff)
                    continue
                }
                throw LimitlessAPIError.rateLimited(retryAfter: retryAfter)
            case 500...599:
                if attempt < maxRetries {
                    attempt += 1
                    try await Self.sleep(seconds: Self.backoffSeconds(for: attempt))
                    continue
                }
                throw LimitlessAPIError.httpStatus(code: http.statusCode, body: Self.bodyString(data))
            default:
                throw LimitlessAPIError.httpStatus(code: http.statusCode, body: Self.bodyString(data))
            }
        }
    }

    // MARK: - Helpers

    private static func retryAfterSeconds(from http: HTTPURLResponse) -> TimeInterval? {
        guard let value = http.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(value.trimmingCharacters(in: .whitespaces))
    }

    /// Exponential backoff: 0.5s, 1s, 2s, … capped at 30s.
    private static func backoffSeconds(for attempt: Int) -> TimeInterval {
        min(30, 0.5 * pow(2, Double(attempt - 1)))
    }

    private static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }

    private static func bodyString(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Coding

    /// Encodes dates in the ISO-8601-with-fractional-seconds form the API accepts on input.
    static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Tolerant decoder: accepts ISO-8601 timestamps both with and without fractional seconds.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = withFraction.date(from: raw) ?? plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(raw)"
            )
        }
        return decoder
    }()
}
