import SwiftUI
import EkitapligimCore
import UserNotifications
import UIKit

@MainActor
struct NotificationsView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var notifications: [NotificationDTO] = []
    @State private var counts: NotificationCountsDTO?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var navigationError: String?
    @State private var optimisticallyReadIDs: Set<Int> = []
    @State private var deliverySettings: UNNotificationSettings?
    @State private var requestingPermission = false

    var body: some View {
        EKitapligimScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    notificationBanner
                    deliveryCard
                    headerActions
                    if let counts { notificationCountsCard(counts) }
                    if isLoading && notifications.isEmpty {
                        EKLoadingState(message: L10n.notificationsLoading)
                    } else if let errorMessage, notifications.isEmpty {
                        EKErrorState(title: L10n.notificationsUnavailableTitle, message: errorMessage) {
                            Task { await load() }
                        }
                    } else if notifications.isEmpty {
                        EKEmptyState(title: L10n.notificationsEmptyTitle,
                            message: CommunityRefreshL10n.text("notifications.emptyBody"), systemImage: "bell")
                    } else {
                        if let errorMessage { EKInlineError(message: errorMessage) }
                        ForEach(notifications) { item in
                            NotificationRow(notification: item,
                                isRead: item.isRead == true || Int(item.id).map(optimisticallyReadIDs.contains) == true) {
                                await open(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .frame(maxWidth: 850).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("notifications.list")
        }
        .navigationTitle(L10n.notificationsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.notificationsUnavailableTitle, isPresented: Binding(
            get: { navigationError != nil },
            set: { if !$0 { navigationError = nil } }
        )) {
            Button(L10n.commonClose) { navigationError = nil }
        } message: { Text(navigationError ?? "") }
        .task { await readDeliverySettings(); await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await readDeliverySettings() } }
        }
        .refreshable { await readDeliverySettings(); await load() }
    }

    private var notificationBanner: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: "bell.badge.fill").font(.title2).foregroundStyle(Color(hex: 0xFFF3CC))
                .frame(width: 52, height: 52).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.notificationsTitle).font(.system(.title, design: .serif).weight(.bold))
                    .foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                Text((counts?.unread ?? container.unreadNotifications) > 0
                    ? CommunityRefreshL10n.count("notifications.unreadCount", counts?.unread ?? container.unreadNotifications)
                    : CommunityRefreshL10n.text("notifications.synchronized"))
                    .font(.subheadline).foregroundStyle(Color(hex: 0xD4E7E1))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0x113D46), Color(hex: 0x17636B), Color(hex: 0x33897D)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 23))
    }

    private var headerActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { refreshButton; Spacer(minLength: 0); readAllButton }
            VStack(alignment: .leading, spacing: 8) { refreshButton; readAllButton }
        }
    }
    private var refreshButton: some View {
        Button { Task { await readDeliverySettings(); await load() } } label: {
            Label(L10n.commonRefresh, systemImage: "arrow.clockwise").font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).frame(minHeight: 48)
        }.buttonStyle(.bordered).tint(EKitapligimPalette.teal).disabled(isLoading)
    }
    private var readAllButton: some View {
        Button { Task { await markAllRead() } } label: {
            Label(L10n.notificationsMarkAllRead, systemImage: "checkmark.circle")
                .font(.subheadline.weight(.semibold)).padding(.horizontal, 10).frame(minHeight: 48)
        }.buttonStyle(.bordered).tint(EKitapligimPalette.teal)
            .disabled(notifications.isEmpty || isLoading)
    }

    private func notificationCountsCard(_ counts: NotificationCountsDTO) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            countTile(L10n.notificationsUnread, value: counts.unread, icon: "envelope.badge", tint: EKitapligimPalette.teal)
            countTile(L10n.notificationsNew, value: counts.unviewed ?? 0, icon: "sparkles", tint: EKitapligimPalette.amber)
        }
    }
    private func countTile(_ title: String, value: Int, icon: String, tint: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).foregroundStyle(tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(value)).font(.title3.weight(.bold)).foregroundStyle(EKitapligimPalette.ink)
                Text(title).font(.caption).foregroundStyle(EKitapligimPalette.muted)
            }
            Spacer(minLength: 0)
        }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(EKitapligimPalette.border))
    }

    private var deliveryCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(deliveryTitle, systemImage: deliveryEnabled ? "bell.badge" : "bell.slash")
                .font(.headline).foregroundStyle(EKitapligimPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(deliveryMessage).font(.subheadline).foregroundStyle(Color(hex: 0x526B70))
                .fixedSize(horizontal: false, vertical: true)
            if deliverySettings?.authorizationStatus == .notDetermined {
                Button {
                    Task { await requestNotificationPermission() }
                } label: {
                    HStack(spacing: 8) {
                        if requestingPermission { ProgressView() }
                        Label(CommunityRefreshL10n.text("notifications.permissionAction"), systemImage: "bell.badge")
                    }
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent).tint(EKitapligimPalette.teal)
                .disabled(requestingPermission)
                .accessibilityIdentifier("notifications.delivery.request")
            }
            Button(action: openNotificationSettings) {
                Label(CommunityRefreshL10n.text("notifications.settingsAction"), systemImage: "gearshape")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(.bordered).tint(EKitapligimPalette.teal)
                .accessibilityIdentifier("notifications.delivery.settings")
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(deliveryEnabled ? Color(hex: 0xF0F8F6) : Color(hex: 0xFFF8E9), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(deliveryEnabled ? Color(hex: 0xD0E5DF) : Color(hex: 0xEBD8AA)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notifications.delivery.status")
    }

    private var deliveryEnabled: Bool {
        guard let settings = deliverySettings else { return false }
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral
    }
    private var visibleAlertsDisabled: Bool {
        guard let settings = deliverySettings, deliveryEnabled else { return false }
        return settings.alertSetting == .disabled && settings.notificationCenterSetting == .disabled && settings.lockScreenSetting == .disabled
    }
    private var deliveryTitle: String {
        guard let status = deliverySettings?.authorizationStatus else { return CommunityRefreshL10n.text("notifications.checking") }
        switch status {
        case .notDetermined: return CommunityRefreshL10n.text("notifications.notAskedTitle")
        case .denied: return CommunityRefreshL10n.text("notifications.disabledTitle")
        case .provisional, .ephemeral: return CommunityRefreshL10n.text("notifications.quietTitle")
        case .authorized: return CommunityRefreshL10n.text(visibleAlertsDisabled ? "notifications.surfacesDisabledTitle" : "notifications.enabledTitle")
        @unknown default: return CommunityRefreshL10n.text("notifications.settingsAction")
        }
    }
    private var deliveryMessage: String {
        guard let status = deliverySettings?.authorizationStatus else { return CommunityRefreshL10n.text("notifications.checkingBody") }
        switch status {
        case .notDetermined: return CommunityRefreshL10n.text("notifications.notAskedBody")
        case .denied: return CommunityRefreshL10n.text("notifications.disabledBody")
        case .provisional, .ephemeral: return CommunityRefreshL10n.text("notifications.quietBody")
        case .authorized: return CommunityRefreshL10n.text(visibleAlertsDisabled ? "notifications.surfacesDisabledBody" : "notifications.enabledBody")
        @unknown default: return CommunityRefreshL10n.text("notifications.unknownBody")
        }
    }

    /// Reading the current permission never requests it, registers push, or changes user settings.
    private func readDeliverySettings() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard !Task.isCancelled else { return }
        deliverySettings = settings
    }
    private func requestNotificationPermission() async {
        guard !requestingPermission, deliverySettings?.authorizationStatus == .notDetermined else { return }
        requestingPermission = true
        defer { requestingPermission = false }
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await readDeliverySettings()
        } catch { navigationError = CommunityRefreshL10n.text("notifications.permissionFailed") }
    }
    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        openURL(url)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await container.notifications.notifications()
            notifications = page.items
            counts = page.counts
            errorMessage = nil
            await container.refreshUnreadCounts()
        } catch {
            errorMessage = L10n.notificationsLoadFailed
        }
    }

    @MainActor
    private func open(_ notification: NotificationDTO) async {
        if notification.isRead != true, let id = Int(notification.id) {
            optimisticallyReadIDs.insert(id)
            do {
                try await container.notificationReadSync.markAlertRead(id)
            } catch {
                navigationError = L10n.notificationsReadSyncFailed
            }
        }

        guard let route = DeepLinkParser().parseNotification(
            appRoute: notification.appRoute,
            targetURL: notification.targetUrl,
            contentID: notification.contentId,
            type: notification.type,
            action: notification.action,
            actorUserID: notification.actorUserId
        ) else {
            navigationError = L10n.notificationsNoDestination
            return
        }

        container.open(route: route)
    }

    private func markAllRead() async {
        do {
            try await container.notificationReadSync.markAllAlertsRead()
            optimisticallyReadIDs.formUnion(notifications.compactMap { Int($0.id) })
            await load()
        } catch {
            navigationError = L10n.notificationsReadSyncFailed
        }
    }

}

@MainActor
private struct NotificationRow: View {
    let notification: NotificationDTO
    let isRead: Bool
    let markRead: () async -> Void

    var body: some View {
        Button { Task { await markRead() } } label: {
            HStack(alignment: .top, spacing: 12) {
                if !isRead {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xE0A02B)).frame(width: 3, height: 58)
                        .accessibilityHidden(true)
                }
                Image(systemName: notification.action == "profile_visit" || notification.type == "profile_visit" ? "person.crop.circle" : "bell.badge")
                    .font(.title3).foregroundStyle(EKitapligimPalette.teal)
                    .frame(width: 40, height: 40)
                    .background(isRead ? Color(hex: 0xEFF8FA) : .white, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(notification.title).font(.subheadline.weight(isRead ? .semibold : .bold))
                            .foregroundStyle(isRead ? EKitapligimPalette.ink : Color(hex: 0x7A5205))
                            .fixedSize(horizontal: false, vertical: true)
                        if !isRead {
                            Circle().fill(EKitapligimPalette.teal).frame(width: 7, height: 7)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(EKitapligimFormat.plainText(notification.message))
                        .font(.subheadline).foregroundStyle(isRead ? Color(hex: 0x4C5A68) : Color(hex: 0x25313D))
                        .fixedSize(horizontal: false, vertical: true)
                    if let actor = notification.actorUsername, !actor.isEmpty {
                        Text(actor).font(.caption.weight(.semibold)).foregroundStyle(EKitapligimPalette.teal)
                    }
                    if let date = notification.eventDate, date > 0 {
                        Text(EKitapligimFormat.relativeTime(date)).font(.caption2).foregroundStyle(EKitapligimPalette.muted)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(15).frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .background(isRead ? .white : Color(hex: 0xFFFBF2), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(isRead ? EKitapligimPalette.border : Color(hex: 0xF1D89A)))
            .contentShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .accessibilityValue(isRead ? CommunityRefreshL10n.text("notifications.readState") : L10n.notificationsUnread)
        .accessibilityIdentifier("notification-\(notification.id)")
    }
}
