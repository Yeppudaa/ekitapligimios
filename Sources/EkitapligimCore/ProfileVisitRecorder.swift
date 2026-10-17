import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Uses the shared web-policy visit producer introduced in MobileApi 1.0.155.
/// A failed visit must never block opening a public member profile or change a login session.
public final class ProfileVisitRecorder: Sendable {
    private let webBaseURL: URL
    private let tokens: any SessionTokenManaging
    private let session: URLSession

    public init(webBaseURL: URL, tokens: any SessionTokenManaging, session: URLSession? = nil) throws {
        guard webBaseURL.scheme?.lowercased() == "https", webBaseURL.host != nil,
              webBaseURL.user == nil, webBaseURL.password == nil, webBaseURL.query == nil, webBaseURL.fragment == nil,
              webBaseURL.port == nil || webBaseURL.port == 443 else { throw APIClientError.invalidURL }
        self.webBaseURL = webBaseURL
        self.tokens = tokens
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 5; configuration.timeoutIntervalForResource = 5
        self.session = session ?? URLSession(configuration: configuration, delegate: ProfileVisitNoRedirects(), delegateQueue: nil)
    }

    public func record(memberID: Int, account: String?) async -> Bool {
        guard memberID > 0, memberID <= Int(Int32.max), let account, !account.isEmpty, !Task.isCancelled else { return false }
        do {
            guard let captured = try await tokens.loadSession(), captured.username == account,
                  Int(captured.userID ?? "") != memberID else { return false }
            var request = try Self.request(webBaseURL: webBaseURL, memberID: memberID, token: captured.accessToken)
            request.timeoutInterval = 5
            guard !Task.isCancelled, try await tokens.loadSession() == captured else { return false }
            let (data, response) = try await session.data(for: request)
            guard !Task.isCancelled, try await tokens.loadSession() == captured,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  http.url == request.url, data.count <= 65_536 else { return false }
            return (try? JSONDecoder().decode(VisitResponse.self, from: data).success) == true
        } catch { return false }
    }

    public static func request(webBaseURL: URL, memberID: Int, token: String) throws -> URLRequest {
        guard memberID > 0, memberID <= Int(Int32.max), !token.isEmpty, token.utf8.count <= 4096,
              token.utf8.allSatisfy({ $0 > 32 && $0 < 127 }),
              webBaseURL.scheme?.lowercased() == "https", webBaseURL.host != nil,
              webBaseURL.user == nil, webBaseURL.password == nil, webBaseURL.query == nil, webBaseURL.fragment == nil,
              webBaseURL.port == nil || webBaseURL.port == 443 else { throw APIClientError.invalidURL }
        let url = webBaseURL.appendingPathComponent("mobile-api/v1/members/\(memberID)/visit")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"; request.httpBody = Data(); request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData; request.timeoutInterval = 5
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return request
    }

    private struct VisitResponse: Decodable { let success: Bool }
}

private final class ProfileVisitNoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
