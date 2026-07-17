import Foundation
import LimitlessKit

/// Backs ``LifelogListView``: loads cached lifelogs from the store and triggers sync.
@MainActor
final class LifelogListViewModel: ObservableObject {
    @Published private(set) var lifelogs: [Lifelog] = []
    @Published private(set) var isSyncing = false
    @Published var errorMessage: String?

    private let store: LifelogStore
    private let syncManager: SyncManager

    init(store: LifelogStore, syncManager: SyncManager) {
        self.store = store
        self.syncManager = syncManager
    }

    /// Reloads the list from the local store (fast, offline).
    func reload() {
        do {
            lifelogs = try store.allLifelogs()
        } catch {
            errorMessage = "Couldn't read local data: \(error.localizedDescription)"
        }
    }

    /// Pulls the delta from Limitless, then reloads. Safe to call on appear and on pull-to-refresh.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            _ = try await syncManager.sync()
            reload()
        } catch let error as LimitlessAPIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
