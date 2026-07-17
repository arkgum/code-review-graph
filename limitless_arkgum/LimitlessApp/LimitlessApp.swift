import SwiftUI

@main
struct LimitlessApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
        }
    }
}

/// Wires the list view model to the shared environment.
private struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        LifelogListView(
            model: LifelogListViewModel(store: env.store, syncManager: env.syncManager)
        )
        .overlay(alignment: .bottom) {
            if let error = env.startupError {
                Text(error)
                    .font(.caption)
                    .padding(8)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
    }
}
