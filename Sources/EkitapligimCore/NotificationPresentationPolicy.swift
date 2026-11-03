import Foundation

public enum NotificationPresentationPolicy {
    /// Permission to deliver to Notification Center alone does not enable a popup.
    /// Provisional/ephemeral authorization must not be reported as full banner authorization.
    public static func bannersEnabled(fullyAuthorized: Bool, alertsEnabled: Bool, bannerStyleEnabled: Bool) -> Bool {
        fullyAuthorized && alertsEnabled && bannerStyleEnabled
    }
}
