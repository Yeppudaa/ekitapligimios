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

    func testTemporarilyUnavailableKeychainDoesNotExpireSignedInSession() async {
        let session = Session(accessToken: "access", refreshToken: "refresh", username: "reader")
        let store = UnavailableSessionStore(session: session)
        let container = AppContainer(tokenStore: store)
        container.authState = .signedIn(session)

        await container.reconcileAuthStateWithKeychain()

        XCTAssertEqual(container.authState, .signedIn(session))
        let stored = await store.session
        XCTAssertEqual(stored, session)
    }

    func testBootstrapCanRetryAfterKeychainBecomesAvailable() async {
        let store = RecoveringSessionStore()
        let container = AppContainer(tokenStore: store)
        await container.bootstrap()
        let firstAttempts = await store.reads
        XCTAssertEqual(firstAttempts, 2)
        await container.bootstrap()
        let attemptsAfterUnlock = await store.reads
        XCTAssertEqual(attemptsAfterUnlock, 3)
        XCTAssertEqual(container.authState, .signedOut)
        // A successfully read empty store should not trigger repeated restoration.
        await container.bootstrap()
        let attemptsAfterEmptyRead = await store.reads
        XCTAssertEqual(attemptsAfterEmptyRead, 3)
    }
}

private actor UnavailableSessionStore: TokenStore {
    let session: Session
    init(session: Session) { self.session = session }
    func accessToken() async throws -> String? { session.accessToken }
    func loadSession() async throws -> Session? { throw SessionStoreFailure.temporarilyUnavailable }
    func save(session: Session) async throws { XCTFail("Must not replace an inaccessible session") }
    func clear() async throws { XCTFail("Must not clear an inaccessible session") }
    func replaceSession(_ session: Session?, ifMatching expected: Session) async throws -> Bool {
        XCTFail("Must not mutate an inaccessible session")
        return false
    }
}

private enum SessionStoreFailure: Error { case temporarilyUnavailable }

private actor RecoveringSessionStore: TokenStore {
    var reads = 0
    func accessToken() async throws -> String? { nil }
    func loadSession() async throws -> Session? {
        reads += 1
        if reads <= 2 { throw SessionStoreFailure.temporarilyUnavailable }
        return nil
    }
    func save(session: Session) async throws { XCTFail("Must not replace credentials") }
    func clear() async throws { XCTFail("Must not clear credentials") }
    func replaceSession(_ session: Session?, ifMatching expected: Session) async throws -> Bool { false }
}
