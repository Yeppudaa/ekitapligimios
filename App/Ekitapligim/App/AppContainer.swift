import Foundation
import SwiftUI
import EkitapligimCore

@MainActor
final class AppContainer: ObservableObject {
    @Published var authState: AuthenticationState = .signedOut
    @Published var selectedTab: AppTab = .home
    @Published var presentedRoute: AppRoute?

    // Android keeps this data at app level so the shell, menu and profile all read the same values.
    @Published private(set) var profileState: ProfileDTO?
    @Published private(set) var subscription: SubscriptionDTO?
    @Published private(set) var readingStats: ReadingStatsDTO?
    @Published private(set) var libraryItems: [LibraryItemDTO] = []
    @Published private(set) var unreadNotifications = 0
    @Published private(set) var unreadMessages = 0
    @Published private(set) var isRefreshingSession = false

    var totalUnread: Int { unreadNotifications + unreadMessages }
    var isSignedIn: Bool { if case .signedIn = authState { return true }; return false }
    var isAdmin: Bool { profileState?.isAdmin ?? (subscription?.isAdminTier ?? false) }
    var isPremium: Bool { subscription?.isPremium ?? (profileState?.isPremium ?? false) }

    var currentlyReading: [LibraryItemDTO] { libraryItems.filter(\.isOnReadingShelf) }
    var finishedBooks: [LibraryItemDTO] { libraryItems.filter(\.isOnFinishedShelf) }
    var wantToRead: [LibraryItemDTO] { libraryItems.filter(\.isOnWantToReadShelf) }
    var favoriteBooks: [LibraryItemDTO] { libraryItems.filter(\.isFavoriteItem) }
    var downloadedBooks: [LibraryItemDTO] { libraryItems.filter(\.isDownloaded) }

    /// The most advanced in-progress book, used by the "Kaldığın yerden devam et" cards.
    var continueReadingItem: LibraryItemDTO? {
        currentlyReading
            .filter { $0.progressPercent > 0 || $0.lastReadPage > 0 }
            .max { $0.progressPercent < $1.progressPercent }
            ?? currentlyReading.first
    }

    private var unreadPollTask: Task<Void, Never>?
    private static let unreadPollInterval: Duration = .seconds(60)

    let downloadManager = DownloadManager()
    let readerBookmarks = ReaderBookmarkStore()
    let config: AppConfig
    let tokenStore: TokenStore
    let apiClient: APIClient
    let books: BookRepository
    let site: SiteRepository
    let directories: DirectoryRepository
    let bookRequests: BookRequestsRepository
    let conversations: ConversationsRepository
    let members: MembersRepository
    let auth: AuthRepository
    let account: AccountRepository
    let safety: SafetyRepository
    let purchases: PurchaseRepository
    let storeKit: StoreKitPurchaseService
    let community: CommunityRepository
    let profile: ProfileRepository
    let notifications: NotificationsRepository
    let subscriptions: SubscriptionRepository
    let readingStatsRepository: ReadingStatsRepository
    let bookAgenda: BookAgendaRepository
    let chat: ChatRepository
    let liveActivity: LiveActivityRepository

    init() {
        let apiURL = Bundle.main.urlValue(for: "EKITAPLIGIM_API_BASE_URL")
            ?? URL(string: "https://ekitapligim.com/ios-api/v1/")
            ?? URL(fileURLWithPath: "/invalid-api-config")
        let webURL = URL(string: "https://ekitapligim.com/")
            ?? URL(fileURLWithPath: "/invalid-web-config")
        let environment = Bundle.main.environmentValue(for: "EKITAPLIGIM_ENVIRONMENT")
        let config = AppConfig(environment: environment, apiBaseURL: apiURL, webBaseURL: webURL)
        let tokenStore = KeychainTokenStore(service: "com.ekitapligim.app")
        let apiClient = APIClient(config: config, tokenProvider: tokenStore)

        self.config = config
        self.tokenStore = tokenStore
        self.apiClient = apiClient
        self.books = BookRepository(apiClient: apiClient)
        self.site = SiteRepository(apiClient: apiClient)
        self.directories = DirectoryRepository(apiClient: apiClient)
        self.bookRequests = BookRequestsRepository(apiClient: apiClient)
        self.conversations = ConversationsRepository(apiClient: apiClient)
        self.members = MembersRepository(apiClient: apiClient)
        self.auth = AuthRepository(apiClient: apiClient)
        self.account = AccountRepository(apiClient: apiClient)
        self.safety = SafetyRepository(apiClient: apiClient)
        let purchases = PurchaseRepository(apiClient: apiClient)
        self.purchases = purchases
        self.storeKit = StoreKitPurchaseService(purchaseRepository: purchases)
        self.community = CommunityRepository(apiClient: apiClient)
        self.profile = ProfileRepository(apiClient: apiClient)
        self.notifications = NotificationsRepository(apiClient: apiClient)
        self.subscriptions = SubscriptionRepository(apiClient: apiClient)
        self.readingStatsRepository = ReadingStatsRepository(apiClient: apiClient)
        self.bookAgenda = BookAgendaRepository(apiClient: apiClient)
        self.chat = ChatRepository(apiClient: apiClient)
        self.liveActivity = LiveActivityRepository(apiClient: apiClient)
    }

    func bootstrap() async {
        do {
            try config.validateForRelease()
            if let session = try await tokenStore.loadSession() {
                authState = .signedIn(session)
                downloadManager.restoreDownloads()
                storeKit.startObservingTransactions()
                await refreshSessionData()
                startUnreadPolling()
            }
        } catch {
            authState = .signedOut
        }
    }

    // MARK: - Oturum verisi

    /// Loads everything the shell and profile need in one pass; each call degrades independently.
    func refreshSessionData() async {
        guard isSignedIn else { return }
        isRefreshingSession = true
        defer { isRefreshingSession = false }

        async let profileResult = try? profile.profile()
        async let subscriptionResult = try? subscriptions.subscription()
        async let libraryResult = try? books.library()
        async let statsResult = try? readingStatsRepository.stats()
        async let countsResult = try? notifications.counts()

        let (loadedProfile, loadedSubscription, loadedLibrary, loadedStats, counts) = await (
            profileResult, subscriptionResult, libraryResult, statsResult, countsResult
        )

        if let loadedProfile { profileState = loadedProfile }
        if let loadedSubscription { subscription = loadedSubscription }
        if let loadedLibrary { libraryItems = loadedLibrary.items }
        // The dedicated route may not be deployed yet, in which case the profile payload carries the stats.
        readingStats = loadedStats.flatMap { $0 } ?? loadedProfile?.readingStats ?? readingStats
        if let counts { applyCounts(counts) }
    }

    func refreshUnreadCounts() async {
        guard isSignedIn, let counts = try? await notifications.counts() else { return }
        applyCounts(counts)
    }

    @discardableResult
    func refreshLibrary() async -> Bool {
        guard isSignedIn, let page = try? await books.library() else { return false }
        libraryItems = page.items
        return true
    }

    func patchLibraryItem(_ bookID: String, transform: (LibraryItemDTO) -> LibraryItemDTO) {
        guard let index = libraryItems.firstIndex(where: { $0.bookId == bookID }) else { return }
        libraryItems[index] = transform(libraryItems[index])
    }

    func upsertLibraryItem(_ item: LibraryItemDTO) {
        if let index = libraryItems.firstIndex(where: { $0.bookId == item.bookId }) {
            libraryItems[index] = item
        } else {
            libraryItems.insert(item, at: 0)
        }
    }

    func updateProfile(_ updated: ProfileDTO) {
        profileState = updated
    }

    func updateReadingStats(_ updated: ReadingStatsDTO) {
        readingStats = updated
    }

    private func applyCounts(_ counts: NotificationCountsDTO) {
        unreadNotifications = max(counts.unread, 0)
        unreadMessages = max(counts.conversationsUnread ?? 0, 0)
    }

    func startUnreadPolling() {
        unreadPollTask?.cancel()
        unreadPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.unreadPollInterval)
                if Task.isCancelled { return }
                await self?.refreshUnreadCounts()
            }
        }
    }

    func stopUnreadPolling() {
        unreadPollTask?.cancel()
        unreadPollTask = nil
    }

    /// Called when the scene becomes active again so badges are never stale on return.
    func handleScenePhaseActive() {
        guard isSignedIn else { return }
        startUnreadPolling()
        Task { await refreshUnreadCounts() }
    }

    private func clearSessionData() {
        stopUnreadPolling()
        profileState = nil
        subscription = nil
        readingStats = nil
        libraryItems = []
        unreadNotifications = 0
        unreadMessages = 0
    }

    func signIn(username: String, password: String) async throws {
        authState = .authenticating
        do {
            let response = try await auth.login(username: username, password: password)
            try await applyAuthResponse(response)
        } catch {
            authState = .signedOut
            throw error
        }
    }

    func signInWithApple(identityToken: String, authorizationCode: String, nonce: String) async throws {
        authState = .authenticating
        do {
            let response = try await auth.signInWithApple(identityToken: identityToken, authorizationCode: authorizationCode, nonce: nonce)
            try await applyAuthResponse(response)
        } catch {
            authState = .signedOut
            throw error
        }
    }

    func register(username: String, email: String, password: String) async throws {
        authState = .authenticating
        do {
            let response = try await auth.register(username: username, email: email, password: password)
            try await applyAuthResponse(response)
        } catch {
            authState = .signedOut
            throw error
        }
    }

    func requestPasswordReset(email: String) async throws {
        try await auth.forgotPassword(email: email)
    }

    func updatePassword(currentPassword: String, newPassword: String) async throws {
        let response = try await account.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
        try await applyAuthResponse(response)
    }

    func requestAccountDeletion(currentPassword: String?, reason: String?) async throws {
        try await account.requestAccountDeletion(currentPassword: currentPassword, reason: reason)
        await clearLocalSession()
        presentedRoute = nil
        selectedTab = .profile
    }

    private func applyAuthResponse(_ response: AuthResponseDTO) async throws {
        let session = Session(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            username: response.user.username
        )
        try await tokenStore.save(session: session)
        authState = .signedIn(session)
        storeKit.startObservingTransactions()
        await refreshSessionData()
        startUnreadPolling()
    }

    func logout() async {
        try? await auth.logout()
        await clearLocalSession()
    }

    private func clearLocalSession() async {
        storeKit.stopObservingTransactions()
        downloadManager.removeAllDownloads()
        try? await tokenStore.clear()
        authState = .signedOut
        clearSessionData()
    }

    func open(route: AppRoute) {
        if let tab = AppTab(route: route) {
            presentedRoute = nil
            selectedTab = tab
            return
        }
        presentedRoute = route
    }
}

/// The six bottom-bar destinations, matching `AppRoutes.bottomNavigationRoutes` on Android.
enum AppTab: Hashable, CaseIterable {
    case home
    case catalog
    case authors
    case requests
    case forum
    case profile

    init?(route: AppRoute) {
        switch route {
        case .home: self = .home
        case .catalog: self = .catalog
        case .authors: self = .authors
        case .requests: self = .requests
        case .forum: self = .forum
        case .profile: self = .profile
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .home: L10n.tabHome
        case .catalog: L10n.tabCatalogShort
        case .authors: L10n.tabAuthors
        case .requests: L10n.tabRequests
        case .forum: L10n.tabForum
        case .profile: L10n.tabProfile
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .catalog: "books.vertical.fill"
        case .authors: "person.2.fill"
        case .requests: "heart.fill"
        case .forum: "bubble.left.and.bubble.right.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

private extension Bundle {
    func urlValue(for key: String) -> URL? {
        guard let value = object(forInfoDictionaryKey: key) as? String else { return nil }
        return URL(string: value)
    }

    func environmentValue(for key: String) -> AppEnvironment {
        guard let value = object(forInfoDictionaryKey: key) as? String else { return .production }
        return AppEnvironment(rawValue: value) ?? .production
    }
}
