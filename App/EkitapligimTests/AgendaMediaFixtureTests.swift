import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
import EkitapligimCore
@testable import Ekitapligim

final class AgendaMediaFixtureTests: XCTestCase {
    func testCapabilitiesAndImageBytesMatchEveryConfiguredOrigin() throws {
        for host in ["ekitapligim.local.invalid", "staging.ekitapligim.com", "ekitapligim.com"] {
            let capabilityURL = try XCTUnwrap(URL(string: "https://\(host)/ios-api/v1/book-agenda?media_capabilities=1"))
            let capability = try XCTUnwrap(ModernParityAgendaMediaFixture.response(for: URLRequest(url: capabilityURL), scenario: "portrait"))
            let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
            XCTAssertTrue(try decoder.decode(AgendaMediaCapabilitiesDTO.self, from: capability.data).canUploadImages)
            let imageURL = try XCTUnwrap(URL(string: "https://\(host)/ios-api/v1/book-agenda/940001?image_id=21"))
            let image = try XCTUnwrap(ModernParityAgendaMediaFixture.response(for: URLRequest(url: imageURL), scenario: "portrait"))
            XCTAssertEqual(image.mime, "image/png")
            XCTAssertEqual(Array(image.data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
            let failed = try XCTUnwrap(ModernParityAgendaMediaFixture.response(for: URLRequest(url: imageURL), scenario: "failure"))
            XCTAssertEqual(failed.status, 503)
        }
    }

    func testMediaFixtureRejectsUnknownAndInsecureOrigins() throws {
        for origin in ["http://ekitapligim.com", "https://unrelated.invalid", "https://ekitapligim.com:444", "https://user@ekitapligim.com"] {
            let url = try XCTUnwrap(URL(string: origin + "/ios-api/v1/book-agenda?media_capabilities=1"))
            XCTAssertNil(ModernParityAgendaMediaFixture.response(for: URLRequest(url: url), scenario: "portrait"))
        }
    }

    func testPhotoOnlyPostPassesThroughActualURLSessionMultipartTransport() async throws {
        let config = AppConfig(environment: .development,
            apiBaseURL: try XCTUnwrap(URL(string: "https://ekitapligim.local.invalid/ios-api/v1/")),
            webBaseURL: try XCTUnwrap(URL(string: "https://ekitapligim.com/")))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AgendaFixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let repository = BookAgendaRepository(apiClient: APIClient(config: config, session: session, tokenProvider: AgendaFixtureToken()))
        let post = try await repository.createPost(message: "", postType: .standard, photo: Data([255, 216, 255, 217]))
        XCTAssertEqual(post.id, "940001")
        XCTAssertEqual(post.attachments.count, 1)
    }
}

private struct AgendaFixtureToken: AccessTokenProviding {
    func accessToken() async throws -> String? { "offline-agenda-fixture-token" }
}

private final class AgendaFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url,
              let result = ModernParityAgendaMediaFixture.response(for: request, scenario: "portrait"),
              let response = HTTPURLResponse(url: url, statusCode: result.status, httpVersion: nil, headerFields: ["Content-Type": result.mime]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
