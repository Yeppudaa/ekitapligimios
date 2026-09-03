import SwiftUI
import UIKit
import EkitapligimCore

@MainActor
struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var isMenuPresented = false

    init() {
        EKitapligimAppearance.configure()
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 251 / 255, green: 254 / 255, blue: 254 / 255, alpha: 1)
        appearance.shadowColor = UIColor(red: 226 / 255, green: 232 / 255, blue: 234 / 255, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            tabs
            if container.selectedTab != .catalog {
                menuButton
            }
            drawer
        }
        .onOpenURL { url in
            if GoogleSignInService.handle(url) { return }
            guard let route = DeepLinkParser().parse(url.absoluteString) else { return }
            container.open(route: route)
        }
        .onAppear { GoogleSignInService.configureIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { container.handleScenePhaseActive() }
            if phase == .background { container.handleScenePhaseBackground() }
        }
        .sheet(item: $container.presentedRoute) { route in
            AppRouteSheet(route: route)
        }
    }

    private var tabs: some View {
        VStack(spacing: 0) {
            Group {
                switch container.selectedTab {
                case .home:
                    HomeView()
                case .catalog:
                    CatalogView(onOpenMenu: openMenu)
                case .agenda:
                    NavigationStack { BookAgendaView() }
                case .flow:
                    NavigationStack { LiveActivityView() }
                case .requests:
                    NavigationStack { BookRequestsView() }
                case .profile:
                    NavigationStack { ProfileView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PrimaryTabBar(
                selection: $container.selectedTab,
                profileBadgeCount: container.totalUnread
            )
        }
        .tint(EKitapligimPalette.teal)
    }

    private var menuButton: some View {
        Button(action: openMenu) {
            Image(systemName: "line.3.horizontal")
                .accessibilityHidden(true)
                .font(.title3.weight(.semibold))
                .foregroundStyle(EKitapligimPalette.ink)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(EKitapligimPalette.border) }
                .overlay(alignment: .topTrailing) {
                    if container.totalUnread > 0 {
                        Circle()
                            .fill(EKitapligimPalette.amber)
                            .frame(width: 9, height: 9)
                            .offset(x: 3, y: -3)
                    }
                }
        }
        .accessibilityLabel(L10n.menuTitle)
        .padding(.top, 8)
        .padding(.trailing, 12)
    }

    private func openMenu() {
        withAnimation(.easeOut(duration: 0.2)) { isMenuPresented = true }
    }

    @ViewBuilder private var drawer: some View {
        if isMenuPresented {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { closeMenu() }
                .transition(.opacity)
                .zIndex(1)

            HStack(spacing: 0) {
                AppSideMenu(onSelect: navigate, onClose: closeMenu)
                    .frame(maxWidth: 356)
                Spacer(minLength: 0)
            }
            .transition(.move(edge: .leading))
            .zIndex(2)
        }
    }

    private func navigate(to route: AppRoute) {
        closeMenu()
        container.open(route: route)
    }

    private func closeMenu() {
        withAnimation(.easeIn(duration: 0.18)) { isMenuPresented = false }
    }
}

// MARK: - Yan menü

@MainActor
private struct AppSideMenu: View {
    @EnvironmentObject private var container: AppContainer
    let onSelect: (AppRoute) -> Void
    let onClose: () -> Void

    private var primaryItems: [AppMenuItem] {
        [
            AppMenuItem(route: .home, title: L10n.menuHome, subtitle: L10n.menuHomeSubtitle, icon: "house.fill"),
            AppMenuItem(route: .catalog, title: L10n.menuBooks, subtitle: L10n.menuBooksSubtitle, icon: "books.vertical.fill"),
            AppMenuItem(route: .bookAgenda, title: L10n.menuBookAgenda, subtitle: L10n.menuBookAgendaSubtitle, icon: "text.book.closed.fill"),
            AppMenuItem(route: .chat, title: L10n.menuChat, subtitle: L10n.menuChatSubtitle, icon: "bubble.left.and.text.bubble.right.fill"),
            AppMenuItem(route: .liveActivity, title: L10n.menuLiveActivity, subtitle: L10n.menuLiveActivitySubtitle, icon: "bolt.fill"),
            AppMenuItem(route: .requests, title: L10n.menuRequests, subtitle: L10n.menuRequestsSubtitle, icon: "heart.fill"),
            AppMenuItem(route: .authors, title: L10n.menuAuthors, subtitle: L10n.menuAuthorsSubtitle, icon: "person.2.fill"),
            AppMenuItem(route: .publishers, title: L10n.menuPublishers, subtitle: L10n.menuPublishersSubtitle, icon: "building.2.fill"),
            AppMenuItem(route: .forum, title: L10n.menuForum, subtitle: L10n.menuForumSubtitle, icon: "bubble.left.and.bubble.right.fill"),
            AppMenuItem(route: .members, title: L10n.menuMembers, subtitle: L10n.menuMembersSubtitle, icon: "person.3.fill"),
            AppMenuItem(
                route: .messages,
                title: L10n.menuMessages,
                subtitle: L10n.menuMessagesSubtitle,
                icon: "envelope.fill",
                badgeCount: container.unreadMessages
            )
        ]
    }

    private var accountItems: [AppMenuItem] {
        guard container.isSignedIn else {
            return [
                AppMenuItem(route: .login, title: L10n.commonLogin, subtitle: L10n.menuLoginSubtitle, icon: "arrow.right.square.fill"),
                AppMenuItem(route: .register, title: L10n.menuRegister, subtitle: L10n.menuRegisterSubtitle, icon: "person.badge.plus.fill")
            ]
        }
        return [
            AppMenuItem(
                route: .profile,
                title: L10n.menuProfile,
                subtitle: L10n.menuProfileSubtitle,
                icon: "person.crop.circle.fill",
                badgeCount: container.totalUnread
            ),
            AppMenuItem(
                route: .notifications,
                title: L10n.menuNotifications,
                subtitle: L10n.menuNotificationsSubtitle,
                icon: "bell.fill",
                badgeCount: container.unreadNotifications
            ),
            AppMenuItem(route: .library(tab: 0), title: L10n.menuLibrary, subtitle: L10n.menuLibrarySubtitle, icon: "books.vertical.circle.fill")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(primaryItems) { item in
                        menuRow(item)
                    }

                    premiumCard
                        .padding(.top, 10)

                    Text(container.isSignedIn ? L10n.menuAccountSection : L10n.menuMembershipSection)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.muted)
                        .padding(.horizontal, 10)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    ForEach(accountItems) { item in
                        menuRow(item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 28)
            }
        }
        .frame(maxHeight: .infinity)
        .background(EKitapligimPalette.pageGradient)
        .ignoresSafeArea(edges: .bottom)
    }

    private var header: some View {
        HStack(spacing: 12) {
            EKitapligimBrandLogo().frame(width: 112, height: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.menuBrandTitle)
                    .font(.headline)
                    .foregroundStyle(EKitapligimPalette.ink)
                Text(L10n.menuSubtitle)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(EKitapligimPalette.muted)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(L10n.menuClose)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func menuRow(_ item: AppMenuItem) -> some View {
        Button { onSelect(item.route) } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .accessibilityHidden(true)
                    .foregroundStyle(EKitapligimPalette.teal)
                    .frame(width: 38, height: 38)
                    .background(EKitapligimPalette.tealSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.ink)
                    Text(item.subtitle)
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                EKUnreadBadge(count: item.badgeCount)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            item.badgeCount > 0 ? "\(item.title), \(L10n.unreadCountAccessibility(item.badgeCount))" : item.title
        )
    }

    private var premiumCard: some View {
        Button { onSelect(.premium) } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .accessibilityHidden(true)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.premiumTitle)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(L10n.menuPremiumSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EKitapligimPalette.quotaPremiumGradient)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.premiumTitle)
    }
}

private struct AppMenuItem: Identifiable {
    let route: AppRoute
    let title: String
    let subtitle: String
    let icon: String
    var badgeCount: Int = 0

    var id: String { "\(route.nativeRoute)-\(title)" }
}

// MARK: - Route sunumu

@MainActor
private struct AppRouteSheet: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    let route: AppRoute

    var body: some View {
        NavigationStack {
            destination
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.commonClose) { dismiss() }
                    }
                }
        }
        .tint(EKitapligimPalette.teal)
    }

    @ViewBuilder private var destination: some View {
        if route.requiresAuthentication && !container.isSignedIn {
            LoginRequiredView()
        } else {
            routeDestination
        }
    }

    @ViewBuilder private var routeDestination: some View {
        switch route {
        case .forum:
            CommunityView()
        case .home, .requests, .profile, .catalog, .bookAgenda, .liveActivity:
            EKEmptyState(
                title: L10n.commonClose,
                message: L10n.menuTitle,
                systemImage: "arrow.left"
            )
        case .catalog:
            CatalogView()
        case .authors:
            DirectoryView(kind: .author)
        case .login:
            LoginView(initialMode: .login)
        case .register:
            LoginView(initialMode: .register)
        case .bookDetail(let id):
            BookDetailView(bookID: id)
        case .reader(let id):
            ReaderLoaderView(bookID: id)
        case .forumDetail(let id):
            ForumThreadsView(forum: ForumDTO(id: String(id), title: L10n.communityForumsSection))
        case .thread(let id):
            ForumThreadDetailView(thread: ForumThreadDTO(id: String(id), title: L10n.myCommentsForumTitle, username: ""))
        case .publishers:
            DirectoryView(kind: .publisher)
        case .bookAgenda:
            BookAgendaView()
        case .bookAgendaPost(let id):
            BookAgendaDetailView(postID: String(id))
        case .chat:
            ChatView()
        case .chatRoom(let id):
            ChatView(initialRoomID: String(id))
        case .liveActivity:
            LiveActivityView()
        case .members:
            MembersView()
        case .member(let id):
            MemberProfileView(memberID: String(id))
        case .messages:
            ConversationsView()
        case .conversation(let id):
            ConversationDetailView(conversationID: String(id))
        case .notifications:
            NotificationsView()
        case .profileEdit:
            ProfileEditView()
        case .library(let tab):
            LibraryView(initialTab: LibraryTab(index: tab))
        case .stats:
            StatsView()
        case .myComments:
            MyCommentsView()
        case .premium:
            PremiumView()
        }
    }
}

@MainActor
private struct LoginRequiredView: View {
    @State private var showingLogin = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(EKitapligimPalette.teal)
            Text(L10n.bookCommentsLoginRequiredTitle)
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.ink)
            Text(L10n.menuLoginSubtitle)
                .font(.subheadline)
                .foregroundStyle(EKitapligimPalette.muted)
                .multilineTextAlignment(.center)
            Button(L10n.commonLogin) { showingLogin = true }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
                .background(EKitapligimPalette.teal, in: Capsule())
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EKitapligimPageBackground())
        .sheet(isPresented: $showingLogin) { LoginView() }
    }
}
