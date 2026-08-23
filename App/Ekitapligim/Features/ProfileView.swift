import SwiftUI
import EkitapligimCore

/// Profilim — mirrors the Android `ProfileScreen` layout section by section.
@MainActor
struct ProfileView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var section: ProfileSection = .profile
    @State private var posts: [ForumPostDTO] = []
    @State private var isLoadingPosts = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var showingLogin = false
    @State private var showingDeleteConfirmation = false
    @State private var isSubmittingDeletion = false
    @State private var route: ProfileRoute?

    private var profile: ProfileDTO? { container.profileState }
    private var stats: ReadingStatsDTO? { container.readingStats }
    private var subscription: SubscriptionDTO? { container.subscription }

    var body: some View {
        ZStack {
            EKitapligimPageBackground()
            if container.isSignedIn {
                signedInContent
            } else {
                GuestProfilePrompt { showingLogin = true }
            }
        }
        .navigationTitle(L10n.profileScreenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if container.isSignedIn, profile?.canEdit != false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { route = .edit } label: {
                        Text(L10n.commonEdit)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(EKitapligimPalette.profileTealDeep)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                            .background(EKitapligimPalette.profileTealSoft, in: Capsule())
                    }
                }
            }
        }
        .sheet(isPresented: $showingLogin) { LoginView() }
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .edit: ProfileEditView()
            case .stats: StatsView()
            case .library(let tab): LibraryView(initialTab: tab)
            case .downloads: DownloadsView()
            case .requests: BookRequestsView()
            case .comments: MyCommentsView()
            case .notifications: NotificationsView()
            case .messages: ConversationsView()
            case .premium: PremiumView()
            case .settings: SettingsView()
            case .security:
                AccountSecurityView(currentEmail: profile?.email ?? "") {
                    Task { await container.refreshSessionData() }
                }
            }
        }
        .task { await initialLoad() }
        .refreshable { await refresh() }
        .alert(L10n.profileDeleteRequest, isPresented: $showingDeleteConfirmation) {
            Button(L10n.commonDismiss, role: .cancel) {}
            Button(L10n.profileDeleteRequestConfirm, role: .destructive) {
                Task { await submitDeletionRequest() }
            }
        } message: {
            Text(L10n.profileDeleteRequestMessage)
        }
    }

    private var signedInContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let errorMessage {
                    EKInlineError(message: errorMessage, retryTitle: L10n.commonRetry) {
                        Task { await refresh() }
                    }
                }
                if let statusMessage {
                    successBanner(statusMessage)
                }

                ProfileHero(profile: profile, subscription: subscription)
                ProfileStatsBand(
                    profile: profile,
                    readingCount: container.currentlyReading.count,
                    finishedCount: container.finishedBooks.count,
                    listedCount: container.libraryItems.count,
                    onShelfTap: { route = .library($0) }
                )
                sectionTabs
                sectionContent
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 34)
        }
    }

    // MARK: Sekmeler

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(ProfileSection.allCases) { item in
                    EKChip(title: item.title, isSelected: section == item) {
                        section = item
                        if item == .posts { Task { await loadPostsIfNeeded() } }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel(L10n.profileSectionTabsAccessibility)
    }

    @ViewBuilder private var sectionContent: some View {
        switch section {
        case .profile: profileSection
        case .library: librarySection
        case .posts: postsSection
        case .activity: activitySection
        case .about: aboutSection
        case .badges: badgesSection
        }
    }

    // MARK: Profil sekmesi

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReadingSummaryStrip(
                readingCount: container.currentlyReading.count,
                finishedCount: container.finishedBooks.count,
                listedCount: container.libraryItems.count
            )
            ReadingAchievementCard(stats: effectiveStats) { route = .stats }
            DailyLimitSection(subscription: subscription, isAdmin: container.isAdmin)
            ContinueReadingCard(item: container.continueReadingItem)
            actionGrid
            PremiumMembershipCard(subscription: subscription, isPremium: container.isPremium) { route = .premium }
            ProfileMetricsRow(profile: profile)
            ProfileInfoCard(profile: profile)
            accountActions
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            EKActionTile(title: L10n.profileActionLibrary, systemImage: "books.vertical.fill") { route = .library(.reading) }
            EKActionTile(title: L10n.profileActionFavorites, systemImage: "heart.fill") { route = .library(.favorites) }
            EKActionTile(title: L10n.profileActionReadLater, systemImage: "clock.fill") { route = .library(.wantToRead) }
            EKActionTile(title: L10n.profileActionReadingNow, systemImage: "book.pages.fill") { route = .library(.reading) }
            EKActionTile(title: L10n.profileActionFinished, systemImage: "checkmark.seal.fill") { route = .library(.finished) }
            EKActionTile(title: L10n.profileActionDownloads, systemImage: "arrow.down.circle.fill") { route = .downloads }
            EKActionTile(title: L10n.profileActionBookRequests, systemImage: "sparkles") { route = .requests }
            EKActionTile(title: L10n.profileActionMyComments, systemImage: "text.bubble.fill") { route = .comments }
            EKActionTile(
                title: L10n.profileActionNotifications,
                systemImage: "bell.fill",
                badgeCount: container.unreadNotifications
            ) { route = .notifications }
            EKActionTile(
                title: L10n.profileActionMessages,
                systemImage: "envelope.fill",
                badgeCount: container.unreadMessages
            ) { route = .messages }
            EKActionTile(title: L10n.profileActionStats, systemImage: "chart.bar.fill") { route = .stats }
        }
    }

    private var accountActions: some View {
        VStack(spacing: 10) {
            EKActionTile(title: L10n.accountSecurityTitle, systemImage: "lock.shield.fill") { route = .security }
            EKActionTile(title: L10n.settingsTitle, systemImage: "gearshape.fill") { route = .settings }

            Button {
                Task { await container.logout() }
            } label: {
                Text(L10n.profileLogout)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EKitapligimPalette.profileTealDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                showingDeleteConfirmation = true
            } label: {
                Text(isSubmittingDeletion ? L10n.commonLoading : L10n.profileDeleteRequest)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .disabled(isSubmittingDeletion)
        }
        .padding(.top, 4)
    }

    // MARK: Diğer sekmeler

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeading(title: L10n.profileLibrarySectionTitle, subtitle: L10n.profileLibrarySectionSubtitle)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                LibraryShelfCard(title: L10n.profileStatReading, count: container.currentlyReading.count, systemImage: "book.pages.fill") {
                    route = .library(.reading)
                }
                LibraryShelfCard(title: L10n.profileStatRead, count: container.finishedBooks.count, systemImage: "checkmark.seal.fill") {
                    route = .library(.finished)
                }
                LibraryShelfCard(title: L10n.profileReadingList, count: container.wantToRead.count, systemImage: "bookmark.fill") {
                    route = .library(.wantToRead)
                }
                LibraryShelfCard(title: L10n.libraryTabFavorites, count: container.favoriteBooks.count, systemImage: "heart.fill") {
                    route = .library(.favorites)
                }
            }

            if container.libraryItems.isEmpty {
                ProfileEmptyState(message: L10n.profileLibraryEmpty)
            } else {
                ProfileSectionHeading(title: L10n.profileMyBooks, subtitle: nil)
                ForEach(container.libraryItems.prefix(6), id: \.bookId) { item in
                    NavigationLink { BookDetailView(bookID: Int(item.bookId) ?? 0) } label: {
                        ProfileBookRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeading(title: L10n.profileTabPosts, subtitle: L10n.profilePostsSubtitle)
            if isLoadingPosts && posts.isEmpty {
                EKSkeletonCard(height: 90)
                EKSkeletonCard(height: 90)
            } else if posts.isEmpty {
                ProfileEmptyState(message: L10n.profilePostsEmpty)
            } else {
                ForEach(posts) { post in
                    ProfilePostRow(post: post)
                }
            }
        }
        .task { await loadPostsIfNeeded() }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeading(title: L10n.profileTabActivity, subtitle: L10n.profileTabActivitySubtitle)
            ProfileActivityList(userID: profile?.id)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeading(title: L10n.profileAboutStoryTitle, subtitle: L10n.profileTabAboutSubtitle)
            let about = EKitapligimFormat.plainText(profile?.about ?? "")
            if about.isEmpty {
                ProfileEmptyState(message: L10n.profileAboutEmpty)
            } else {
                Text(about)
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.profileInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .ekitapligimCard()
            }
            ProfileInfoCard(profile: profile)
            Button(L10n.profileAboutEditAction) { route = .edit }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(EKitapligimPalette.profileTealDeep)
        }
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeading(title: L10n.profileBadgesTitle, subtitle: L10n.profileTabBadgesSubtitle)
            let badges = profile?.badges ?? []
            if badges.isEmpty {
                ProfileEmptyState(message: L10n.profileBadgesEmpty)
            } else {
                ForEach(badges) { badge in
                    ProfileBadgeRow(badge: badge)
                }
            }
        }
    }

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(EKitapligimPalette.successInk)
            Text(message)
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.successInk)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(EKitapligimPalette.successSoft)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: Veri

    /// Falls back to the stats embedded in the profile payload when `me/reading-stats` is not deployed.
    private var effectiveStats: ReadingStatsDTO {
        stats ?? profile?.readingStats ?? ReadingStatsDTO()
    }

    private func initialLoad() async {
        guard container.isSignedIn, container.profileState == nil else { return }
        await refresh()
    }

    private func refresh() async {
        guard container.isSignedIn else { return }
        errorMessage = nil
        await container.refreshSessionData()
        if container.profileState == nil {
            errorMessage = L10n.profileLoadFailed
        }
    }

    private func loadPostsIfNeeded() async {
        guard container.isSignedIn, posts.isEmpty, !isLoadingPosts else { return }
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        posts = (try? await container.profile.comments(page: 1).comments) ?? []
    }

    private func submitDeletionRequest() async {
        isSubmittingDeletion = true
        defer { isSubmittingDeletion = false }
        do {
            try await container.requestAccountDeletion(currentPassword: nil, reason: nil)
            statusMessage = L10n.profileDeleteRequestSent
        } catch {
            errorMessage = L10n.profileDeleteRequestFailed
        }
    }
}

// MARK: - Bölümler

enum ProfileSection: String, CaseIterable, Identifiable {
    case profile, library, posts, activity, about, badges

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: L10n.profileTabProfile
        case .library: L10n.profileTabLibrary
        case .posts: L10n.profileTabPosts
        case .activity: L10n.profileTabActivity
        case .about: L10n.profileTabAbout
        case .badges: L10n.profileTabBadges
        }
    }
}

private enum ProfileRoute: Hashable, Identifiable {
    case edit
    case stats
    case library(LibraryTab)
    case downloads
    case requests
    case comments
    case notifications
    case messages
    case premium
    case settings
    case security

    var id: String { String(describing: self) }
}

// MARK: - Hero

private struct ProfileHero: View {
    let profile: ProfileDTO?
    let subscription: SubscriptionDTO?

    private var username: String { profile?.username ?? "" }
    private var isVerified: Bool { profile?.role?.showVerifiedBadge ?? false }
    private var isAdmin: Bool { profile?.isAdmin ?? (subscription?.isAdminTier ?? false) }
    private var isPremium: Bool { subscription?.isPremium ?? (profile?.isPremium ?? false) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            banner
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 13) {
                    EKAvatar(
                        urlString: profile?.avatarUrl,
                        username: username,
                        size: 76,
                        background: .white.opacity(0.16),
                        foreground: .white
                    )
                    .overlay { Circle().stroke(.white.opacity(0.6), lineWidth: 2) }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(username)
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.footnote)
                                    .foregroundStyle(EKitapligimPalette.profileGold)
                                    .accessibilityLabel(L10n.profileVerifiedAccessibility)
                            }
                        }
                        Text(profile?.displayTitle ?? L10n.profileMemberFallback)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                        HStack(spacing: 7) {
                            if isAdmin {
                                heroChip(L10n.profileRoleAdmin, systemImage: "shield.fill")
                            }
                            if isPremium {
                                heroChip(L10n.profileRolePremium, systemImage: "crown.fill")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 16) {
                    if let joined = EKitapligimFormat.date(profile?.registerDate ?? 0) {
                        heroFootnote(L10n.profileJoinedOn(joined), systemImage: "calendar")
                    }
                    if let seen = EKitapligimFormat.date(profile?.lastActivity ?? 0) {
                        heroFootnote(L10n.profileLastSeen(seen), systemImage: "clock")
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
        }
        .background(EKitapligimPalette.profileHeroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var banner: some View {
        ZStack {
            EKitapligimPalette.profileBannerGradient
            if let bannerUrl = profile?.bannerUrl,
               !bannerUrl.isEmpty,
               let url = URL(string: bannerUrl),
               url.scheme?.lowercased() == "https" {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(height: 84)
        .clipped()
        .accessibilityHidden(true)
    }

    private func heroChip(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            Text(title).font(.system(size: 10, weight: .heavy))
        }
        .foregroundStyle(EKitapligimPalette.profileGold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.13), in: Capsule())
        .overlay { Capsule().stroke(EKitapligimPalette.profileGold.opacity(0.5)) }
    }

    private func heroFootnote(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 9))
            Text(text).font(.system(size: 10))
        }
        .foregroundStyle(.white.opacity(0.75))
        .lineLimit(1)
    }
}

// MARK: - İstatistik şeridi

private struct ProfileStatsBand: View {
    let profile: ProfileDTO?
    let readingCount: Int
    let finishedCount: Int
    let listedCount: Int
    let onShelfTap: (LibraryTab) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                EKStatCell(value: EKitapligimFormat.count(profile?.messageCount ?? 0), label: L10n.profileStatMessages)
                divider
                EKStatCell(value: EKitapligimFormat.count(profile?.reactionScore ?? 0), label: L10n.profileStatReactions)
                divider
                EKStatCell(value: EKitapligimFormat.count(profile?.trophyPoints ?? 0), label: L10n.profileStatPoints)
                divider
                shelfCell(value: readingCount, label: L10n.profileStatReading, tab: .reading)
                divider
                shelfCell(value: finishedCount, label: L10n.profileStatRead, tab: .finished)
                divider
                shelfCell(value: listedCount, label: L10n.profileStatListed, tab: .wantToRead)
            }
            .padding(.vertical, 14)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(EKitapligimPalette.profileBorder) }
    }

    private func shelfCell(value: Int, label: String, tab: LibraryTab) -> some View {
        Button { onShelfTap(tab) } label: {
            EKStatCell(value: EKitapligimFormat.count(value), label: label)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(EKitapligimPalette.profileBorder)
            .frame(width: 1, height: 28)
    }
}

// MARK: - Okuma özeti ve hedef

private struct ReadingSummaryStrip: View {
    let readingCount: Int
    let finishedCount: Int
    let listedCount: Int

    var body: some View {
        HStack(spacing: 0) {
            cell(value: readingCount, label: L10n.profileSummaryReading)
            divider
            cell(value: finishedCount, label: L10n.profileSummaryRead)
            divider
            cell(value: listedCount, label: L10n.profileSummaryListed)
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(EKitapligimPalette.profileTealSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func cell(value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text(EKitapligimFormat.count(value))
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(EKitapligimPalette.profileTealDeep)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(EKitapligimPalette.profileMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(EKitapligimPalette.profileBorder)
            .frame(width: 1, height: 30)
    }
}

private struct ReadingAchievementCard: View {
    let stats: ReadingStatsDTO
    let onOpenStats: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                EKProgressRing(progress: Double(stats.goalProgressPercent) / 100)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.goalCompleted ? L10n.readingGoalCompletedTitle : L10n.readingGoalTitle)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.profileInk)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.profileMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                EKPill(
                    title: stats.goalCompleted ? L10n.readingGoalDonePill : L10n.readingGoalTodayPill,
                    foreground: stats.goalCompleted ? EKitapligimPalette.successInk : EKitapligimPalette.profileTealDeep,
                    background: stats.goalCompleted ? EKitapligimPalette.successSoft : EKitapligimPalette.profileTealSoft
                )
            }

            HStack(spacing: 0) {
                metric(L10n.readingGoalTotalPages, value: L10n.readingGoalPageCount(stats.totalPages))
                metric(L10n.readingGoalDuration, value: EKitapligimFormat.readingMinutes(stats.totalMinutes))
                metric(L10n.readingGoalStreak, value: L10n.readingGoalDayCount(stats.streakCount))
            }

            Button(L10n.profileActionStats, action: onOpenStats)
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.profileTealDeep)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
    }

    private var subtitle: String {
        stats.goalCompleted
            ? L10n.readingGoalCompletedSubtitle
            : L10n.readingGoalSubtitle(
                done: stats.todayMinutes,
                goal: stats.dailyGoalMinutes,
                remaining: stats.remainingMinutes
            )
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(EKitapligimPalette.profileInk)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(EKitapligimPalette.profileMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Günlük kotalar

private struct DailyLimitSection: View {
    let subscription: SubscriptionDTO?
    let isAdmin: Bool

    var body: some View {
        VStack(spacing: 10) {
            quotaCard(
                quota: subscription?.dailyRead,
                title: isAdmin ? L10n.quotaAdminTitle : L10n.quotaReadTitle,
                adminDetail: L10n.quotaAdminRead,
                systemImage: "book.fill",
                gradient: isAdmin ? EKitapligimPalette.quotaAdminGradient : EKitapligimPalette.quotaReadGradient,
                isRead: true
            )
            quotaCard(
                quota: subscription?.dailyDownload,
                title: isAdmin ? L10n.quotaAdminTitle : L10n.quotaDownloadTitle,
                adminDetail: L10n.quotaAdminDownload,
                systemImage: "arrow.down.circle.fill",
                gradient: isAdmin ? EKitapligimPalette.quotaAdminGradient : EKitapligimPalette.quotaDownloadGradient,
                isRead: false
            )
        }
    }

    private func quotaCard(
        quota: DailyQuotaDTO?,
        title: String,
        adminDetail: String,
        systemImage: String,
        gradient: LinearGradient,
        isRead: Bool
    ) -> some View {
        let used = quota?.used ?? 0
        let limit = quota?.limit ?? 0
        let isUnlimited = isAdmin || (quota?.isUnlimited ?? false)
        let subtitle = isUnlimited
            ? L10n.quotaAdminSubtitle(used: used, detail: adminDetail)
            : (isRead ? L10n.quotaReadSubtitle(used: used, limit: limit) : L10n.quotaDownloadSubtitle(used: used, limit: limit))
        let progress: Double = {
            if isUnlimited { return 0 }
            if limit <= 0 { return 1 }
            return min(max(Double(used) / Double(limit), 0), 1)
        }()

        return EKQuotaCard(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            trailingValue: isUnlimited ? (isAdmin ? L10n.quotaAdminValue : L10n.quotaUnlimitedValue) : String(quota?.remaining ?? 0),
            trailingCaption: isUnlimited ? L10n.quotaActiveCaption : L10n.quotaRemainingCaption,
            progress: progress,
            gradient: gradient,
            isUnlimited: isUnlimited
        )
    }
}

// MARK: - Okumaya devam et

private struct ContinueReadingCard: View {
    let item: LibraryItemDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.continueReadingEyebrow)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.9)
                .foregroundStyle(EKitapligimPalette.profileTealDeep)

            if let item {
                NavigationLink { BookDetailView(bookID: Int(item.bookId) ?? 0) } label: {
                    HStack(spacing: 13) {
                        EKitapligimRemoteCover(urlString: item.coverUrl)
                            .frame(width: 56, height: 82)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title.isEmpty ? L10n.commonBookNumber(item.bookId) : item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.profileInk)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if !item.author.isEmpty {
                                Text(item.author)
                                    .font(.caption)
                                    .foregroundStyle(EKitapligimPalette.profileMuted)
                                    .lineLimit(1)
                            }
                            Text(L10n.continueReadingFromPage(max(item.lastReadPage, 1)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(EKitapligimPalette.profileTealDeep)
                            ProgressView(value: Double(min(max(item.progressPercent, 0), 100)), total: 100)
                                .tint(EKitapligimPalette.profileSuccess)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(EKitapligimPalette.profileTeal)
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.continueReadingEmptyTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.profileInk)
                    Text(L10n.continueReadingEmptySubtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.profileMuted)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
    }
}

// MARK: - Premium kart

private struct PremiumMembershipCard: View {
    let subscription: SubscriptionDTO?
    let isPremium: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.headline)
                        .foregroundStyle(EKitapligimPalette.profileGold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPremium ? L10n.premiumCardActiveTitle : L10n.premiumCardUpgradeTitle)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.white)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Text(isPremium ? L10n.premiumCardActiveBadge : L10n.premiumCardBadge)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(EKitapligimPalette.profileGoldDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(EKitapligimPalette.profileGold, in: Capsule())
                }

                HStack(spacing: 8) {
                    benefitPill(L10n.premiumCardReadPerk, systemImage: "book.fill")
                    benefitPill(L10n.premiumCardDownloadPerk, systemImage: "arrow.down.circle.fill")
                    Spacer(minLength: 0)
                    Text(L10n.premiumCardDiscover)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EKitapligimPalette.quotaPremiumGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var detail: String {
        guard isPremium else { return L10n.premiumCardUpgradeSubtitle }
        if let days = subscription?.remainingDays, days > 0 {
            return L10n.premiumCardRemainingDays(days)
        }
        return L10n.premiumCardActiveNote
    }

    private func benefitPill(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            Text(title).font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.white.opacity(0.16), in: Capsule())
    }
}

// MARK: - Metrikler ve üyelik bilgileri

private struct ProfileMetricsRow: View {
    let profile: ProfileDTO?

    var body: some View {
        HStack(spacing: 10) {
            metric(L10n.profileMetricComments, value: profile?.messageCount ?? 0, systemImage: "text.bubble.fill")
            metric(L10n.profileMetricReactions, value: profile?.reactionScore ?? 0, systemImage: "hand.thumbsup.fill")
            metric(L10n.profileMetricPoints, value: profile?.trophyPoints ?? 0, systemImage: "star.fill")
        }
    }

    private func metric(_ label: String, value: Int, systemImage: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.profileTeal)
            Text(EKitapligimFormat.count(value))
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(EKitapligimPalette.profileInk)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(EKitapligimPalette.profileMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .ekitapligimCard(radius: 14)
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileInfoCard: View {
    let profile: ProfileDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.profileInfoTitle)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.profileInk)
                    Text(L10n.profileInfoSubtitle)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.profileMuted)
                }
                Spacer(minLength: 0)
                EKPill(
                    title: L10n.profileInfoActiveBadge,
                    foreground: EKitapligimPalette.successInk,
                    background: EKitapligimPalette.successSoft
                )
            }

            let about = EKitapligimFormat.plainText(profile?.about ?? "")
            if !about.isEmpty {
                EKInfoRow(label: L10n.profileInfoAbout, value: about, systemImage: "person.text.rectangle")
            }
            if let location = profile?.location, !location.isEmpty {
                EKInfoRow(label: L10n.profileInfoLocation, value: location, systemImage: "mappin.and.ellipse")
            }
            if let website = profile?.website, !website.isEmpty {
                EKInfoRow(label: L10n.profileInfoWebsite, value: website, systemImage: "link")
            }
            if let joined = EKitapligimFormat.date(profile?.registerDate ?? 0) {
                EKInfoRow(label: L10n.profileInfoRegisterDate, value: joined, systemImage: "calendar")
            }
            if let seen = EKitapligimFormat.date(profile?.lastActivity ?? 0) {
                EKInfoRow(label: L10n.profileInfoLastActivity, value: seen, systemImage: "clock")
            }
            EKInfoRow(
                label: L10n.profileInfoOnlineStatus,
                value: (profile?.activityVisible ?? true) ? L10n.profileInfoVisible : L10n.profileInfoHidden,
                systemImage: "eye"
            )
            EKInfoRow(
                label: L10n.profileMemberGroup,
                value: profile?.role?.roleLabel.isEmpty == false ? (profile?.role?.roleLabel ?? "") : L10n.profileMemberFallbackGroup,
                systemImage: "person.2"
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
    }
}

// MARK: - Sekme içerikleri için ortak parçalar

private struct ProfileSectionHeading: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.profileInk)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProfileEmptyState: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(EKitapligimPalette.profileMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 16)
            .background(EKitapligimPalette.profileSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LibraryShelfCard: View {
    let title: String
    let count: Int
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(EKitapligimPalette.profileTeal)
                Text(EKitapligimFormat.count(count))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .ekitapligimCard(radius: 15)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileBookRow: View {
    let item: LibraryItemDTO

    var body: some View {
        HStack(spacing: 12) {
            EKitapligimRemoteCover(urlString: item.coverUrl)
                .frame(width: 48, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? L10n.commonBookNumber(item.bookId) : item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !item.author.isEmpty {
                    Text(item.author)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.profileMuted)
                        .lineLimit(1)
                }
                Text(L10n.commonPercent(min(max(item.progressPercent, 0), 100)))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.profileTealDeep)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.profileTeal)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard(radius: 14)
    }
}

private struct ProfilePostRow: View {
    let post: ForumPostDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                EKPill(title: L10n.profilePostBadge)
                Text(post.threadTitle ?? L10n.profileForumPost)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(EKitapligimFormat.relativeTime(post.postDate))
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
            }
            Text(EKitapligimFormat.plainText(post.message))
                .font(.subheadline)
                .foregroundStyle(EKitapligimPalette.profileInk)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard(radius: 15)
    }
}

private struct ProfileBadgeRow: View {
    let badge: ProfileBadgeDTO

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rosette")
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.amber)
                .frame(width: 42, height: 42)
                .background(EKitapligimPalette.amberSoft)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(badge.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.profileInk)
                Text(badge.description.isEmpty ? L10n.profileBadgeEarnedMessage : badge.description)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let date = EKitapligimFormat.date(badge.awardDate) {
                    Text(L10n.profileBadgeEarnedOn(date))
                        .font(.caption2)
                        .foregroundStyle(EKitapligimPalette.profileMuted)
                }
            }
            Spacer(minLength: 0)
            if badge.points > 0 {
                Text("+\(badge.points)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.profileGoldDeep)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard(radius: 15)
        .accessibilityElement(children: .combine)
    }
}

/// The "Son Aktivite" tab reuses the live-activity feed filtered to this member.
@MainActor
private struct ProfileActivityList: View {
    @EnvironmentObject private var container: AppContainer
    let userID: String?

    @State private var items: [LiveActivityItemDTO] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 10) {
            if isLoading && items.isEmpty {
                EKSkeletonCard(height: 66)
                EKSkeletonCard(height: 66)
            } else if items.isEmpty {
                ProfileEmptyState(message: L10n.profileActivityEmpty)
            } else {
                ForEach(items) { item in
                    LiveActivityRow(item: item)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let userID, !userID.isEmpty, items.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        items = (try? await container.liveActivity.activity(limit: 12, userID: userID).items) ?? []
    }
}

// MARK: - Misafir görünümü

private struct GuestProfilePrompt: View {
    let onLogin: () -> Void

    private let benefits: [(String, String)] = [
        (L10n.profileGuestShelfSync, "arrow.triangle.2.circlepath"),
        (L10n.profileGuestLimits, "gauge.with.needle"),
        (L10n.profileGuestFavorites, "heart.fill"),
        (L10n.profileGuestSecure, "lock.shield.fill")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    EKitapligimBrandLogo().frame(width: 190, height: 78)
                    Text(L10n.profileGuestTitle)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(L10n.profileGuestSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(EKitapligimPalette.profileHeroGradient)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(benefits, id: \.0) { benefit in
                        VStack(spacing: 7) {
                            Image(systemName: benefit.1)
                                .font(.subheadline)
                                .foregroundStyle(EKitapligimPalette.profileTeal)
                            Text(benefit.0)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(EKitapligimPalette.profileInk)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .ekitapligimCard(radius: 15)
                    }
                }

                Button(action: onLogin) {
                    Text(L10n.commonLogin)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(EKitapligimPalette.profileTealDeep)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Text(L10n.profileGuestFooter)
                    .font(.caption2)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }
}
