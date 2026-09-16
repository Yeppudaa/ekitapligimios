import XCTest
@testable import Ekitapligim
import EkitapligimCore

@MainActor
final class SessionInvalidationTests: XCTestCase {
    private var temporaryDirectory: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testRemoteSessionInvalidationPreservesDownloads() throws {
        let container = AppContainer()
        let manager = container.downloadManager
        let localURL = try manager.localURL(for: "42", fileExtension: "pdf")
        temporaryDirectory = localURL.deletingLastPathComponent()
        try Data("%PDF-1.7".utf8).write(to: localURL)
        manager.restoreDownloads()
        container.authState = .signedIn(Session(accessToken: "token", refreshToken: "refresh", username: "reader"))

        container.markRemoteSessionInvalidated()

        XCTAssertEqual(container.authState, .expired)
        XCTAssertNotNil(manager.localFile(for: "42"))
        XCTAssertEqual(manager.states["42"], .downloaded(localFileName: "book-42.pdf"))
    }
}
