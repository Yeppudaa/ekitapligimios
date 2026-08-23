import SwiftUI
import UIKit
import EkitapligimCore

@MainActor
struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var isMenuPresented = false

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 251 / 255, green: 254 / 255, blue: 254 / 255, alpha: 1)
        appearance.shadowColor = UIColor(red: 226 / 255, green: 232 / 255, blue: 234 / 255, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $container.selectedTab) {
                HomeView().tabItem { Label(L10n.tabHome, systemImage: "house.fill") }.tag(AppTab.home)
                CatalogView().tabItem { Label(L10n.tabCatalog, systemImage: "books.vertical.fill") }.tag(AppTab.catalog)
                LibraryView().tabItem { Label(L10n.tabLibrary, systemImage: "bookmark.fill") }.tag(AppTab.library)
                CommunityView().tabItem { Label(L10n.tabCommunity, systemImage: "person.3.fill") }.tag(AppTab.community)
                SettingsView().tabItem { Label(L10n.tabAccount, systemImage: "person.crop.circle.fill") }.tag(AppTab.settings)
            }
            .tint(EKitapligimPalette.teal)

            Button { withAnimation(.easeOut(duration: 0.2)) { isMenuPresented = true } } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(EKitapligimPalette.border) }
            }
            .accessibilityLabel(L10n.menuTitle)
            .padding(.top, 8)
            .padding(.trailing, 12)

            if isMenuPresented {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture { closeMenu() }
                    .transition(.opacity)
                    .zIndex(1)
                AppSideMenu(onSelect: selectMenuItem, onClose: closeMenu)
                    .frame(maxWidth: 356)
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
            }
        }
        .onOpenURL { url in
            guard let route = DeepLinkParser().parse(url.absoluteString) else { return }
            container.open(route: route)
        }
        .sheet(item: $container.presentedRoute) { route in
            AppRouteView(route: route)
        }
    }

    private func selectMenuItem(_ item: AppMenuItem) {
        closeMenu()
        switch item.destination {
        case .tab(let tab): container.selectedTab = tab
        case .route(let route): container.presentedRoute = route
        }
    }

    private func closeMenu() {
        withAnimation(.easeIn(duration: 0.18)) { isMenuPresented = false }
    }
}

private struct AppSideMenu: View {
    let onSelect: (AppMenuItem) -> Void
    let onClose: () -> Void

    private let items: [AppMenuItem] = [
        .init(title: L10n.tabHome, subtitle: L10n.homeExploreSection, icon: "house.fill", destination: .tab(.home)),
        .init(title: L10n.tabCatalog, subtitle: L10n.homeOpenCatalog, icon: "books.vertical.fill", destination: .tab(.catalog)),
        .init(title: L10n.directoryAuthorsTitle, subtitle: L10n.menuAuthorsSubtitle, icon: "person.2.fill", destination: .route(.authors)),
        .init(title: L10n.directoryPublishersTitle, subtitle: L10n.menuPublishersSubtitle, icon: "building.2.fill", destination: .route(.publishers)),
        .init(title: L10n.bookRequestsTitle, subtitle: L10n.menuRequestsSubtitle, icon: "heart.fill", destination: .route(.requests)),
        .init(title: L10n.tabCommunity, subtitle: L10n.communityForumsSection, icon: "bubble.left.and.bubble.right.fill", destination: .tab(.community)),
        .init(title: L10n.tabLibrary, subtitle: L10n.homeContinueReading, icon: "bookmark.fill", destination: .tab(.library)),
        .init(title: L10n.tabAccount, subtitle: L10n.settingsAccountSection, icon: "person.crop.circle.fill", destination: .tab(.settings))
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                EKitapligimBrandLogo().frame(width: 112, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.homeTitle).font(.headline).foregroundStyle(EKitapligimPalette.ink)
                    Text(L10n.menuSubtitle).font(.caption2).foregroundStyle(EKitapligimPalette.muted)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").foregroundStyle(EKitapligimPalette.muted).frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(items) { item in
                        Button { onSelect(item) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .accessibilityLabel(item.title)
                                    .foregroundStyle(EKitapligimPalette.teal)
                                    .frame(width: 38, height: 38)
                                    .background(EKitapligimPalette.tealSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.subheadline.weight(.bold)).foregroundStyle(EKitapligimPalette.ink)
                                    Text(item.subtitle).font(.caption2).foregroundStyle(EKitapligimPalette.muted).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(EKitapligimPalette.muted)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title)
                    }

                    Button { onSelect(.init(title: L10n.premiumShortTitle, subtitle: L10n.premiumDescription, icon: "crown.fill", destination: .tab(.settings))) } label: {
                        Label(L10n.premiumTitle, systemImage: "crown.fill")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(EKitapligimPalette.amber)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(EKitapligimPalette.amberSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(maxHeight: .infinity)
        .background(EKitapligimPalette.pageGradient)
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct AppMenuItem: Identifiable {
    enum Destination { case tab(AppTab), route(AppRoute) }
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let destination: Destination
}

@MainActor
private struct AppRouteView: View {
    @Environment(\.dismiss) private var dismiss
    let route: AppRoute

    var body: some View {
        NavigationStack {
            routeDestination
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button(L10n.commonClose) { dismiss() } }
                }
        }
        .tint(EKitapligimPalette.teal)
    }

    @ViewBuilder private var routeDestination: some View {
        switch route {
        case .bookDetail(let id): BookDetailView(bookID: id)
        case .thread(let id): ForumThreadDetailView(thread: ForumThreadDTO(id: String(id), title: L10n.myCommentsForumTitle, username: ""))
        case .forumDetail(let id): ForumThreadsView(forum: ForumDTO(id: String(id), title: L10n.communityForumsSection))
        case .authors: DirectoryView(kind: .author)
        case .publishers: DirectoryView(kind: .publisher)
        case .requests: BookRequestsView()
        case .home: HomeView()
        case .catalog: CatalogView()
        case .forum: CommunityView()
        }
    }
}
