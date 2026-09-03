import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class APIClientTests: XCTestCase {
    func testAuthenticatedRequestAddsBearerToken() async throws {
        let config = try makeConfig()
        let client = APIClient(config: config, tokenProvider: InMemoryTokenProvider(token: "abc123"))

        let request = try await client.authenticatedRequest(.library)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc123")
    }

    func testOptionalAuthAttachesBearerWhenTokenIsAvailable() async throws {
        let config = try makeConfig()
        let client = APIClient(config: config, tokenProvider: InMemoryTokenProvider(token: "abc123"))

        let request = try await client.authenticatedRequest(.chatRooms)

        XCTAssertFalse(APIEndpoint.chatRooms.requiresAuthentication)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc123")
    }

    func testRequiredAuthWithoutTokenThrows() async throws {
        let config = try makeConfig()
        let client = APIClient(config: config)

        do {
            _ = try await client.authenticatedRequest(.library)
            XCTFail("Expected authenticationRequired")
        } catch APIClientError.authenticationRequired {
            // expected
        }
    }

    func testLoginEndpointUsesFormBody() throws {
        let config = try makeConfig()
        let client = APIClient(config: config)

        let request = try client.makeURLRequest(.login(
            username: "demo@example.com",
            password: "secret value",
            acceptedTermsVersion: "2026-08"
        ))
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertTrue(body?.contains("login=demo@example.com") == true)
        XCTAssertTrue(body?.contains("password=secret%20value") == true)
        XCTAssertTrue(body?.contains("accepted_terms_version=2026-08") == true)
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

    func testGoogleAuthEndpointUsesFormBody() throws {
        let config = try makeConfig()
        let client = APIClient(config: config)

        let request = try client.makeURLRequest(.googleAuth(idToken: "id.token+value"))
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(body, "id_token=id.token%2Bvalue")
        XCTAssertEqual(APIEndpoint.googleAuth(idToken: "id.token+value").path, "auth/google")
    }

    func testGoogleRegistrationEndpointIncludesUsername() throws {
        let config = try makeConfig()
        let client = APIClient(config: config)

        let request = try client.makeURLRequest(.googleAuth(idToken: "id.token", username: "Yeni Okur"))
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)

        XCTAssertTrue(body?.contains("id_token=id.token") == true)
        XCTAssertTrue(body?.contains("username=Yeni%20Okur") == true)
    }

    func testXenForoErrorDecodesObjectOrEmptyArrayParams() throws {
        let decoder = JSONDecoder.ekitapligim
        let usernameRequired = Data(#"{"errors":[{"code":"username_required","message":"Kullanıcı adı gerekli.","params":{"suggested_username":"Yeni Okur","email":"okur@example.com"}}]}"#.utf8)
        let ordinaryError = Data(#"{"errors":[{"code":"google_token_invalid","message":"Geçersiz.","params":[]}]}"#.utf8)

        let requiredEnvelope = try decoder.decode(APIErrorEnvelope.self, from: usernameRequired)
        let ordinaryEnvelope = try decoder.decode(APIErrorEnvelope.self, from: ordinaryError)

        XCTAssertEqual(requiredEnvelope.errors.first?.params?["suggested_username"], "Yeni Okur")
        XCTAssertNil(ordinaryEnvelope.errors.first?.params)
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
            apiBaseURL: try XCTUnwrap(URL(string: "https://staging.ekitapligim.com/ios-api/v1/")),
            webBaseURL: try XCTUnwrap(URL(string: "https://ekitapligim.com/"))
        )
    }
}
