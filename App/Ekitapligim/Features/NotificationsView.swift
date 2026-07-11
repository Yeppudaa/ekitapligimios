import SwiftUI
import EkitapligimCore

struct NotificationsView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var notifications: [NotificationDTO] = []
    @State private var counts: NotificationCountsDTO?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var navigationError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(L10n.notificationsLoading)
            } else if let errorMessage {
                ContentUnavailableView(L10n.notificationsUnavailableTitle, systemImage: "bell.badge", description: Text(errorMessage))
            } else if notifications.isEmpty {
                ContentUnavailableView(L10n.notificationsEmptyTitle, systemImage: "bell")
            } else {
                List {
                    if let counts {
                        Section {
                            LabeledContent(L10n.notificationsUnread, value: String(counts.unread))
                            LabeledContent(L10n.notificationsNew, value: String(counts.unviewed ?? 0))
                        }
                    }
                    Section {
                        ForEach(notifications) { item in
                            NotificationRow(notification: item) {
                                await open(item)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.notificationsTitle)
        .alert(L10n.notificationsUnavailableTitle, isPresented: Binding(
            get: { navigationError != nil },
            set: { if !$0 { navigationError = nil } }
        )) {
            Button(L10n.commonClose) { navigationError = nil }
        } message: {
            Text(navigationError ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.notificationsMarkAllRead) {
                    Task { await markAllRead() }
                }
                .disabled(notifications.isEmpty)
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await container.notifications.notifications()
            notifications = page.items
            counts = page.counts
        } catch {
            errorMessage = L10n.notificationsLoadFailed
        }
    }

    @MainActor
    private func open(_ notification: NotificationDTO) async {
        if notification.isRead != true, let id = Int(notification.id) {
            try? await container.notifications.markRead(id: id)
            await load()
        }

        guard let route = DeepLinkParser().parseNotification(
            appRoute: notification.appRoute,
            targetURL: notification.targetUrl,
            contentID: notification.contentId,
            type: notification.type
        ) else {
            navigationError = L10n.notificationsNoDestination
            return
        }

        container.open(route: route)
    }

    private func markAllRead() async {
        try? await container.notifications.markAllRead()
        await load()
    }

}

private struct NotificationRow: View {
    let notification: NotificationDTO
    let markRead: () async -> Void

    var body: some View {
        Button {
            Task { await markRead() }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.title)
                        .font(.headline)
                    if notification.isRead != true {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .accessibilityLabel(L10n.notificationsUnread)
                    }
                }
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let actor = notification.actorUsername, !actor.isEmpty {
                    Text(actor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
