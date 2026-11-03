import Foundation
import Combine
import UIKit
import UserNotifications
import EkitapligimCore

/// Manages APNs device token registration, permission requests, and push payload routing.
@MainActor
final class PushNotificationManager: ObservableObject {

    enum ReadTarget: Equatable, Sendable {
        case alert(Int)
        case conversation(Int)
    }

    enum RegistrationStatus: Equatable {
        case idle
        case permissionDenied
        case registering
        case registered
        case failed
    }

    @Published private(set) var registrationStatus: RegistrationStatus = .idle

    private let registerToken: (String) async throws -> Void
    private let unregisterTokenRequest: (String) async throws -> Void
    private let deepLinkParser = DeepLinkParser()
    private var onRoute: ((AppRoute) -> Void)?
    private var onRead: ((ReadTarget) -> Void)?
    private var registeredToken: String?
    private var pendingToken: String?
    private var isRegistering = false
    private var registeringToken: String?
    private var registrationTask: Task<Void, Never>?
    private var unregistrationTask: Task<Void, Never>?
    private var isUnregistering = false
    private var registrationRevision = UUID()
    private var registrationOperationID: UUID?

    init(apiClient: APIClient) {
        self.registerToken = { token in
            let _: SuccessResponse = try await apiClient.request(.registerDeviceToken(token))
        }
        self.unregisterTokenRequest = { token in
            let _: SuccessResponse = try await apiClient.request(.unregisterDeviceToken(token))
        }
    }

    init(
        registerToken: @escaping (String) async throws -> Void,
        unregisterToken: @escaping (String) async throws -> Void = { _ in }
    ) {
        self.registerToken = registerToken
        self.unregisterTokenRequest = unregisterToken
    }

    /// Assigns the deep-link handler called when the user taps a push notification.
    func setRouteHandler(_ handler: @escaping (AppRoute) -> Void) {
        onRoute = handler
    }

    func setReadHandler(_ handler: @escaping (ReadTarget) -> Void) {
        onRead = handler
    }

    // MARK: - Permission & Registration

    /// Requests notification permission and registers for remote notifications.
    func requestPermissionAndRegister() async {
        let revision = registrationRevision
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard revision == registrationRevision, !isUnregistering else { return }
            guard granted else {
                registrationStatus = .permissionDenied
                return
            }
            if registeredToken == nil { registrationStatus = .registering }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            guard revision == registrationRevision else { return }
            registrationStatus = .failed
            #if DEBUG
            print("[Push] Notification authorization failed.")
            #endif
        }
    }

    /// Re-check after returning from iOS Settings without showing another permission prompt.
    func registerIfAuthorized() async {
        let revision = registrationRevision
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard revision == registrationRevision, !isUnregistering else { return }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else { return }
        if registeredToken == nil { registrationStatus = .registering }
        UIApplication.shared.registerForRemoteNotifications()
        await retryPendingRegistration()
    }

    func didFailRemoteRegistration() { registrationStatus = .failed }

    // MARK: - Token Handling

    /// Called by AppDelegate when APNs delivers a device token.
    func didReceiveDeviceToken(_ token: String) async {
        guard !isUnregistering else { return }
        guard token != registeredToken else {
            pendingToken = nil
            registrationStatus = .registered
            return
        }
        pendingToken = token
        await retryPendingRegistration()
    }

    /// Retries a token upload that previously failed without exposing the token in diagnostics.
    func retryPendingRegistration() async {
        guard !isUnregistering else { return }
        let revision = registrationRevision
        if let registrationTask {
            let operation = registrationOperationID
            await registrationTask.value
            guard revision == registrationRevision, !isUnregistering else { return }
            if registrationOperationID == operation {
                self.registrationTask = nil
                registrationOperationID = nil
            }
            guard pendingToken != nil else { return }
            await retryPendingRegistration()
            return
        }
        let operation = UUID()
        let task = Task {
            repeat {
                let attempted = pendingToken
                await performPendingRegistration()
                guard revision == registrationRevision, !isUnregistering, !Task.isCancelled,
                      registrationStatus == .registered, let next = pendingToken, next != attempted else { return }
            } while true
        }
        registrationOperationID = operation
        registrationTask = task
        await task.value
        if registrationOperationID == operation {
            registrationTask = nil
            registrationOperationID = nil
        }
    }

    private func performPendingRegistration() async {
        guard let token = pendingToken,
              token != registeredToken,
              !isRegistering else { return }

        isRegistering = true
        let revision = registrationRevision
        registeringToken = token
        registrationStatus = .registering
        defer {
            if registrationRevision == revision { isRegistering = false; registeringToken = nil }
        }

        do {
            try await registerToken(token)
            guard registrationRevision == revision, !Task.isCancelled else { return }
            let previousToken = registeredToken
            registeredToken = token
            if pendingToken == token {
                pendingToken = nil
            }
            registrationStatus = .registered

            if let previousToken, previousToken != token {
                try? await unregisterTokenRequest(previousToken)
            }
        } catch {
            guard registrationRevision == revision, !Task.isCancelled else { return }
            registrationStatus = .failed
            #if DEBUG
            print("[Push] Token registration failed; it will be retried when the app becomes active.")
            #endif
        }
    }

    /// The server session already ended (expired or revoked), so the backend cannot be
    /// asked to delete the token. Forget it locally: the next sign-in, possibly with
    /// another account, must upload the same APNs token again so the server moves it to
    /// that account instead of keeping the previous owner's notifications on this device.
    func forgetRegistrationAfterSessionLoss() {
        registrationRevision = UUID()
        registrationTask?.cancel()
        registrationTask = nil
        registrationOperationID = nil
        isRegistering = false
        registeringToken = nil
        // APNs hands the same token back after the next sign-in; upload it then.
        pendingToken = nil
        registeredToken = nil
        registrationStatus = .idle
    }

    /// Removes the current device token from the backend (called on logout).
    func unregisterToken() async {
        // Logout must wait for an upload that already started while its bearer
        // remains valid. Otherwise a late upload can restore the old token.
        if let unregistrationTask { await unregistrationTask.value; return }
        isUnregistering = true
        let task = Task { await performTokenRemoval() }
        unregistrationTask = task
        await task.value
        unregistrationTask = nil
        isUnregistering = false
    }

    private func performTokenRemoval() async {
        // A failed upload response may still have committed on the server.
        let attemptedToken = registeringToken ?? pendingToken
        pendingToken = nil
        await registrationTask?.value
        let tokens = Set([registeredToken, attemptedToken].compactMap { $0 })
        registeredToken = nil
        pendingToken = nil
        registrationStatus = .idle
        for token in tokens {
            do {
                try await unregisterTokenRequest(token)
            } catch {
                #if DEBUG
                print("[Push] Token unregister failed.")
                #endif
            }
        }
    }

    // MARK: - Push Payload Handling

    /// Handles a background/silent push by refreshing unread counts.
    func handleBackgroundPush(userInfo: [AnyHashable: Any]) {
        // Background refresh is handled by AppContainer's polling; nothing extra needed.
    }

    /// Routes the user to the appropriate screen when they tap a notification.
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        let route = extractRoute(from: userInfo)
        if let route {
            onRoute?(route)
        }
        if let target = extractReadTarget(from: userInfo) {
            onRead?(target)
        }
    }

    private func extractReadTarget(from userInfo: [AnyHashable: Any]) -> ReadTarget? {
        if let alertID = integerValue(userInfo["alert_id"]), alertID > 0 {
            return .alert(alertID)
        }
        if let conversationID = integerValue(userInfo["conversation_id"]), conversationID > 0 {
            return .conversation(conversationID)
        }
        return nil
    }

    private func integerValue(_ value: Any?) -> Int? {
        (value as? Int) ?? (value as? NSNumber)?.intValue ?? (value as? String).flatMap(Int.init)
    }

    private func extractRoute(from userInfo: [AnyHashable: Any]) -> AppRoute? {
        let appRoute = userInfo["route"] as? String
        let targetURL = userInfo["target_url"] as? String
        let contentID = (userInfo["content_id"] as? Int)
            ?? (userInfo["content_id"] as? String).flatMap(Int.init)
        let type = userInfo["type"] as? String
        let action = userInfo["action"] as? String
        let actorUserID = (userInfo["actor_user_id"] as? Int)
            ?? (userInfo["actor_user_id"] as? String).flatMap(Int.init)

        return deepLinkParser.parseNotification(
            appRoute: appRoute,
            targetURL: targetURL,
            contentID: contentID,
            type: type,
            action: action,
            actorUserID: actorUserID
        )
    }
}
