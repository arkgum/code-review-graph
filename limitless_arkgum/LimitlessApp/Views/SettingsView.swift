import SwiftUI

/// Settings sheet: enter, replace, or clear the Limitless API key (stored in the Keychain).
struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var keyInput = ""
    @State private var savedConfirmation = false

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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Saved", isPresented: $savedConfirmation) {
                Button("OK", role: .cancel) { dismiss() }
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
}
