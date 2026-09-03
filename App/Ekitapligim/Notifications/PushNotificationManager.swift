import Foundation
import UIKit
import UserNotifications
import EkitapligimCore

/// Manages APNs device token registration, permission requests, and push payload routing.
@MainActor
final class PushNotificationManager: ObservableObject {

    private let apiClient: APIClient
    private let deepLinkParser = DeepLinkParser()
    private var onRoute: ((AppRoute) -> Void)?
    private var currentToken: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Assigns the deep-link handler called when the user taps a push notification.
    func setRouteHandler(_ handler: @escaping (AppRoute) -> Void) {
        onRoute = handler
    }

    // MARK: - Permission & Registration

    /// Requests notification permission and registers for remote notifications.
    func requestPermissionAndRegister() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            #if DEBUG
            print("[Push] Authorization error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Token Handling

    /// Called by AppDelegate when APNs delivers a device token.
    func didReceiveDeviceToken(_ token: String) {
        guard token != currentToken else { return }
        currentToken = token
        Task { await sendTokenToBackend(token) }
    }

    /// Sends the device token to the backend for storage.
    private func sendTokenToBackend(_ token: String) async {
        do {
            let _: SuccessResponse = try await apiClient.request(
                .registerDeviceToken(token)
            )
        } catch {
            #if DEBUG
            print("[Push] Token registration failed: \(error)")
            #endif
        }
    }

    /// Removes the current device token from the backend (called on logout).
    func unregisterToken() async {
        guard let token = currentToken else { return }
        currentToken = nil
        do {
            let _: SuccessResponse = try await apiClient.request(
                .unregisterDeviceToken(token)
            )
        } catch {
            #if DEBUG
            print("[Push] Token unregister failed: \(error)")
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
