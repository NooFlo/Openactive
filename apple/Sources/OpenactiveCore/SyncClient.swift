import Foundation

public enum OpenactiveError: LocalizedError {
    case badServerURL
    case unauthorized
    case http(status: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .badServerURL: return "Invalid home server URL"
        case .unauthorized: return "Sign in required (Session may have expired)"
        case .http(let status, let message): return "Server error \(status): \(message)"
        }
    }
}

public final class SyncClient: @unchecked Sendable {
    public static let sessionCookieName = "oa_session"

    public let baseURL: URL
    private let session: URLSession

    public init(serverURL: URL) {
        self.baseURL = serverURL
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    public convenience init?(serverURLString: String) {
        var s = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") { s = "http://" + s }
        guard let url = URL(string: s), url.host != nil else { return nil }
        self.init(serverURL: url)
    }

    public func login(username: String, password: String) async throws -> String {
        struct User: Decodable { let username: String; let displayName: String }
        struct LoginResponse: Decodable { let user: User }
        let body = try JSONSerialization.data(withJSONObject: ["username": username, "password": password])
        let data = try await request(path: "/api/auth/login", method: "POST", body: body)
        return try JSONDecoder().decode(LoginResponse.self, from: data).user.displayName
    }

    public func preparedTrips() async throws -> [PreparedTrip] {
        let data = try await request(path: "/api/sync/prepared")
        return try JSONDecoder().decode(PreparedTripsResponse.self, from: data).trips
    }

    public func bundle(slug: String) async throws -> OfflineBundle {
        let data = try await request(path: "/api/tours/\(slug)/bundle")
        return try JSONDecoder().decode(BundleResponse.self, from: data).bundle
    }

    public func tile(_ ref: TileRef) async throws -> Data {
        try await request(path: "/api/tiles/\(ref.z)/\(ref.x)/\(ref.y).pbf")
    }

    public func savedSessionToken() -> String? {
        let cookies = HTTPCookieStorage.shared.cookies(for: baseURL) ?? []
        return cookies.first(where: { $0.name == Self.sessionCookieName })?.value
    }

    public func restoreSessionToken(_ token: String) {
        guard let cookie = HTTPCookie(properties: [
            .domain: baseURL.host ?? "",
            .name: Self.sessionCookieName,
            .value: token,
            .path: "/",
            .expires: Date.distantFutureInCookieTerms,
        ]) else { return }
        HTTPCookieStorage.shared.setCookie(cookie)
    }

    public func signOut() async {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/login"))
        request.httpMethod = "DELETE"
        _ = try? await session.data(for: request)
        for cookie in HTTPCookieStorage.shared.cookies(for: baseURL) ?? [] {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    private func request(path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw OpenactiveError.badServerURL
        }
        let base = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = base + path
        guard let url = components.url else { throw OpenactiveError.badServerURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenactiveError.badServerURL }
        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw OpenactiveError.unauthorized
        default:
            let message = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["error"] as? String
                ?? String(decoding: data.prefix(200), as: UTF8.self)
            throw OpenactiveError.http(status: http.statusCode, message: message)
        }
    }
}

private extension Date {
    static var distantFutureInCookieTerms: Date {
        Date(timeIntervalSinceNow: 30 * 24 * 3600)
    }
}
