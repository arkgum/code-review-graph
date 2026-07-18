import SwiftUI
import LimitlessKit

/// Root screen: the list of lifelogs, with pull-to-refresh and sync-on-appear.
struct LifelogListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: LifelogListViewModel
    @State private var showingSettings = false

    init(model: LifelogListViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !env.hasAPIKey {
                    needsKeyState
                } else if model.lifelogs.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Lifelogs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings, onDismiss: {
                env.refreshKeyState()
                Task { await model.sync() }
            }) {
                SettingsView()
            }
        }
        .task {
            model.reload()
            if env.hasAPIKey { await model.sync() }
        }
        .onChange(of: scenePhase) { phase in
            // Re-sync (and refresh the list) when returning to the foreground.
            if phase == .active, env.hasAPIKey {
                Task { await model.sync() }
            }
        }
        .alert("Sync error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var list: some View {
        List(model.lifelogs) { log in
            NavigationLink(value: log) {
                LifelogRow(log: log)
            }
        }
        .listStyle(.plain)
        .refreshable { await model.sync() }
        .navigationDestination(for: Lifelog.self) { log in
            LifelogDetailView(log: log, service: env.audioService)
        }
        .overlay(alignment: .top) {
            if model.isSyncing {
                ProgressView().padding(8)
            }
        }
    }

    private var emptyState: some View {
        // A List (not a bare VStack) so pull-to-refresh is available while empty.
        List {
            VStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No lifelogs yet")
                    .font(.headline)
                Text("Pull to refresh to sync from Limitless.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .refreshable { await model.sync() }
    }

    private var needsKeyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.horizontal")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Add your Limitless API key")
                .font(.headline)
            Text("Settings → paste the key from your Limitless developer settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") { showingSettings = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// One row in the list.
private struct LifelogRow: View {
    let log: Lifelog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.title.isEmpty ? "Untitled" : log.title)
                    .font(.headline)
                    .lineLimit(1)
                if log.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
            HStack(spacing: 8) {
                Text(Formatting.dayTime(log.startTime))
                if let dur = Formatting.duration(from: log.startTime, to: log.endTime) {
                    Text("· \(dur)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
