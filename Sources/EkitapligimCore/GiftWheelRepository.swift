import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol GiftWheelServing: Sendable {
    func status(account: String) async throws -> GiftWheelStatusDTO
    func winners(account: String) async throws -> [GiftWheelEntryDTO]
    func spin(account: String, pending: PendingGiftSpin) async throws -> GiftWheelSpinDTO
}

/// PremiumWheel's own transport. No MobileApi endpoints, cookie storage, API keys or billing dependencies.
public final class GiftWheelRepository: GiftWheelServing, Sendable {
    private let baseURL: URL
    private let tokens: any SessionTokenManaging
    private let session: URLSession
    private let refresh: @Sendable () async throws -> Void
    public init(webBaseURL: URL, tokens: any SessionTokenManaging,
                refresh: @escaping @Sendable () async throws -> Void, session: URLSession? = nil) {
        self.baseURL = webBaseURL
        self.tokens = tokens
        self.refresh = refresh
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForResource = 30
        self.session = session ?? URLSession(configuration: configuration, delegate: WheelNoRedirects(), delegateQueue: nil)
    }
    public func status(account: String) async throws -> GiftWheelStatusDTO {
        let response: GiftWheelStatusDTO = try await request("status", account: account)
        return try response.validated()
    }
    public func winners(account: String) async throws -> [GiftWheelEntryDTO] {
        let response: GiftWheelWinnersDTO = try await request("winners", account: account)
        guard response.apiVersion == 1 else { throw GiftWheelError.invalidResponse }
        return response.winners
    }
    public func spin(account: String, pending: PendingGiftSpin) async throws -> GiftWheelSpinDTO {
        guard pending.isValid else { throw GiftWheelError.invalidResponse }
        return try await request("spin", account: account, body: "request_key=\(pending.key)&revision=\(pending.revision)")
    }
    public func makeRequest(action: String, token: String, body: String? = nil) throws -> URLRequest {
        let host = baseURL.host?.lowercased() ?? ""
        guard baseURL.scheme == "https", ["ekitapligim.com", "www.ekitapligim.com"].contains(host),
              baseURL.user == nil, baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil,
              ["status", "spin", "winners"].contains(action) else { throw GiftWheelError.invalidConfiguration }
        guard token.hasPrefix("ms_at_"), !token.contains("\r"), !token.contains("\n") else { throw GiftWheelError.authenticationRequired }
        var request = URLRequest(url: baseURL.appendingPathComponent("hediye-carki-api").appendingPathComponent(action))
        request.httpMethod = body == nil ? "GET" : "POST"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = Data(body.utf8)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
    private func request<T: Decodable>(_ action: String, account: String, body: String? = nil) async throws -> T {
        for attempt in 0...1 {
            try Task.checkCancellation()
            guard let identity = try await tokens.loadSession(), identity.username == account else { throw GiftWheelError.authenticationRequired }
            let request = try makeRequest(action: action, token: identity.accessToken, body: body)
            let (data, response) = try await session.data(for: request)
            guard try await tokens.loadSession()?.username == account else { throw GiftWheelError.authenticationRequired }
            guard let http = response as? HTTPURLResponse else { throw GiftWheelError.invalidResponse }
            if http.statusCode == 401 {
                guard attempt == 0 else { throw GiftWheelError.authenticationRequired }
                do { try await refresh() }
                catch APIClientError.authenticationRequired { throw GiftWheelError.authenticationRequired }
                continue // POST retains precisely the same persisted request key.
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let failure = try? decoder.decode(WheelErrorEnvelopeDTO.self, from: data)
            guard (200..<300).contains(http.statusCode), failure == nil else {
                throw GiftWheelError.server(http.statusCode, failure?.error.message)
            }
            do { return try decoder.decode(T.self, from: data) }
            catch { throw GiftWheelError.invalidResponse }
        }
        throw GiftWheelError.authenticationRequired
    }
}

private struct WheelErrorEnvelopeDTO: Decodable {
    struct DetailDTO: Decodable { let message: String }
    let error: DetailDTO
}

private final class WheelNoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
