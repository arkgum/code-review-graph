import Foundation

/// Supplies the Limitless API key to the client at request time.
///
/// Kept as a protocol so the networking layer never embeds a key and so tests can inject one.
/// The production implementation on iOS reads from the Keychain (stage 5); see
/// `KeychainAPIKeyProvider` in the app layer.
public protocol APIKeyProvider: Sendable {
    /// Returns the current API key, or `nil` if none is configured.
    func currentAPIKey() -> String?
}

/// A simple in-memory provider. Useful for tests and previews — never for storing a real key.
public struct StaticAPIKeyProvider: APIKeyProvider {
    private let key: String?

    public init(_ key: String?) {
        self.key = key
    }

    public func currentAPIKey() -> String? { key }
}
