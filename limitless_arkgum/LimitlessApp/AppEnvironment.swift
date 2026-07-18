import Foundation
import LimitlessKit

/// Composition root: builds and owns the store, API client, sync engine, and key provider,
/// and exposes them to the SwiftUI view tree via `@EnvironmentObject`.
@MainActor
final class AppEnvironment: ObservableObject {
    let keyProvider: KeychainAPIKeyProvider
    let backendConfig: BackendConfigStore
    let store: LifelogStore
    let syncManager: SyncManager
    let audioService: AudioService
    let audioStore: AudioStore

    /// Set when the store or environment failed to initialize; surfaced in the UI.
    @Published private(set) var startupError: String?
    /// Mirrors whether an API key is configured, so views can react to Settings changes.
    @Published private(set) var hasAPIKey: Bool

    init() {
        let keyProvider = KeychainAPIKeyProvider()
        self.keyProvider = keyProvider
        self.hasAPIKey = keyProvider.hasKey

        let backendConfig = BackendConfigStore()
        self.backendConfig = backendConfig

        let client = LimitlessClient(keyProvider: keyProvider)
        // Enable the outbox only when a backend URL + token are configured (stage 6).
        let backend: SyncBackend? = backendConfig.current.map {
            HTTPSyncBackend(baseURL: $0.baseURL, token: $0.token)
        }

        // Audio cache (stage 7): downloaded Ogg Opus files live in Caches (evictable by the OS).
        let audioStore = (try? FileAudioStore(directory: Self.audioDirectory()))
            ?? (try! FileAudioStore(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("limitless-audio-\(UUID().uuidString)")))
        self.audioStore = audioStore
        self.audioService = AudioService(client: client, store: audioStore)

        do {
            let store = try GRDBLifelogStore(path: Self.databasePath())
            self.store = store
            self.syncManager = SyncManager(client: client, store: store, backend: backend)
        } catch {
            // Fall back to an ephemeral in-memory DB so the app still launches and shows the error.
            let fallback = try! GRDBLifelogStore(path: ":memory:")
            self.store = fallback
            self.syncManager = SyncManager(client: client, store: fallback, backend: backend)
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

    private static func audioDirectory() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        return base.appendingPathComponent("limitless_arkgum/audio", isDirectory: true)
    }
}
