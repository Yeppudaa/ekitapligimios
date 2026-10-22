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
    @State private var keyboardBottomInset: CGFloat = 0
    @State private var keyboardDismissRequest = 0
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
            drawer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The shell owns keyboard avoidance once. Descendant scroll views receive its safe inset;
        // UIKit sheets keep their own presentation-local keyboard avoidance.
        .background {
            WindowKeyboardLayoutReader(dismissRequest: keyboardDismissRequest) { keyboardBottomInset = $0 }
                .ignoresSafeArea(.container, edges: .bottom)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: container.selectedTab) { _, _ in
            if !container.isCatalogSearchPresented { dismissKeyboard() }
        }
        .onChange(of: container.isForumPresented) { _, _ in dismissKeyboard() }
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { container.handleScenePhaseActive() }
            if phase == .background {
                dismissKeyboard()
                container.handleScenePhaseBackground()
            }
        }
        .sheet(item: sheetRoute) { route in
            AppRouteSheet(route: route, keyboardIsPresented: keyboardBottomInset > 0.5)
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
        GeometryReader { geometry in
            activeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.replyViewportHeight, max(0, geometry.size.height - geometry.safeAreaInsets.bottom - geometry.safeAreaInsets.top))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("shell.content")
                .overlay(alignment: .bottomTrailing) {
                    if !isMenuPresented && !assistantHidden && keyboardBottomInset <= 0.5 && container.presentedRoute == nil && container.audioPageRoute == nil {
                        AIAssistantLauncher(model: container.assistantModel, isCollapsed: $assistantCollapsed) {
                            container.open(route: .aiAssistant(bookID: nil))
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if keyboardBottomInset > 0.5 {
                Color.clear.frame(height: keyboardBottomInset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else {
                VStack(spacing: 0) {
                    if container.presentedRoute == nil, let controller = container.audioPlayback {
                        AudioMiniPlayerView(controller: controller) { container.open(route: .audioPlayer) }
                    }
                    PrimaryTabBar(selection: $container.selectedTab, profileBadgeCount: container.totalUnread)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("shell.primary-tabs")
                }
            }
        }
        .tint(EKitapligimPalette.teal)
    }

    @ViewBuilder private var activeContent: some View {
        if container.isForumPresented {
            CommunityView(hostsAudioNavigation: true, onOpenMenu: shellMenuAction)
        } else {
            switch container.selectedTab {
            case .home: HomeView(hostsAudioNavigation: true, onOpenMenu: shellMenuAction)
            case .catalog: CatalogView(hostsAudioNavigation: true, onOpenMenu: shellMenuAction)
            case .agenda: NavigationStack { BookAgendaView().shellMenu(action: shellMenuAction).audioPageNavigation() }
            case .flow: NavigationStack { LiveActivityView().shellMenu(action: shellMenuAction).audioPageNavigation() }
            case .requests: NavigationStack { BookRequestsView().shellMenu(action: shellMenuAction).audioPageNavigation() }
            case .profile: NavigationStack { ProfileView().shellMenu(action: shellMenuAction).audioPageNavigation() }
            }
        }
    }

    private func dismissKeyboard() { keyboardDismissRequest += 1 }
    private var shellMenuAction: (() -> Void)? {
        guard container.audioPageRoute == nil else { return nil }
        return { openMenu() }
    }

    private func openMenu() {
        dismissKeyboard()
        withAnimation(.easeOut(duration: 0.2)) { isMenuPresented = true }
    }

    @ViewBuilder private var drawer: some View {
        if isMenuPresented {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { closeMenu() }
                .transition(.opacity)
                .zIndex(1)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ModernSideMenu(onSelect: navigate, onClose: closeMenu)
                        .frame(width: min(368, geometry.size.width), height: geometry.size.height)
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
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
    var keyboardIsPresented = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                destination
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.replyViewportHeight, max(0, geometry.size.height - geometry.safeAreaInsets.bottom - geometry.safeAreaInsets.top))
            }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsMiniPlayer, !keyboardIsPresented, let controller = container.audioPlayback {
                        AudioMiniPlayerView(controller: controller) { container.open(route: .audioPlayer) }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if let controller = container.audioPlayback {
                            AudioAwareRouteCloseButton(controller: controller) { dismiss() }
                                .accessibilityIdentifier("shell.route.close")
                        } else {
                            Button(L10n.commonClose) { dismiss() }
                                .accessibilityIdentifier("shell.route.close")
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
struct LoginRequiredView: View {
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
