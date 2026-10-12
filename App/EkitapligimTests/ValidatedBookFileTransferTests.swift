import Foundation
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class ValidatedBookFileTransferTests: XCTestCase {
    private func sourceURL(for object: [String: Any]) throws -> URL? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        return ValidatedBookFileTransfer.jsonSourceURL(at: file)
    }

    func testFollowsHTTPSJSONSourcesLikeAndroidReader() throws {
        let target = "https://books.example.com/read/book.pdf?t=temporary"
        for key in ["source_url", "sourceUrl", "url"] {
            XCTAssertEqual(try sourceURL(for: [key: target])?.absoluteString, target)
        }
        XCTAssertEqual(try sourceURL(for: ["innerContent": ["source_url": target]])?.absoluteString, target)
    }

    func testRejectsInsecureJSONSourcesAndOversizedRedirectBodies() throws {
        XCTAssertNil(try sourceURL(for: ["source_url": "http://books.example.com/book.pdf"]))
        XCTAssertNil(try sourceURL(for: ["source_url": "file:///private/book.pdf"]))
        XCTAssertNil(try sourceURL(for: ["source_url": "https://books.example.com/book.pdf", "metadata": String(repeating: "x", count: 65_537)]))
    }

    func testConvertsDriveShareURLBeforeDownloading() throws {
        let source = try sourceURL(for: ["sourceUrl": "https://drive.google.com/file/d/book42/view"])
        XCTAssertEqual(source?.host, "drive.usercontent.google.com")
        XCTAssertTrue(source?.query?.contains("id=book42") == true)
    }

    func testLateProgressCannotReplaceValidationOrOpening() {
        var phases: [ReaderLoadingPhase] = []
        let delivery = BookDownloadProgressDelivery { phases.append($0) }
        let progress = BookTransferProgress(receivedBytes: 100, expectedBytes: 200)
        delivery.receive(progress)
        delivery.finish()
        phases.append(.validating)
        delivery.receive(BookTransferProgress(receivedBytes: 200, expectedBytes: 200))

        XCTAssertEqual(phases, [.downloading(progress), .validating])
    }

    func testDiskFullIncludesUnderlyingURLSessionPOSIXError() {
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: 28)
        let wrapped = NSError(domain: NSURLErrorDomain, code: -3003, userInfo: [NSUnderlyingErrorKey: underlying])
        XCTAssertTrue(ValidatedBookFileTransfer.isOutOfSpace(wrapped))
        XCTAssertTrue(ValidatedBookFileTransfer.isOutOfSpace(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)))
        XCTAssertFalse(ValidatedBookFileTransfer.isOutOfSpace(NSError(domain: NSURLErrorDomain, code: NSFileWriteOutOfSpaceError)))
        XCTAssertFalse(ValidatedBookFileTransfer.isOutOfSpace(URLError(.networkConnectionLost)))
    }

    func testExpiredReaderTokenRefreshesOnceAndInstallsFile() async throws {
        let fixture = try TransferFixture(statuses: [401, 200])
        defer { fixture.cleanUp() }
        let store = TransferTokenStore("expired")
        let transfer = ValidatedBookFileTransfer(
            tokenProvider: store, apiBaseURL: fixture.apiURL,
            refreshAccessToken: { token in
                await fixture.recordRefresh(token)
                await store.setToken("renewed")
                return "renewed"
            }, downloadFile: fixture.download
        )
        try await transfer.download(from: fixture.sourceURL, fileType: "pdf", to: fixture.destinationURL)
        XCTAssertEqual(fixture.authorizations, ["Bearer expired", "Bearer renewed"])
        XCTAssertEqual(fixture.refreshTokens, ["expired"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.destinationURL.path))
        XCTAssertTrue(fixture.temporaryFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testResourceDenialAfterRefreshDoesNotRefreshAgain() async throws {
        let fixture = try TransferFixture(statuses: [401, 401])
        defer { fixture.cleanUp() }
        let store = TransferTokenStore("expired")
        let transfer = ValidatedBookFileTransfer(
            tokenProvider: store, apiBaseURL: fixture.apiURL,
            refreshAccessToken: { token in
                await fixture.recordRefresh(token)
                await store.setToken("renewed")
                return "renewed"
            }, downloadFile: fixture.download
        )
        do {
            try await transfer.download(from: fixture.sourceURL, fileType: "pdf", to: fixture.destinationURL)
            XCTFail("An unauthorized file must not be installed")
        } catch BookFileTransferError.serverRejected { }
        XCTAssertEqual(fixture.authorizations.count, 2)
        XCTAssertEqual(fixture.refreshTokens, ["expired"])
        let token = try await store.accessToken()
        XCTAssertEqual(token, "renewed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destinationURL.path))
    }

    func testPermissionErrorsAndExternalFailuresNeverRefresh() async throws {
        for scenario in ["forbidden", "external", "redirected"] {
            let fixture = try TransferFixture(statuses: [scenario == "forbidden" ? 403 : 401])
            defer { fixture.cleanUp() }
            let store = TransferTokenStore("valid")
            let externalURL = try XCTUnwrap(URL(string: "https://files.example.com/book.pdf"))
            if scenario == "redirected" { fixture.responseURL = externalURL }
            let transfer = ValidatedBookFileTransfer(
                tokenProvider: store, apiBaseURL: fixture.apiURL,
                refreshAccessToken: { token in await fixture.recordRefresh(token); return "unexpected" },
                downloadFile: fixture.download
            )
            do {
                try await transfer.download(
                    from: scenario == "external" ? externalURL : fixture.sourceURL,
                    fileType: "pdf", to: fixture.destinationURL
                )
                XCTFail("Rejected file accepted")
            } catch BookFileTransferError.serverRejected { }
            XCTAssertTrue(fixture.refreshTokens.isEmpty, scenario)
            XCTAssertEqual(fixture.authorizations.count, 1)
            if scenario == "external" { XCTAssertNil(fixture.authorizations[0]) }
        }
    }

    func testAccountChangeDuringRefreshCancelsFileRetry() async throws {
        let fixture = try TransferFixture(statuses: [401])
        defer { fixture.cleanUp() }
        let store = TransferTokenStore("expired")
        let transfer = ValidatedBookFileTransfer(
            tokenProvider: store, apiBaseURL: fixture.apiURL,
            refreshAccessToken: { _ in
                await store.setToken("another-account")
                return "old-account-renewed"
            }, downloadFile: fixture.download
        )
        do {
            try await transfer.download(from: fixture.sourceURL, fileType: "pdf", to: fixture.destinationURL)
            XCTFail("Stale-account retry accepted")
        } catch is CancellationError { }
        XCTAssertEqual(fixture.authorizations.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destinationURL.path))
    }

    func testTemporaryRefreshFailureCanBeRetriedWithoutClearingCredentials() async throws {
        let fixture = try TransferFixture(statuses: [401])
        defer { fixture.cleanUp() }
        let store = TransferTokenStore("expired")
        let transfer = ValidatedBookFileTransfer(
            tokenProvider: store, apiBaseURL: fixture.apiURL,
            refreshAccessToken: { _ in throw URLError(.networkConnectionLost) },
            downloadFile: fixture.download
        )
        do {
            try await transfer.download(from: fixture.sourceURL, fileType: "pdf", to: fixture.destinationURL)
            XCTFail("Expected network failure")
        } catch let error as URLError { XCTAssertEqual(error.code, .networkConnectionLost) }
        let token = try await store.accessToken()
        XCTAssertEqual(token, "expired")
        XCTAssertTrue(fixture.temporaryFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }

    func testTemporarilyUnavailableKeychainDoesNotSendGuestDownload() async throws {
        let fixture = try TransferFixture(statuses: [])
        defer { fixture.cleanUp() }
        let transfer = ValidatedBookFileTransfer(
            tokenProvider: UnavailableTransferTokenStore(), apiBaseURL: fixture.apiURL,
            downloadFile: fixture.download
        )
        do {
            try await transfer.download(from: fixture.sourceURL, fileType: "pdf", to: fixture.destinationURL)
            XCTFail("Expected secure storage error")
        } catch TransferTestError.storageUnavailable { }
        XCTAssertTrue(fixture.authorizations.isEmpty)
    }
}

private enum TransferTestError: Error { case storageUnavailable }
private struct UnavailableTransferTokenStore: AccessTokenProviding {
    func accessToken() async throws -> String? { throw TransferTestError.storageUnavailable }
}
private actor TransferTokenStore: AccessTokenProviding {
    private var token: String?
    init(_ token: String) { self.token = token }
    func accessToken() async throws -> String? { token }
    func setToken(_ value: String?) { token = value }
}

@MainActor
private final class TransferFixture {
    let directory: URL
    let apiURL: URL
    let sourceURL: URL
    let destinationURL: URL
    var responseURL: URL?
    var authorizations: [String?] = []
    var refreshTokens: [String] = []
    var temporaryFiles: [URL] = []
    private var statuses: [Int]

    init(statuses: [Int]) throws {
        self.statuses = statuses
        apiURL = try XCTUnwrap(URL(string: "https://ekitapligim.com/ios-api/v1/"))
        sourceURL = apiURL.appendingPathComponent("books/42/reader/source")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        destinationURL = directory.appendingPathComponent("installed/book.pdf")
    }

    func recordRefresh(_ token: String) { refreshTokens.append(token) }
    func cleanUp() { try? FileManager.default.removeItem(at: directory) }
    func download(_ request: URLRequest, _ delegate: URLSessionTaskDelegate) async throws -> (URL, URLResponse) {
        authorizations.append(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertFalse(statuses.isEmpty, "Unexpected additional download")
        let status = statuses.isEmpty ? 500 : statuses.removeFirst()
        let file = directory.appendingPathComponent(UUID().uuidString)
        try Data((status == 200 ? "%PDF-1.7\nbook body" : "unauthorized").utf8).write(to: file)
        temporaryFiles.append(file)
        let url = try XCTUnwrap(responseURL ?? request.url)
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
        return (file, response)
    }
}
