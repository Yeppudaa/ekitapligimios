import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import EkitapligimCore

final class AgendaMediaTests: XCTestCase {
    override func tearDown() {
        AgendaMediaProtocol.handler = nil
        AgendaMediaProtocol.declaredLength = nil
        super.tearDown()
    }

    func testLegacyAttachmentPrefersFullImageWhenThumbnailIsEmpty() throws {
        let image = try attachment(#"{"id":21,"url":"https://example.com/full.jpg","thumbnail_url":""}"#)
        XCTAssertEqual(image.displayURL?.absoluteString, "https://example.com/full.jpg")
        XCTAssertFalse(image.protectedImage)
        XCTAssertEqual(image.aspectRatio, 4.0 / 3.0)
    }

    func testAttachmentRejectsInsecureURLAndFallsBackToSecureThumbnail() throws {
        let image = try attachment(#"{"id":"21","url":"http://example.com/photo.jpg","thumbnail_url":" https://example.com/thumb.jpg "}"#)
        XCTAssertEqual(image.displayURL?.absoluteString, "https://example.com/thumb.jpg")
        for url in ["", "file:///tmp/a", "data:image/jpeg;base64,AA", "https://user:pass@example.com/a", "/attachments/1"] {
            XCTAssertNil(AgendaMediaPolicy.imageURL(url))
        }
    }

    func testProtectedAttachmentPreservesPortraitDimensions() throws {
        let image = try attachment(#"{"id":21,"url":"","width":900,"height":1200,"protected_image":true}"#)
        XCTAssertTrue(image.protectedImage)
        XCTAssertEqual(image.aspectRatio, 0.75)
    }

    func testOlderBackendCannotEnablePhotoPublishingByGenericUploadFlag() throws {
        for payload in [#"{"capabilities":{"can_upload":true}}"#, #"{"can_upload_images":true}"#,
                        #"{"image_upload_version":2,"can_upload_images":true}"#] {
            let capability = try JSONDecoder.ekitapligim.decode(AgendaMediaCapabilitiesDTO.self, from: Data(payload.utf8))
            XCTAssertFalse(capability.canUploadImages)
        }
    }

    func testCapabilitiesRespectServerLimitAndClampMaximum() throws {
        for (limit, expected) in [(1_024, 1_024), (90_000_000, AgendaMediaPolicy.maximumUploadBytes), (-1, 0)] {
            let data = Data("{\"image_upload_version\":1,\"can_upload_images\":true,\"maximum_bytes\":\(limit)}".utf8)
            let capability = try JSONDecoder.ekitapligim.decode(AgendaMediaCapabilitiesDTO.self, from: data)
            XCTAssertTrue(capability.canUploadImages)
            XCTAssertEqual(capability.maximumBytes, expected)
        }
    }

    func testPhotoAndUnicodeTextUseOneAuthenticatedMultipartRequest() throws {
        let endpoint = APIEndpoint.createBookAgendaPost(message: "Okuma anı 📖\nYeni satır", postType: .review,
            bookThreadID: "17", rating: 4, photo: Data([0xFF, 0xD8, 0xFF, 0xD9]))
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertEqual(endpoint.path, "book-agenda")
        guard case .multipart(let file) = endpoint.body else { return XCTFail("Missing multipart") }
        XCTAssertEqual(file.field, "image")
        XCTAssertEqual(file.fields["image_upload"], "1")
        XCTAssertEqual(file.fields["book_thread_id"], "17")
        XCTAssertEqual(file.fields["rating"], "4")
        let body = APIClient.multipartBody(for: file, boundary: "boundary")
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("name=\"message\"\r\n\r\nOkuma anı 📖\nYeni satır\r\n"))
        XCTAssertTrue(text.contains("name=\"image\"; filename=\"agenda.jpg\"\r\nContent-Type: image/jpeg"))
        XCTAssertTrue(body.range(of: file.data) != nil)
        XCTAssertTrue(text.hasSuffix("\r\n--boundary--\r\n"))
        XCTAssertEqual(text.components(separatedBy: "filename=").count, 2)
    }

    func testTextOnlyPostsRetainTheirFormContract() {
        XCTAssertEqual(APIEndpoint.createBookAgendaPost(message: "Hello", postType: .standard).body,
            .form(["message": "Hello", "post_type": "standard", "visibility": "public"]))
    }

    func testBadAndDuplicateAttachmentsDoNotBreakThePostOrGalleryIdentity() throws {
        let data = Data(#"{"id":9,"attachments":[null,{"id":"21","url":"https://example.com/a.jpg"},{"broken":true},{"id":"21","url":"https://example.com/a.jpg"},{"id":22,"url":"https://example.com/b.jpg","width":"800","height":"600"}]}"#.utf8)
        let post = try JSONDecoder.ekitapligim.decode(BookAgendaPostDTO.self, from: data)
        XCTAssertEqual(post.attachments.map(\.id), ["21", "22"])
        XCTAssertEqual(post.attachments.last?.aspectRatio, 4.0 / 3.0)
    }

    func testUnsupportedServerMakesNoPostRequestWithSelectedPhoto() async throws {
        AgendaMediaProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertTrue(request.url?.query?.contains("media_capabilities=1") == true)
            return (200, "application/json", Data(#"{"items":[],"capabilities":{"can_upload":true}}"#.utf8))
        }
        do {
            _ = try await repository().createPost(message: "photo", postType: .standard, photo: Data([1]))
            XCTFail("Must not publish without photo support")
        } catch AgendaMediaError.uploadUnavailable {}
    }

    func testProtectedImageUsesFixedAPIRouteAndBearer() async throws {
        AgendaMediaProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "example.com")
            XCTAssertEqual(request.url?.path, "/ios-api/v1/book-agenda/9")
            XCTAssertEqual(request.url?.query, "image_id=21")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-session")
            return (200, "image/jpeg", Data([1, 2, 3]))
        }
        let image = try attachment(#"{"id":21,"url":"https://untrusted.example/a","protected_image":true}"#)
        let data = try await repository().image(postID: "9", attachment: image)
        XCTAssertEqual(data, Data([1, 2, 3]))
    }

    func testSupportedServerPublishesPhotoOnlyWithFileAndReturnsItsAttachment() async throws {
        AgendaMediaProtocol.handler = { request in
            if request.httpMethod == "GET" {
                return (200, "application/json", Data(#"{"image_upload_version":1,"can_upload_images":true,"maximum_bytes":8388608}"#.utf8))
            }
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-session")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data;") == true)
            return (200, "application/json", Data(#"{"post":{"id":9,"message":"","attachments":[{"id":21,"protected_image":true}]}}"#.utf8))
        }
        let post = try await repository().createPost(message: "", postType: .standard, photo: Data([0xFF, 0xD8]))
        XCTAssertEqual(post.id, "9")
        XCTAssertEqual(post.attachments.first?.id, "21")
    }

    func testServerImageSizeRestrictionStopsThePostRequest() async throws {
        AgendaMediaProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET", "Oversized photo must not post")
            return (200, "application/json", Data(#"{"image_upload_version":1,"can_upload_images":true,"maximum_bytes":1}"#.utf8))
        }
        do {
            _ = try await repository().createPost(message: "photo", postType: .standard, photo: Data([1, 2]))
            XCTFail("Server upload limit must be respected")
        } catch AgendaMediaError.imageTooLarge {}
    }

    func testTruncatedImageBodyCannotBeDisplayedAsSuccessfulPhoto() async throws {
        AgendaMediaProtocol.declaredLength = 20
        AgendaMediaProtocol.handler = { _ in (200, "image/jpeg", Data([1, 2, 3])) }
        let image = try attachment(#"{"id":21,"url":"https://example.com/a.jpg"}"#)
        do { _ = try await repository().image(postID: "9", attachment: image); XCTFail("Truncated image accepted") }
        catch AgendaMediaError.invalidImage {}
    }

    func testImageRequestNeverFollowsRedirectWithProtectedBearer() throws {
        let transport = AgendaImageTransport()
        let source = try XCTUnwrap(URL(string: "https://example.com/ios-api/v1/book-agenda/9?image_id=21"))
        let target = try XCTUnwrap(URL(string: "https://other.example/private.jpg"))
        let response = try XCTUnwrap(HTTPURLResponse(url: source, statusCode: 302, httpVersion: nil, headerFields: ["Location": target.absoluteString]))
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: source)
        defer { task.cancel(); session.invalidateAndCancel() }
        var request = URLRequest(url: target)
        request.setValue("Bearer test-session", forHTTPHeaderField: "Authorization")
        transport.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request) { redirect in
            XCTAssertNil(redirect)
        }
    }

    func testPublicImageNeverReceivesBearerOrCookie() async throws {
        AgendaMediaProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "cdn.example.com")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            return (200, "image/png", Data([4, 5]))
        }
        let image = try attachment(#"{"id":"inline-1","url":"https://cdn.example.com/photo.png"}"#)
        let data = try await repository().image(postID: "9", attachment: image)
        XCTAssertEqual(data, Data([4, 5]))
    }

    func testHTMLAndOversizedImageResponsesAreRejected() async throws {
        let image = try attachment(#"{"id":21,"url":"https://example.com/a.jpg"}"#)
        for response in [("text/html", Data("Login page".utf8)),
                         ("image/jpeg", Data(repeating: 1, count: AgendaMediaPolicy.maximumDownloadBytes + 1))] {
            AgendaMediaProtocol.handler = { _ in (200, response.0, response.1) }
            do { _ = try await repository().image(postID: "9", attachment: image); XCTFail("Invalid image accepted") }
            catch AgendaMediaError.invalidImage {}
        }
    }

    func testProtectedImageDoesNotFallBackToPublicURLAfterPermissionDenial() async throws {
        AgendaMediaProtocol.handler = { request in
            XCTAssertTrue(request.url?.path.contains("book-agenda/9") == true)
            return (403, "application/json", Data())
        }
        let image = try attachment(#"{"id":21,"url":"https://cdn.example.com/private.jpg","protected_image":true}"#)
        do { _ = try await repository().image(postID: "9", attachment: image); XCTFail("Denied image accepted") }
        catch APIClientError.httpStatus(403, _) {}
    }

    func testAccountChangeDuringPhotoCapabilityCheckCannotPublishTheOldDraft() async throws {
        let tokens = MutableAgendaMediaTokens()
        AgendaMediaProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET", "An old photo draft must never POST as the new account")
            tokens.set("different-account")
            return (200, "application/json", Data(#"{"image_upload_version":1,"can_upload_images":true,"maximum_bytes":8388608}"#.utf8))
        }
        do {
            _ = try await repository(tokenProvider: tokens).createPost(message: "private draft", postType: .standard, photo: Data([1]))
            XCTFail("Account replacement must cancel publishing")
        } catch is CancellationError {}
    }

    func testSignOutDuringPhotoCapabilityCheckDoesNotPublish() async throws {
        let tokens = MutableAgendaMediaTokens()
        AgendaMediaProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            tokens.set(nil)
            return (200, "application/json", Data(#"{"image_upload_version":1,"can_upload_images":true,"maximum_bytes":8388608}"#.utf8))
        }
        do {
            _ = try await repository(tokenProvider: tokens).createPost(message: "draft", postType: .standard, photo: Data([1]))
            XCTFail("Signed-out draft must not publish")
        } catch APIClientError.authenticationRequired {}
    }

    private func attachment(_ json: String) throws -> BookAgendaAttachmentDTO {
        try JSONDecoder.ekitapligim.decode(BookAgendaAttachmentDTO.self, from: Data(json.utf8))
    }
    private func repository(tokenProvider: any AccessTokenProviding = AgendaMediaTokens()) throws -> BookAgendaRepository {
        let config = AppConfig(environment: .production,
            apiBaseURL: try XCTUnwrap(URL(string: "https://example.com/ios-api/v1/")),
            webBaseURL: try XCTUnwrap(URL(string: "https://example.com")))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AgendaMediaProtocol.self]
        return BookAgendaRepository(apiClient: APIClient(config: config, session: URLSession(configuration: configuration),
            tokenProvider: tokenProvider))
    }
}

private struct AgendaMediaTokens: AccessTokenProviding {
    func accessToken() async throws -> String? { "test-session" }
}

private final class MutableAgendaMediaTokens: AccessTokenProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String? = "test-session"
    func set(_ token: String?) { lock.withLock { value = token } }
    func accessToken() async throws -> String? { lock.withLock { value } }
}

private final class AgendaMediaProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, String, Data))?
    nonisolated(unsafe) static var declaredLength: Int?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler, let url = request.url else { throw URLError(.badURL) }
            let (status, mime, data) = try handler(request)
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": mime, "Content-Length": String(Self.declaredLength ?? data.count)]) else { throw URLError(.badServerResponse) }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty { client?.urlProtocol(self, didLoad: data) }
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
