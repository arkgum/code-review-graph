import Foundation
import Security
import LimitlessKit

/// Stores the Limitless API key in the iOS Keychain and vends it to ``LimitlessClient``.
///
/// The key is written with `kSecAttrAccessibleAfterFirstUnlock` so background sync can read it
/// after the first unlock following a reboot. The key never touches UserDefaults, code, or logs.
public final class KeychainAPIKeyProvider: APIKeyProvider {
    private let service: String
    private let account: String

    public init(service: String = "ai.limitless.arkgum", account: String = "limitless-api-key") {
        self.service = service
        self.account = account
    }

    // MARK: - APIKeyProvider

    public func currentAPIKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }
        return key
    }

    // MARK: - Mutation (used by Settings)

    /// Whether a non-empty key is currently stored.
    public var hasKey: Bool { currentAPIKey() != nil }

    /// Stores (or replaces) the key. Passing an empty/whitespace string clears it.
    @discardableResult
    public func setAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return clear() }

        let data = Data(trimmed.utf8)
        // Try update first; if nothing to update, add.
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    /// Removes the stored key.
    @discardableResult
    public func clear() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Private

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
