import SwiftUI
import EkitapligimCore

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
    }
}
