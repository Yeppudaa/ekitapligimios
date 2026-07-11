import Foundation
import SwiftUI
import EkitapligimCore

@MainActor
final class AppContainer: ObservableObject {
    @Published var authState: AuthenticationState = .signedOut
    @Published var selectedTab: AppTab = .home
    @Published var presentedRoute: AppRoute?

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

    init() {
        let apiURL = Bundle.main.urlValue(for: "EKITAPLIGIM_API_BASE_URL")
            ?? URL(string: "https://ekitapligim.com/mobile-api/v1/")
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
    }

    func bootstrap() async {
        do {
            try config.validateForRelease()
            if let session = try await tokenStore.loadSession() {
                authState = .signedIn(session)
                storeKit.startObservingTransactions()
            }
        } catch {
            authState = .signedOut
        }
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
        selectedTab = .settings
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
    }

    func logout() async {
        try? await auth.logout()
        await clearLocalSession()
    }

    private func clearLocalSession() async {
        storeKit.stopObservingTransactions()
        try? await tokenStore.clear()
        authState = .signedOut
    }

    func open(route: AppRoute) {
        switch route {
        case .home:
            presentedRoute = nil
            selectedTab = .home
        case .catalog:
            presentedRoute = nil
            selectedTab = .catalog
        case .forum:
            presentedRoute = nil
            selectedTab = .community
        default:
            presentedRoute = route
        }
    }
}

enum AppTab: Hashable {
    case home
    case catalog
    case library
    case community
    case settings
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
