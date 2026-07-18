import SwiftUI

/// Settings sheet: enter, replace, or clear the Limitless API key (stored in the Keychain).
struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var keyInput = ""
    @State private var backendURL = ""
    @State private var backendToken = ""
    @State private var savedConfirmation = false
    @State private var audioRefresh = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Paste API key", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Limitless API Key")
                } footer: {
                    Text("Create a key in your Limitless developer settings. It is stored only in this device's Keychain.")
                }

                Section {
                    Button("Save") { save() }
                        .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    if env.hasAPIKey {
                        Button("Remove stored key", role: .destructive) { clear() }
                    }
                } footer: {
                    if env.hasAPIKey {
                        Label("A key is currently stored.", systemImage: "checkmark.seal")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    TextField("https://your-backend", text: $backendURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Sync token", text: $backendToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save backend") { saveBackend() }
                    if env.backendConfig.current != nil {
                        Button("Disable backend sync", role: .destructive) { clearBackend() }
                    }
                } header: {
                    Text("Backend (optional)")
                } footer: {
                    Text("Where synced lifelogs are pushed (your Spring Boot server). Leave empty to keep data on-device only. Changes take effect after restarting the app.")
                }

                Section {
                    HStack {
                        Text("Downloaded audio")
                        Spacer()
                        Text(audioUsage).foregroundStyle(.secondary)
                    }
                    Button("Clear audio cache", role: .destructive) { clearAudio() }
                        .disabled(env.audioStore.totalBytes() == 0)
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Audio is stored as Ogg Opus. iOS can't play Ogg natively yet — export files to play them elsewhere.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Saved", isPresented: $savedConfirmation) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                backendURL = env.backendConfig.urlString
            }
        }
    }

    private func save() {
        if env.keyProvider.setAPIKey(keyInput) {
            keyInput = ""
            env.refreshKeyState()
            savedConfirmation = true
        }
    }

    private func clear() {
        env.keyProvider.clear()
        env.refreshKeyState()
    }

    private func saveBackend() {
        env.backendConfig.save(urlString: backendURL, token: backendToken)
        backendToken = ""
        savedConfirmation = true
    }

    private func clearBackend() {
        env.backendConfig.clear()
        backendURL = ""
        backendToken = ""
    }

    private var audioUsage: String {
        _ = audioRefresh // re-evaluate after clearing
        let bytes = env.audioStore.totalBytes()
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func clearAudio() {
        try? env.audioStore.deleteAll()
        audioRefresh += 1
    }
}
