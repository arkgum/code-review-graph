import Foundation
import LimitlessKit

/// Composition root: builds and owns the store, API client, sync engine, and key provider,
/// and exposes them to the SwiftUI view tree via `@EnvironmentObject`.
@MainActor
final class AppEnvironment: ObservableObject {
    let keyProvider: KeychainAPIKeyProvider
    let store: LifelogStore
    let syncManager: SyncManager

    /// Set when the store or environment failed to initialize; surfaced in the UI.
    @Published private(set) var startupError: String?
    /// Mirrors whether an API key is configured, so views can react to Settings changes.
    @Published private(set) var hasAPIKey: Bool

    init() {
        let keyProvider = KeychainAPIKeyProvider()
        self.keyProvider = keyProvider
        self.hasAPIKey = keyProvider.hasKey

        let client = LimitlessClient(keyProvider: keyProvider)

        do {
            let store = try GRDBLifelogStore(path: Self.databasePath())
            self.store = store
            // No backend wired yet (stage 6). Sync pulls into the local store only.
            self.syncManager = SyncManager(client: client, store: store, backend: nil)
        } catch {
            // Fall back to an ephemeral in-memory DB so the app still launches and shows the error.
            let fallback = try! GRDBLifelogStore(path: ":memory:")
            self.store = fallback
            self.syncManager = SyncManager(client: client, store: fallback, backend: nil)
            self.startupError = "Failed to open local database: \(error.localizedDescription)"
        }
    }

    /// Re-reads whether a key exists (call after Settings saves/clears it).
    func refreshKeyState() {
        hasAPIKey = keyProvider.hasKey
    }

    // MARK: - Paths

    private static func databasePath() -> String {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("limitless_arkgum", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("lifelogs.sqlite").path
    }
}
