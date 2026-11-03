import SwiftUI
import EkitapligimCore

@MainActor
struct PushRegistrationStatusView: View {
    @ObservedObject var manager: PushNotificationManager
    let allowsRegistration: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CommunityDesignL10n.text(key)).font(.caption).foregroundStyle(CommunityStyle.muted)
                .accessibilityIdentifier("notifications.delivery.registration")
            if allowsRegistration && (manager.registrationStatus == .failed || manager.registrationStatus == .idle) {
                Button {
                    Task { await manager.registerIfAuthorized() }
                } label: {
                    Label(CommunityDesignL10n.text("notifications.retryRegistration"), systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold)).frame(minHeight: 44)
                }.buttonStyle(.plain).foregroundStyle(CommunityStyle.teal)
            }
        }
    }
    private var key: String {
        switch manager.registrationStatus {
        case .registered: "notifications.registered"
        case .registering: "notifications.registering"
        case .failed: "notifications.registrationFailed"
        case .idle: "notifications.registrationPending"
        case .permissionDenied: "notifications.registrationDenied"
        }
    }
}
