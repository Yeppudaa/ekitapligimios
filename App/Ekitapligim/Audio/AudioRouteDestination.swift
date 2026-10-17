import SwiftUI
import EkitapligimCore

@MainActor
struct AudioRouteDestination: View {
    @EnvironmentObject private var container: AppContainer
    let route: AppRoute
    var initialFilters: AudioFilters? = nil
    @State private var childRoute: AppRoute?
    @State private var childFilters: AudioFilters?

    var body: some View {
        Group {
            if let repository = container.audioRepository, let controller = container.audioPlayback {
                switch route {
                case .audiobooks:
                    AudioBooksView(repository: repository, controller: controller, account: container.audioAccount,
                        initialFilters: initialFilters ?? .init(),
                        onBook: openBook, onLibrary: { openLibrary(.saved) }, onLogin: login, onPremium: premium)
                case .audiobook(let id):
                    AudioBookDetailView(bookID: id, repository: repository, controller: controller, account: container.audioAccount,
                        onBook: openBook, onLogin: login, onPremium: premium,
                        onPlayer: { childRoute = .audioPlayer }, onFilterCatalog: openFilteredCatalog)
                case .audioLibrary(let tab):
                    AudioLibraryView(repository: repository, controller: controller, account: container.audioAccount,
                        initialTab: AudioLibraryTab(rawValue: tab) ?? .saved,
                        onBook: openBook, onBrowse: { childRoute = .audiobooks }, onLogin: login)
                case .audioPlayer:
                    AudioPlayerView(controller: controller, onBook: openBook, onPremium: premium, onLogin: login)
                default:
                    EKEmptyState(title: AudioL10n.text("title"), message: AudioL10n.text("loadError"), systemImage: "headphones")
                }
            } else {
                EKErrorState(title: AudioL10n.text("title"), message: AudioL10n.text("loadError"))
            }
        }
        .navigationDestination(item: $childRoute) { route in AudioRouteDestination(route: route, initialFilters: route == .audiobooks ? childFilters : nil) }
        .onAppear { container.audioPlayback?.activate(account: container.audioAccount) }
        .onChange(of: container.sessionRevision) { _, _ in
            container.audioPlayback?.activate(account: container.audioAccount)
        }
    }

    private func openBook(_ id: Int) { childRoute = .audiobook(id) }
    private func openLibrary(_ tab: AudioLibraryTab) { childRoute = .audioLibrary(tab: tab.rawValue) }
    private func openFilteredCatalog(_ field: String, value: String) {
        var filters = AudioFilters()
        switch field { case "author": filters.author = value; case "category": filters.category = max(0, Int(value) ?? 0); case "narrator": filters.narrator = value; default: return }
        childFilters = filters; childRoute = .audiobooks
    }
    private func login() { container.open(route: .login) }
    private func premium() { container.open(route: .premium) }
}
