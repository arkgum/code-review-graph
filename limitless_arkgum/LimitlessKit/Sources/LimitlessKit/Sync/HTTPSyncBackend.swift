import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// ``SyncBackend`` that POSTs lifelogs to your own HTTP service (e.g. the Spring Boot receiver).
///
/// Sends the batch as a JSON array to `<baseURL>/api/lifelogs` with a shared secret in the
/// `X-Sync-Token` header. Throws on any non-2xx response so the engine keeps the batch unsynced
/// and retries next run; the server upserts by `id`, so retries are safe.
public struct HTTPSyncBackend: SyncBackend {
    private let endpoint: URL
    private let token: String
    private let session: URLSession

    /// - Parameters:
    ///   - baseURL: root of your backend, e.g. `https://my-host`. `/api/lifelogs` is appended.
    ///   - token: shared secret sent as `X-Sync-Token`.
    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.endpoint = baseURL.appendingPathComponent("api/lifelogs")
        self.token = token
        self.session = session
    }

    public func upload(_ lifelogs: [Lifelog]) async throws {
        guard !lifelogs.isEmpty else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Sync-Token")
        do {
            request.httpBody = try Self.encoder.encode(lifelogs)
        } catch {
            throw LimitlessAPIError.decoding("Failed to encode lifelogs: \(error)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LimitlessAPIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw LimitlessAPIError.transport("Non-HTTP response from backend")
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw LimitlessAPIError.unauthorized
        default:
            let body = data.isEmpty ? nil : String(data: data, encoding: .utf8)
            throw LimitlessAPIError.httpStatus(code: http.statusCode, body: body)
        }
    }

    /// Encodes dates as ISO-8601 with fractional seconds, which the backend parses into Instants.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var container = enc.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()
}
