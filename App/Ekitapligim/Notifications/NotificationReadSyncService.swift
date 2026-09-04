import Foundation
import EkitapligimCore

@MainActor
final class NotificationReadSyncService {
    enum Target: Codable, Hashable, Sendable {
        case alert(Int)
        case conversation(Int)
        case allAlerts
    }

    var countsDidChange: ((NotificationCountsDTO) -> Void)?

    private let markAlertRequest: (Int) async throws -> NotificationCountsDTO
    private let markConversationRequest: (Int) async throws -> NotificationCountsDTO
    private let markAllAlertsRequest: () async throws -> NotificationCountsDTO
    private let defaults: UserDefaults
    private let storageKey = "ekitapligim.pendingNotificationReads"
    private var pending: Set<Target>
    var pendingCount: Int { pending.count }

    init(repository: NotificationsRepository, defaults: UserDefaults = .standard) {
        self.markAlertRequest = { try await repository.markRead(id: $0) }
        self.markConversationRequest = { try await repository.markConversationRead(id: $0) }
        self.markAllAlertsRequest = { try await repository.markAllRead() }
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(Set<Target>.self, from: data) {
            pending = stored
        } else {
            pending = []
        }
    }

    init(
        defaults: UserDefaults,
        markAlert: @escaping (Int) async throws -> NotificationCountsDTO,
        markConversation: @escaping (Int) async throws -> NotificationCountsDTO,
        markAllAlerts: @escaping () async throws -> NotificationCountsDTO
    ) {
        self.markAlertRequest = markAlert
        self.markConversationRequest = markConversation
        self.markAllAlertsRequest = markAllAlerts
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(Set<Target>.self, from: data) {
            pending = stored
        } else {
            pending = []
        }
    }

    func markAlertRead(_ id: Int) async throws {
        guard id > 0 else { return }
        try await acknowledge(.alert(id))
    }

    func markConversationRead(_ id: Int) async throws {
        guard id > 0 else { return }
        try await acknowledge(.conversation(id))
    }

    func markAllAlertsRead() async throws {
        try await acknowledge(.allAlerts)
    }

    func retryPending() async {
        for target in pending {
            try? await acknowledge(target)
        }
    }

    func clear() {
        pending.removeAll()
        persist()
    }

    private func acknowledge(_ target: Target) async throws {
        pending.insert(target)
        persist()

        let counts: NotificationCountsDTO
        switch target {
        case .alert(let id):
            counts = try await markAlertRequest(id)
        case .conversation(let id):
            counts = try await markConversationRequest(id)
        case .allAlerts:
            counts = try await markAllAlertsRequest()
        }

        if target == .allAlerts {
            pending = pending.filter {
                if case .alert = $0 { return false }
                return true
            }
        }
        pending.remove(target)
        persist()
        countsDidChange?(counts)
    }

    private func persist() {
        guard !pending.isEmpty else {
            defaults.removeObject(forKey: storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
