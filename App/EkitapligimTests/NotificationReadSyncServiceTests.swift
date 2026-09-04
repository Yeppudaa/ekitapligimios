import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class NotificationReadSyncServiceTests: XCTestCase {
    private enum TestError: Error { case temporary }

    func testFailedReadIsRetriedAndClearedAfterSuccess() async throws {
        let suiteName = "NotificationReadSyncServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var attempts = 0
        let counts = try makeCounts(unread: 0, conversationsUnread: 0)
        let service = NotificationReadSyncService(
            defaults: defaults,
            markAlert: { _ in
                attempts += 1
                if attempts == 1 { throw TestError.temporary }
                return counts
            },
            markConversation: { _ in counts },
            markAllAlerts: { counts }
        )

        do {
            try await service.markAlertRead(44)
            XCTFail("The first request must fail")
        } catch TestError.temporary {
        }
        XCTAssertEqual(service.pendingCount, 1)

        await service.retryPending()
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(service.pendingCount, 0)
    }

    func testSuccessfulConversationReadPublishesAuthoritativeCounts() async throws {
        let suiteName = "NotificationReadSyncServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let counts = try makeCounts(unread: 2, conversationsUnread: 1)
        let service = NotificationReadSyncService(
            defaults: defaults,
            markAlert: { _ in counts },
            markConversation: { _ in counts },
            markAllAlerts: { counts }
        )
        var received: NotificationCountsDTO?
        service.countsDidChange = { received = $0 }

        try await service.markConversationRead(9)

        XCTAssertEqual(received?.unread, 2)
        XCTAssertEqual(received?.conversationsUnread, 1)
        XCTAssertEqual(service.pendingCount, 0)
    }

    private func makeCounts(unread: Int, conversationsUnread: Int) throws -> NotificationCountsDTO {
        let data = Data("{\"unread\":\(unread),\"unviewed\":0,\"conversations_unread\":\(conversationsUnread)}".utf8)
        return try JSONDecoder.ekitapligim.decode(NotificationCountsDTO.self, from: data)
    }
}
