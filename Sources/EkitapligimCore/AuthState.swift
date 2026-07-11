import Foundation

public enum AuthenticationState: Equatable, Sendable {
    case signedOut
    case authenticating
    case signedIn(Session)
    case expired
    case disabledAccount(message: String)
}

public struct Session: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let username: String

    public init(accessToken: String, refreshToken: String?, username: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.username = username
    }
}

public struct InMemoryTokenProvider: AccessTokenProviding {
    private let token: String?

    public init(token: String?) {
        self.token = token
    }

    public func accessToken() async throws -> String? {
        token
    }
}
