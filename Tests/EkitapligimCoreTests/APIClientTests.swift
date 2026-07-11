import XCTest
@testable import EkitapligimCore

final class APIClientTests: XCTestCase {
    func testAuthenticatedRequestAddsBearerToken() async throws {
        let config = try makeConfig()
        let client = APIClient(config: config, tokenProvider: InMemoryTokenProvider(token: "abc123"))

        let request = try await client.authenticatedRequest(.library)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc123")
    }

    func testLoginEndpointUsesFormBody() throws {
        let config = try makeConfig()
        let client = APIClient(config: config)

        let request = try client.makeURLRequest(.login(username: "demo@example.com", password: "secret value"))
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertTrue(body?.contains("login=demo@example.com") == true)
        XCTAssertTrue(body?.contains("password=secret%20value") == true)
    }

    func testFormBodyEscapesSeparators() throws {
        let config = try makeConfig()
        let client = APIClient(config: config)

        let request = try client.makeURLRequest(.forgotPassword(email: "a&b=1@example.com"))
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)

        XCTAssertEqual(body, "email=a%26b%3D1@example.com")
    }

    func testAppleAuthEndpointUsesFormBody() throws {
        let config = try makeConfig()
        let client = APIClient(config: config)

        let request = try client.makeURLRequest(.appleAuth(identityToken: "identity", authorizationCode: "code", nonce: "raw-nonce"))
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(body?.contains("identity_token=identity") == true)
        XCTAssertTrue(body?.contains("authorization_code=code") == true)
        XCTAssertTrue(body?.contains("nonce=raw-nonce") == true)
    }

    func testRefreshEndpointUsesRefreshTokenWithoutBearerAuthorization() throws {
        let config = try makeConfig()
        let client = APIClient(config: config)

        let request = try client.makeURLRequest(.refreshSession(refreshToken: "ms_rt_secret+value"))
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(body, "refresh_token=ms_rt_secret%2Bvalue")
    }

    private func makeConfig() throws -> AppConfig {
        AppConfig(
            environment: .staging,
            apiBaseURL: try XCTUnwrap(URL(string: "https://staging.ekitapligim.com/mobile-api/v1/")),
            webBaseURL: try XCTUnwrap(URL(string: "https://ekitapligim.com/"))
        )
    }
}
