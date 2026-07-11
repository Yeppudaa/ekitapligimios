import Foundation

public protocol AccessTokenProviding: Sendable {
    func accessToken() async throws -> String?
}

public protocol SessionTokenManaging: AccessTokenProviding {
    func loadSession() async throws -> Session?
    func save(session: Session) async throws
    func clear() async throws
}

public final class APIClient: Sendable {
    private let config: AppConfig
    private let session: URLSession
    private let tokenProvider: AccessTokenProviding?
    private let decoder: JSONDecoder
    private let refreshCoordinator = TokenRefreshCoordinator()

    public init(config: AppConfig, session: URLSession = .shared, tokenProvider: AccessTokenProviding? = nil) {
        self.config = config
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = JSONDecoder.ekitapligim
    }

    public func request<T: Decodable>(_ endpoint: APIEndpoint, as type: T.Type = T.self) async throws -> T {
        try await request(endpoint, as: type, allowsTokenRefresh: true)
    }

    private func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        as type: T.Type,
        allowsTokenRefresh: Bool
    ) async throws -> T {
        let request = try await authenticatedRequest(endpoint)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
        if http.statusCode == 401,
           endpoint.requiresAuthentication,
           allowsTokenRefresh,
           let tokenManager = tokenProvider as? any SessionTokenManaging {
            do {
                _ = try await refreshCoordinator.refresh { [self] in
                    try await refreshSession(using: tokenManager)
                }
                return try await self.request(endpoint, as: type, allowsTokenRefresh: false)
            } catch {
                try? await tokenManager.clear()
                throw APIClientError.authenticationRequired
            }
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIClientError.httpStatus(http.statusCode, try? decoder.decode(APIErrorEnvelope.self, from: data))
        }
        if data.isEmpty {
            if let empty = EmptyResponse() as? T {
                return empty
            }
            if let emptyType = T.self as? EmptyDataDecodable.Type,
               let emptyValue = emptyType.emptyValue as? T {
                return emptyValue
            }
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingFailed(error.localizedDescription)
        }
    }

    private func refreshSession(using tokenManager: any SessionTokenManaging) async throws -> Session {
        guard let storedSession = try await tokenManager.loadSession(),
              let refreshToken = storedSession.refreshToken,
              !refreshToken.isEmpty else {
            throw APIClientError.authenticationRequired
        }

        let endpoint = APIEndpoint.refreshSession(refreshToken: refreshToken)
        let request = try makeURLRequest(endpoint)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIClientError.httpStatus(http.statusCode, try? decoder.decode(APIErrorEnvelope.self, from: data))
        }

        let authResponse: AuthResponseDTO
        do {
            authResponse = try decoder.decode(AuthResponseDTO.self, from: data)
        } catch {
            throw APIClientError.decodingFailed(error.localizedDescription)
        }
        let refreshedSession = Session(
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            username: authResponse.user.username
        )
        try await tokenManager.save(session: refreshedSession)
        return refreshedSession
    }

    public func makeURLRequest(_ endpoint: APIEndpoint) throws -> URLRequest {
        var request = URLRequest(url: try endpoint.url(relativeTo: config.apiBaseURL))
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        switch endpoint.body {
        case .json(let data):
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .form(let values):
            request.httpBody = values
                .map { key, value in "\(Self.formEscape(key))=\(Self.formEscape(value))" }
                .joined(separator: "&")
                .data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        case .none:
            break
        }
        return request
    }

    public func authenticatedRequest(_ endpoint: APIEndpoint) async throws -> URLRequest {
        var request = try makeURLRequest(endpoint)
        if endpoint.requiresAuthentication {
            guard let token = try await tokenProvider?.accessToken(), !token.isEmpty else {
                throw APIClientError.authenticationRequired
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private static func formEscape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private actor TokenRefreshCoordinator {
    private var task: Task<Session, Error>?

    func refresh(operation: @escaping @Sendable () async throws -> Session) async throws -> Session {
        if let task {
            return try await task.value
        }

        let newTask = Task { try await operation() }
        task = newTask
        defer { task = nil }
        return try await newTask.value
    }
}

public enum APIClientError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case authenticationRequired
    case httpStatus(Int, APIErrorEnvelope?)
    case decodingFailed(String)
}

public struct APIErrorEnvelope: Decodable, Equatable, Sendable {
    public let errors: [APIErrorDetail]
}

public struct APIErrorDetail: Decodable, Equatable, Sendable {
    public let code: String
    public let message: String
}

public extension JSONDecoder {
    static var ekitapligim: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
