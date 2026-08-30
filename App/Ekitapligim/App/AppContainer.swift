import Foundation
import SwiftUI
import EkitapligimCore

@MainActor
final class AppContainer: ObservableObject {
    @Published var authState: AuthenticationState = .signedOut
    @Published var selectedTab: AppTab = .home
    @Published var presentedRoute: AppRoute?
    /// Shelf index for the Library tab (`library/{tab}` deep links and menu shortcuts).
    @Published var libraryShelfTab: Int = 0

    // Android keeps this data at app level so the shell, menu and profile all read the same values.
    @Published private(set) var profileState: ProfileDTO?
    @Published private(set) var subscription: SubscriptionDTO?
    @Published private(set) var readingStats: ReadingStatsDTO?
    @Published private(set) var libraryItems: [LibraryItemDTO] = []
    @Published private(set) var unreadNotifications = 0
    @Published private(set) var unreadMessages = 0
    @Published private(set) var isRefreshingSession = false
    @Published private(set) var blockedUserIDs: Set<Int> = []

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

    let downloadManager: DownloadManager
    let readerContentLoader: ReaderContentLoader
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
        let fileTransfer = ValidatedBookFileTransfer(tokenProvider: tokenStore, apiBaseURL: apiURL)

        self.config = config
        self.tokenStore = tokenStore
        self.apiClient = apiClient
        self.downloadManager = DownloadManager(transfer: fileTransfer)
        self.readerContentLoader = ReaderContentLoader(transfer: fileTransfer)
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
        self.storeKit.entitlementDidChange = { [weak self] in
            await self?.refreshPremiumStatus()
        }
    }

    func bootstrap() async {
        do {
            try config.validateForRelease()
            if let session = try await tokenStore.loadSession() {
                authState = .signedIn(session)
                downloadManager.restoreDownloads()
                storeKit.startObservingTransactions()
                await refreshSessionData()
                await storeKit.refreshEntitlements()
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
        async let blockedResult = try? safety.blockedMembers()

        let (loadedProfile, loadedSubscription, loadedLibrary, loadedStats, counts, blocked) = await (
            profileResult, subscriptionResult, libraryResult, statsResult, countsResult, blockedResult
        )

        if let loadedProfile { profileState = loadedProfile }
        if let loadedSubscription { subscription = loadedSubscription }
        if let loadedLibrary { libraryItems = loadedLibrary.items }
        // The dedicated route may not be deployed yet, in which case the profile payload carries the stats.
        readingStats = loadedStats.flatMap { $0 } ?? loadedProfile?.readingStats ?? readingStats
        if let counts { applyCounts(counts) }
        if let blocked {
            blockedUserIDs = Set(blocked.members.compactMap { Int($0.id) })
        }
    }

    func refreshUnreadCounts() async {
        guard isSignedIn, let counts = try? await notifications.counts() else { return }
        applyCounts(counts)
    }

    func refreshPremiumStatus() async {
        guard isSignedIn, let updated = try? await subscriptions.subscription() else { return }
        subscription = updated
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
        blockedUserIDs = []
    }

    func signIn(username: String, password: String, acceptedTermsVersion: String) async throws {
        authState = .authenticating
        do {
            let response = try await auth.login(
                username: username,
                password: password,
                acceptedTermsVersion: acceptedTermsVersion
            )
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

    func register(username: String, email: String, password: String, acceptedTermsVersion: String) async throws {
        authState = .authenticating
        do {
            let response = try await auth.register(
                username: username,
                email: email,
                password: password,
                acceptedTermsVersion: acceptedTermsVersion
            )
            try await applyAuthResponse(response)
        } catch {
            authState = .signedOut
            throw error
        }
    }

    func requestPasswordReset(email: String) async throws {
        try await auth.forgotPassword(email: email)
    }

    @discardableResult
    func blockAndReport(
        userID: Int,
        sourceType: UGCContentType,
        sourceID: Int,
        reason: UGCReportReason,
        details: String = ""
    ) async throws -> BlockMemberResponseDTO {
        let response = try await safety.blockMember(
            userID: userID,
            sourceType: sourceType,
            sourceID: sourceID,
            reason: reason,
            details: details
        )
        blockedUserIDs.insert(userID)
        return response
    }

    func rememberBlockedUser(_ userID: Int) {
        blockedUserIDs.insert(userID)
    }

    func forgetBlockedUser(_ userID: Int) {
        blockedUserIDs.remove(userID)
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
        await storeKit.refreshEntitlements()
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
        if case .library(let tab) = route {
            libraryShelfTab = tab
            presentedRoute = nil
            selectedTab = .library
            return
        }
        if let tab = AppTab(route: route) {
            presentedRoute = nil
            selectedTab = tab
            return
        }
        presentedRoute = route
    }
}

/// The five bottom-bar destinations. Katalog and Yazarlar stay in the side menu.
enum AppTab: Hashable, CaseIterable {
    case home
    case community
    case library
    case requests
    case profile

    init?(route: AppRoute) {
        switch route {
        case .home: self = .home
        case .forum: self = .community
        case .library: self = .library
        case .requests: self = .requests
        case .profile: self = .profile
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .home: L10n.tabHome
        case .community: L10n.tabCommunity
        case .library: L10n.tabLibrary
        case .requests: L10n.tabRequests
        case .profile: L10n.tabProfile
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .community: "bubble.left.and.bubble.right.fill"
        case .library: "books.vertical.circle.fill"
        case .requests: "heart.fill"
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
