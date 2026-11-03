import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class AudioPageRoutingTests: XCTestCase {
    func testAudioPagesPushFromTheirOriginInsteadOfOpeningASheet() async {
        let container = makeContainer()
        let origins: [(AppTab, AppRoute)] = [
            (.home, .audiobooks),
            (.catalog, .audiobook(101)),
            (.profile, .audioLibrary(tab: "saved"))
        ]
        for (tab, route) in origins {
            container.selectedTab = tab
            container.presentedRoute = .bookDetail(42)

            container.open(route: route)

            XCTAssertEqual(container.audioPageRoute, route)
            XCTAssertNil(container.presentedRoute, "An audio page must replace any old sheet presentation")
            XCTAssertEqual(container.selectedTab, tab, "Back must return to the tab that opened the audio page")
            XCTAssertFalse(container.isForumPresented)
        }
    }

    func testOpeningAudioFromForumPreservesForumAsTheBackDestination() async {
        let container = makeContainer()
        container.selectedTab = .requests
        container.open(route: .forum)

        container.open(route: .audiobooks)

        XCTAssertTrue(container.isForumPresented)
        XCTAssertEqual(container.selectedTab, .requests)
        XCTAssertEqual(container.audioPageRoute, .audiobooks)
        XCTAssertNil(container.presentedRoute)

        container.audioPageRoute = nil

        XCTAssertTrue(container.isForumPresented, "Popping audio must reveal the original forum page")
        XCTAssertEqual(container.selectedTab, .requests)
    }

    func testTopLevelRoutesClearAudioNavigation() async {
        let container = makeContainer()
        let destinations: [AppRoute] = [
            .home, .catalog, .bookAgenda, .liveActivity, .requests, .profile,
            .library(tab: 3), .forum
        ]
        for destination in destinations {
            container.open(route: .audiobooks)
            XCTAssertNotNil(container.audioPageRoute)

            container.open(route: destination)

            XCTAssertNil(container.audioPageRoute, "Top-level navigation must leave audio: \(destination)")
            XCTAssertNil(container.presentedRoute)
        }
    }

    func testBottomTabSelectionClearsAudioNavigation() async {
        let container = makeContainer()
        for tab in AppTab.allCases {
            container.open(route: .audioLibrary(tab: "saved"))

            container.selectedTab = tab

            XCTAssertNil(container.audioPageRoute, "Bottom-bar selection must not reopen an old audio page")
            XCTAssertFalse(container.isForumPresented)
            XCTAssertEqual(container.selectedTab, tab)
        }
    }

    func testNativeBackKeepsTheOriginTab() async {
        let container = makeContainer()
        container.selectedTab = .profile
        container.open(route: .audioLibrary(tab: "saved"))

        // SwiftUI writes nil to the item binding when the native Back action pops the page.
        container.audioPageRoute = nil

        XCTAssertEqual(container.selectedTab, .profile)
        XCTAssertNil(container.presentedRoute)
        XCTAssertFalse(container.isForumPresented)
    }

    func testLoginPremiumAndPlayerPresentationsPreserveTheAudioPage() async {
        let container = makeContainer()
        container.selectedTab = .home
        container.open(route: .audiobook(101))

        for sheet in [AppRoute.login, .register, .premium, .audioPlayer] {
            container.open(route: sheet)

            XCTAssertEqual(container.presentedRoute, sheet)
            XCTAssertEqual(container.audioPageRoute, .audiobook(101))
            XCTAssertEqual(container.selectedTab, .home)

            container.presentedRoute = nil

            XCTAssertEqual(container.audioPageRoute, .audiobook(101), "Closing a secondary presentation must reveal the same audio page")
        }
    }

    private func makeContainer() -> AppContainer {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AudioRoutingNoNetworkProtocol.self]
        return AppContainer(apiSession: URLSession(configuration: configuration), tokenStore: AudioRoutingTokenStore())
    }
}

private actor AudioRoutingTokenStore: TokenStore {
    func accessToken() async throws -> String? { nil }
    func loadSession() async throws -> Session? { nil }
    func save(session: Session) async throws { XCTFail("Routing must not write credentials") }
    func clear() async throws { XCTFail("Routing must not clear credentials") }
    func replaceSession(_ session: Session?, ifMatching expected: Session) async throws -> Bool {
        XCTFail("Routing must not replace credentials")
        return false
    }
}

private final class AudioRoutingNoNetworkProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTFail("Opening a route must not perform a network request")
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}
