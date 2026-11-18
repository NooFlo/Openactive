import Foundation
import SwiftUI
import OpenactiveCore

@MainActor
final class AppState: ObservableObject {
    @Published var serverURLString: String
    @Published var username: String
    @Published var password: String = ""
    @Published var displayName: String?
    @Published var trips: [PreparedTrip] = []
    @Published var downloadedBundles: [OfflineBundle] = []
    @Published var downloadProgress: (slug: String, done: Int, total: Int)?
    @Published var message: String?
    @Published var isBusy = false

    private(set) var client: SyncClient?
    private let store: OfflineStore

    private static let serverKey = "server-url"
    private static let userKey = "username"
    private static let displayKey = "display-name"
    private static let sessionKey = "session-token"

    init(store: OfflineStore = OfflineStore.makeDefault()) {
        self.store = store
        self.serverURLString = KeychainStore.get(Self.serverKey) ?? "http://192.168.178.32:3456"
        self.username = KeychainStore.get(Self.userKey) ?? ""
        self.displayName = KeychainStore.get(Self.displayKey)
        restoreSession()
    }

    var isSignedIn: Bool { displayName != nil }

    func signIn() async {
        guard let client = SyncClient(serverURLString: serverURLString) else {
            message = "Enter a valid home server URL (e.g. http://192.168.178.32:3456)"
            return
        }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let name = try await client.login(username: username, password: password)
            self.client = client
            displayName = name
            password = ""
            KeychainStore.set(serverURLString, for: Self.serverKey)
            KeychainStore.set(username, for: Self.userKey)
            KeychainStore.set(name, for: Self.displayKey)
            if let token = client.savedSessionToken() {
                KeychainStore.set(token, for: Self.sessionKey)
            }
            await refreshTrips()
            message = "Signed in as \(name)"
        } catch {
            message = "Sign in failed: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        await client?.signOut()
        KeychainStore.remove(Self.sessionKey)
        client = nil
        displayName = nil
        trips = []
        message = "Signed out"
    }

    func refreshTrips() async {
        guard let client else { return }
        do {
            trips = try await client.preparedTrips()
            downloadedBundles = store.loadBundles()
        } catch {
            message = "Could not load prepared trips: \(error.localizedDescription)"
            if case OpenactiveError.unauthorized = error { displayName = nil }
        }
    }

    func download(trip: PreparedTrip) async {
        guard let client else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let bundle = try await client.bundle(slug: trip.slug)
            downloadProgress = (trip.slug, 0, max(bundle.tileCount, 1))
            try store.save(bundle: bundle)
            _ = try await store.downloadTiles(of: bundle, client: client) { done, total in
                Task { @MainActor in
                    self.downloadProgress = (trip.slug, done, total)
                }
            }
            downloadProgress = nil
            downloadedBundles = store.loadBundles()
            message = "\(bundle.title): route + \(bundle.tileCount) tiles (~\(bundle.estSizeMb) MB) on device"
        } catch {
            downloadProgress = nil
            message = "Download failed: \(error.localizedDescription)"
        }
    }

    func isDownloaded(_ trip: PreparedTrip) -> Bool {
        store.isDownloaded(slug: trip.slug)
    }

    private func restoreSession() {
        guard let token = KeychainStore.get(Self.sessionKey),
              let client = SyncClient(serverURLString: serverURLString)
        else { return }
        client.restoreSessionToken(token)
        self.client = client
        downloadedBundles = store.loadBundles()
        Task { await refreshTrips() }
    }
}
