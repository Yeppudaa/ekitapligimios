import SwiftUI
import UIKit
import EkitapligimCore

@MainActor
struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var isMenuPresented = false
    @State private var assistantHidden = false
    @State private var assistantCollapsed = true
    @State private var keyboardVisible = false
    @State private var readerRequestedPremium = false

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
            if container.isForumPresented || container.selectedTab != .catalog {
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
        .task { container.activateAssistantAccount() }
        .task { container.audioPlayback?.activate(account: container.audioAccount) }
        .onChange(of: container.sessionRevision) { _, _ in
            container.audioPlayback?.activate(account: container.audioAccount)
        }
        .onPreferenceChange(AILauncherHiddenKey.self) { assistantHidden = $0 }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { container.handleScenePhaseActive() }
            if phase == .background { container.handleScenePhaseBackground() }
        }
        .sheet(item: sheetRoute) { route in
            AppRouteSheet(route: route)
        }
        .fullScreenCover(item: readerRoute, onDismiss: {
            if readerRequestedPremium {
                readerRequestedPremium = false
                container.open(route: .premium)
            }
        }) { route in
            if case .reader(let id) = route {
                ReaderLoaderView(bookID: id, onPremium: {
                    readerRequestedPremium = true
                    container.presentedRoute = nil
                })
            }
        }
    }

    private var readerRoute: Binding<AppRoute?> {
        Binding(get: {
            if case .reader = container.presentedRoute { return container.presentedRoute }
            return nil
        }, set: { value in
            if case .reader = container.presentedRoute { container.presentedRoute = value }
        })
    }

    private var sheetRoute: Binding<AppRoute?> {
        Binding(get: {
            if case .reader = container.presentedRoute { return nil }
            return container.presentedRoute
        }, set: { value in
            if case .reader = container.presentedRoute { return }
            container.presentedRoute = value
        })
    }

    private var tabs: some View {
        VStack(spacing: 0) {
            Group {
                if container.isForumPresented {
                    CommunityView()
                } else {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                if !isMenuPresented && !assistantHidden && !keyboardVisible && container.presentedRoute == nil {
                    AIAssistantLauncher(model: container.assistantModel, isCollapsed: $assistantCollapsed) {
                        container.open(route: .aiAssistant(bookID: nil))
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }

            if container.presentedRoute == nil, let controller = container.audioPlayback {
                AudioMiniPlayerView(controller: controller) { container.open(route: .audioPlayer) }
            }
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
                ModernSideMenu(onSelect: navigate, onClose: closeMenu)
                    .frame(maxWidth: 368)
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

// MARK: - Route sunumu

@MainActor
private struct AppRouteSheet: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    let route: AppRoute

    var body: some View {
        NavigationStack {
            destination
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsMiniPlayer, let controller = container.audioPlayback {
                        AudioMiniPlayerView(controller: controller) { container.open(route: .audioPlayer) }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if let controller = container.audioPlayback {
                            AudioAwareRouteCloseButton(controller: controller) { dismiss() }
                        } else {
                            Button(L10n.commonClose) { dismiss() }
                        }
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
        case .audiobooks, .audiobook, .audioLibrary, .audioPlayer:
            AudioRouteDestination(route: route)
        case .giftWheel:
            GiftWheelDestination().presentationDetents([.large])
        case .aiAssistant(let bookID):
            AIAssistantDestination(bookID: bookID)
        case .aiCollections(let slug):
            AICollectionsDestination(slug: slug)
        case .forum:
            CommunityView()
        case .home, .requests, .profile, .bookAgenda, .liveActivity:
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

    private var showsMiniPlayer: Bool {
        switch route {
        case .audioPlayer, .reader, .login, .register, .premium: return false
        default: return true
        }
    }
}

/// Observes the player itself so expanding a nested player removes the shell's duplicate close control.
@MainActor
private struct AudioAwareRouteCloseButton: View {
    @ObservedObject var controller: AudioPlaybackController
    var onClose: () -> Void

    var body: some View {
        if !controller.expanded { Button(L10n.commonClose, action: onClose) }
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
