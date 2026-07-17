import Foundation

/// Stores optional backend (Spring Boot) sync settings: the base URL in UserDefaults and the
/// shared sync token in the Keychain. Outbox is enabled only when both are present and the URL
/// is valid.
final class BackendConfigStore {
    struct Config: Equatable {
        var baseURL: URL
        var token: String
    }

    private let defaults: UserDefaults
    private let tokenStore: KeychainAPIKeyProvider
    private static let urlKey = "backend.baseURL"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Reuse the Keychain wrapper with a distinct account for the sync token.
        self.tokenStore = KeychainAPIKeyProvider(account: "backend-sync-token")
    }

    /// Current config, or `nil` if not fully configured.
    var current: Config? {
        guard let urlString = defaults.string(forKey: Self.urlKey),
              let url = URL(string: urlString),
              url.scheme != nil,
              let token = tokenStore.currentAPIKey()
        else { return nil }
        return Config(baseURL: url, token: token)
    }

    var urlString: String {
        defaults.string(forKey: Self.urlKey) ?? ""
    }

    var hasToken: Bool { tokenStore.hasKey }

    /// Saves URL + token. Empty URL or token clears that piece.
    func save(urlString: String, token: String) {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedURL.isEmpty {
            defaults.removeObject(forKey: Self.urlKey)
        } else {
            defaults.set(trimmedURL, forKey: Self.urlKey)
        }
        // setAPIKey clears when passed empty/whitespace.
        tokenStore.setAPIKey(token)
    }

    func clear() {
        defaults.removeObject(forKey: Self.urlKey)
        tokenStore.clear()
    }
}
