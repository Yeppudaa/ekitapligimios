import Foundation
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
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                registrationStatus = .permissionDenied
                return
            }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            registrationStatus = .failed
            #if DEBUG
            print("[Push] Authorization error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Token Handling

    /// Called by AppDelegate when APNs delivers a device token.
    func didReceiveDeviceToken(_ token: String) async {
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
        guard let token = pendingToken,
              token != registeredToken,
              !isRegistering else { return }

        isRegistering = true
        registrationStatus = .registering
        defer { isRegistering = false }

        do {
            try await registerToken(token)
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
            registrationStatus = .failed
            #if DEBUG
            print("[Push] Token registration failed; it will be retried when the app becomes active.")
            #endif
        }
    }

    /// Removes the current device token from the backend (called on logout).
    func unregisterToken() async {
        guard let token = registeredToken else {
            pendingToken = nil
            registrationStatus = .idle
            return
        }
        registeredToken = nil
        pendingToken = nil
        registrationStatus = .idle
        do {
            try await unregisterTokenRequest(token)
        } catch {
            #if DEBUG
            print("[Push] Token unregister failed.")
            #endif
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
