import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Home server") {
                    serverURLField
                    usernameField
                    SecureField("Password", text: $state.password)
                }
                Section {
                    Button("Sign in") { Task { await state.signIn() } }
                        .disabled(state.isBusy || state.username.isEmpty || state.password.isEmpty)
                    if state.isSignedIn {
                        Button("Sign out", role: .destructive) { Task { await state.signOut() } }
                    }
                }
                if let name = state.displayName {
                    Section("Session") { Text("Signed in as \(name)") }
                }
                if let message = state.message {
                    Section { Text(message).font(.footnote) }
                }
                Section("Offline store") {
                    Text("\(state.downloadedBundles.count) trip(s) on device")
                }
            }
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    private var serverURLField: some View {
        #if os(iOS)
        TextField("Server URL", text: $state.serverURLString)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        #else
        TextField("Server URL", text: $state.serverURLString)
            .autocorrectionDisabled()
        #endif
    }

    @ViewBuilder
    private var usernameField: some View {
        #if os(iOS)
        TextField("Username", text: $state.username)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        #else
        TextField("Username", text: $state.username)
            .autocorrectionDisabled()
        #endif
    }
}
