import XCTest
@testable import EkitapligimCore

final class ReaderSourcePolicyTests: XCTestCase {
    func testConvertsGoogleDrivePreviewURLToBinaryDownload() throws {
        let source = try XCTUnwrap(URL(string: "https://drive.google.com/file/d/abc_DEF-123/view?usp=sharing"))
        let result = try XCTUnwrap(ReaderSourcePolicy.downloadableURL(from: source))
        let components = try XCTUnwrap(URLComponents(url: result, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.host, "drive.usercontent.google.com")
        XCTAssertEqual(components.path, "/download")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "id" })?.value, "abc_DEF-123")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "confirm" })?.value, "t")
    }

    func testConvertsGoogleDriveOpenURL() throws {
        let source = try XCTUnwrap(URL(string: "https://drive.google.com/open?id=book42"))

        XCTAssertEqual(
            ReaderSourcePolicy.downloadableURL(from: source)?.host,
            "drive.usercontent.google.com"
        )
    }

    func testPreservesGoogleDriveResourceKey() throws {
        let source = try XCTUnwrap(URL(string: "https://drive.google.com/file/d/abc_DEF-123/view?resourcekey=abc-9"))
        let result = try XCTUnwrap(ReaderSourcePolicy.downloadableURL(from: source))
        let components = try XCTUnwrap(URLComponents(url: result, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "resourcekey" })?.value, "abc-9")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "id" })?.value, "abc_DEF-123")
    }

    func testConvertsDocsGoogleFileURL() throws {
        let source = try XCTUnwrap(URL(string: "https://docs.google.com/file/d/abc_DEF-123/edit"))
        let result = try XCTUnwrap(ReaderSourcePolicy.downloadableURL(from: source))
        let components = try XCTUnwrap(URLComponents(url: result, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.host, "drive.usercontent.google.com")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "id" })?.value, "abc_DEF-123")
    }

    func testPreservesTemporaryServerURLAndToken() throws {
        let source = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/books/42/reader/source?t=secret"))

        XCTAssertEqual(ReaderSourcePolicy.downloadableURL(from: source), source)
    }

    func testRejectsInsecureSource() throws {
        let source = try XCTUnwrap(URL(string: "http://drive.google.com/file/d/book42/view"))

        XCTAssertNil(ReaderSourcePolicy.downloadableURL(from: source))
    }

    func testDoesNotUseWebReadSourceForNativeDownload() throws {
        let session = ReaderSessionDTO(
            token: "reader-token",
            sourceUrl: "https://ekitapligim.com/books/yanlis-hedef.15585/read-source?t=reader-token",
            fileType: "pdf",
            apiSourceUrl: "https://ekitapligim.com/api/v1/books/reader-source?t=reader-token"
        )
        let apiBase = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))
        let result = try XCTUnwrap(ReaderSourcePolicy.nativeContentURL(session: session, bookID: 15585, apiBaseURL: apiBase))

        XCTAssertEqual(result.scheme, "https")
        XCTAssertFalse(result.path.contains("read-source"))
        XCTAssertTrue(result.path.contains("/reader/source"))
        XCTAssertTrue(result.path.contains("/books/15585/"))
        XCTAssertEqual(
            URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "t" })?.value,
            "reader-token"
        )
    }

    func testUsesExistingNativeReaderSourceURL() throws {
        let native = "https://ekitapligim.com/ios-api/v1/books/42/reader/source?t=secret"
        let session = ReaderSessionDTO(
            token: "secret",
            sourceUrl: "https://ekitapligim.com/books/kitap.42/read-source?t=secret",
            fileType: "pdf",
            apiSourceUrl: native
        )
        let apiBase = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))
        let result = try XCTUnwrap(ReaderSourcePolicy.nativeContentURL(session: session, bookID: 42, apiBaseURL: apiBase))

        XCTAssertEqual(result, try XCTUnwrap(URL(string: native)))
    }

    func testUsesGoogleDriveCandidateWhenSessionPointsAtDrive() throws {
        let session = ReaderSessionDTO(
            token: "secret",
            sourceUrl: "https://drive.google.com/file/d/abc_DEF-123/view?usp=sharing",
            fileType: "pdf"
        )
        let apiBase = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))
        let result = try XCTUnwrap(ReaderSourcePolicy.nativeContentURL(session: session, bookID: 42, apiBaseURL: apiBase))

        XCTAssertEqual(result.host, "drive.usercontent.google.com")
        XCTAssertEqual(
            URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value,
            "abc_DEF-123"
        )
    }

    func testParsesGoogleDriveConfirmHref() throws {
        let html = """
        <html><body><a href="/uc?export=download&amp;confirm=ABCD&amp;id=abc_DEF-123">Download anyway from drive.google.com</a></body></html>
        """
        let url = try XCTUnwrap(ReaderSourcePolicy.googleDriveConfirmURL(from: html))

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "drive.google.com")
        XCTAssertTrue(url.absoluteString.contains("confirm=ABCD"))
        XCTAssertTrue(url.absoluteString.contains("id=abc_DEF-123"))
    }

    func testAttachesBearerOnlyToAPIHost() throws {
        let apiBase = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))
        let source = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/books/1/reader/source?t=x"))
        let drive = try XCTUnwrap(URL(string: "https://drive.usercontent.google.com/download?id=a&export=download"))

        XCTAssertTrue(ReaderSourcePolicy.shouldAttachAccessToken(to: source, apiBaseURL: apiBase))
        XCTAssertFalse(ReaderSourcePolicy.shouldAttachAccessToken(to: drive, apiBaseURL: apiBase))
    }
}
