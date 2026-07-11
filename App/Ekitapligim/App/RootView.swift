import SwiftUI
import EkitapligimCore

@MainActor
struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView(selection: $container.selectedTab) {
            HomeView()
                .tabItem { Label(L10n.tabHome, systemImage: "house") }
                .tag(AppTab.home)

            CatalogView()
                .tabItem { Label(L10n.tabCatalog, systemImage: "books.vertical") }
                .tag(AppTab.catalog)

            LibraryView()
                .tabItem { Label(L10n.tabLibrary, systemImage: "bookmark") }
                .tag(AppTab.library)

            CommunityView()
                .tabItem { Label(L10n.tabCommunity, systemImage: "person.3") }
                .tag(AppTab.community)

            SettingsView()
                .tabItem { Label(L10n.tabAccount, systemImage: "person.crop.circle") }
                .tag(AppTab.settings)
        }
        .onOpenURL { url in
            guard let route = DeepLinkParser().parse(url.absoluteString) else { return }
            container.open(route: route)
        }
        .sheet(item: $container.presentedRoute) { route in
            AppRouteView(route: route)
        }
    }
}

@MainActor
private struct AppRouteView: View {
    @Environment(\.dismiss) private var dismiss
    let route: AppRoute

    var body: some View {
        NavigationStack {
            routeDestination
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.commonClose) { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var routeDestination: some View {
        switch route {
        case .bookDetail(let id):
            BookDetailView(bookID: id)
        case .thread(let id):
            ForumThreadDetailView(thread: ForumThreadDTO(id: String(id), title: L10n.myCommentsForumTitle, username: ""))
        case .forumDetail(let id):
            ForumThreadsView(forum: ForumDTO(id: String(id), title: L10n.communityForumsSection))
        case .authors:
            DirectoryView(kind: .author)
        case .publishers:
            DirectoryView(kind: .publisher)
        case .requests:
            BookRequestsView()
        case .home:
            HomeView()
        case .catalog:
            CatalogView()
        case .forum:
            CommunityView()
        }
    }
}
