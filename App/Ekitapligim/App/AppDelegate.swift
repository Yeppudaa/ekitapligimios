import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    @MainActor weak var pushManager: PushNotificationManager? {
        didSet { if notificationStartupComplete { completeNotificationStartup() } }
    }
    @MainActor private var pendingNotificationTap: [AnyHashable: Any]?
    @MainActor private var notificationStartupComplete = false

    @MainActor func completeNotificationStartup() {
        notificationStartupComplete = true
        if let payload = pendingNotificationTap, let pushManager {
            pendingNotificationTap = nil
            pushManager.handleNotificationTap(userInfo: payload)
        }
    }

    @MainActor func routeNotificationTap(_ payload: [AnyHashable: Any]) {
        guard notificationStartupComplete, let pushManager else {
            pendingNotificationTap = payload
            return
        }
        pushManager.handleNotificationTap(userInfo: payload)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Remote Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            await pushManager?.didReceiveDeviceToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in pushManager?.didFailRemoteRegistration() }
        #if DEBUG
        print("[Push] Remote notification registration failed.")
        #endif
    }

    // MARK: - Silent / Background Push

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            pushManager?.handleBackgroundPush(userInfo: userInfo)
            completionHandler(.newData)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification arrives while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .badge, .sound])
    }

    /// Called when the user taps a notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            routeNotificationTap(userInfo)
        }
        completionHandler()
    }
}
