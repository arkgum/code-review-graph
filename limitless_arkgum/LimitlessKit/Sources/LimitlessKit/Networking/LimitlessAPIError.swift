import Foundation

/// Errors surfaced by ``LimitlessClient``.
public enum LimitlessAPIError: Error, Equatable, Sendable {
    /// No API key was available from the ``APIKeyProvider``.
    case missingAPIKey
    /// The server rejected the key (HTTP 401/403).
    case unauthorized
    /// Rate limit exceeded (HTTP 429) after exhausting retries.
    case rateLimited(retryAfter: TimeInterval?)
    /// A non-success HTTP status other than the ones above.
    case httpStatus(code: Int, body: String?)
    /// The response body could not be decoded into the expected shape.
    case decoding(String)
    /// The URL could not be constructed from the provided components.
    case invalidURL
    /// A caller-supplied parameter was invalid (e.g. an audio range exceeding the API limit).
    case invalidParameter(String)
    /// A transport-level failure (offline, timeout, TLS, …). Message only, to stay `Equatable`.
    case transport(String)
}

extension LimitlessAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Limitless API key configured."
        case .unauthorized:
            return "The Limitless API key was rejected."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limited by Limitless. Retry after \(Int(retryAfter))s."
            }
            return "Rate limited by Limitless."
        case .httpStatus(let code, _):
            return "Limitless API returned HTTP \(code)."
        case .decoding(let detail):
            return "Failed to decode Limitless response: \(detail)"
        case .invalidURL:
            return "Failed to build a valid Limitless API URL."
        case .invalidParameter(let detail):
            return "Invalid request parameter: \(detail)"
        case .transport(let detail):
            return "Network error talking to Limitless: \(detail)"
        }
    }
}
