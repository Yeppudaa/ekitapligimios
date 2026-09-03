import SwiftUI
import EkitapligimCore

@MainActor
struct MembersView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var members: [MemberDTO] = []
    @State private var query = ""
    @State private var sort = "alphabetical"
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var total = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        EKitapligimScreen {
            Group {
                if isLoading && members.isEmpty {
                    EKLoadingState(message: L10n.membersLoading)
                } else if let errorMessage, members.isEmpty {
                    EKErrorState(title: L10n.membersUnavailableTitle, message: errorMessage) {
                        Task { await load(reset: true) }
                    }
                } else if members.isEmpty {
                    EKEmptyState(title: L10n.membersEmptyTitle, message: L10n.membersEmptyDescription, systemImage: "person.3")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            membersHeader
                            ForEach(members) { member in
                                NavigationLink {
                                    MemberProfileView(memberID: member.id)
                                } label: {
                                    MemberRow(member: member)
                                }
                                .buttonStyle(.plain)
                            }
                            if currentPage < lastPage {
                                EKLoadMoreButton(isLoading: isLoading) {
                                    Task { await load(reset: false) }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle(L10n.membersTitle)
        .searchable(text: $query, prompt: L10n.membersSearchPrompt)
        .onSubmit(of: .search) { Task { await load(reset: true) } }
        .task { await load(reset: true) }
    }

    private var membersHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.membersTitle)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.ink)
                    Text(L10n.membersTotalLabel)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                }
                Spacer()
                Text("\(total)")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.tealDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(EKitapligimPalette.tealSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Picker(L10n.membersSortLabel, selection: $sort) {
                Text(L10n.membersSortAlphabetical).tag("alphabetical")
                Text(L10n.membersSortNewest).tag("newest")
                Text(L10n.membersSortActive).tag("active")
            }
            .pickerStyle(.segmented)
            .onChange(of: sort) { _, _ in Task { await load(reset: true) } }
        }
        .padding(16)
        .ekitapligimCard(radius: 16)
    }

    private func load(reset: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await container.members.members(
                page: reset ? 1 : currentPage + 1,
                query: query.trimmed.nilIfEmpty,
                sort: sort
            )
            members = reset ? result.members : members + result.members.filter { item in
                !members.contains(where: { $0.id == item.id })
            }
            members = members.filter { member in
                guard let id = Int(member.id) else { return true }
                return !container.blockedUserIDs.contains(id)
            }
            currentPage = result.currentPage
            lastPage = result.lastPage
            total = result.total
        } catch {
            errorMessage = L10n.membersLoadFailed
        }
    }
}

@MainActor
private struct MemberRow: View {
    let member: MemberDTO

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: member.avatarUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(EKitapligimPalette.muted)
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: 0xE0EAEB), lineWidth: 1))
                .accessibilityHidden(true)

                if member.showVerifiedBadge {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.teal)
                        .background(Circle().fill(.white).padding(-2))
                        .accessibilityLabel(L10n.membersVerified)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(member.username)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .lineLimit(1)
                Text(member.roleLabel.isEmpty ? member.userTitle : member.roleLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.tealDark)
                    .lineLimit(1)
                if !member.about.isEmpty {
                    Text(member.about)
                        .font(.caption)
                        .foregroundStyle(EKitapligimPalette.muted)
                        .lineLimit(2)
                }
                Text(L10n.membersMessageCount(member.messageCount))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(EKitapligimPalette.muted)
        }
        .padding(14)
        .ekitapligimCard(radius: 16)
    }
}

@MainActor
struct MemberProfileView: View {
    @EnvironmentObject private var container: AppContainer
    let memberID: String

    @State private var profile: MemberProfileDTO?
    @State private var section: MemberProfileSection = .profile
    @State private var isLoading = true
    @State private var isActing = false
    @State private var errorMessage: String?
    @State private var operationError: String?
    @State private var showBlockConfirmation = false
    @State private var showUnblockConfirmation = false
    @State private var showBlockAndReport = false
    @State private var showMessageSheet = false
    @State private var showLogin = false
    @State private var blockCompleted = false
    @State private var unblockCompleted = false
    @State private var messageDraft = ""
    @State private var isSendingMessage = false
    @State private var createdConversationRoute: MemberConversationRoute?

    private var isSignedIn: Bool { container.isSignedIn }
    private var isOwnProfile: Bool { container.profileState?.id == memberID }

    var body: some View {
        Group {
            if isOwnProfile {
                ProfileView()
            } else {
                memberContent
            }
        }
        .navigationTitle(profile?.member.username ?? L10n.membersProfileTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $createdConversationRoute) { route in
            ConversationDetailView(conversationID: route.id)
        }
        .task { await load() }
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showMessageSheet) { messageComposeSheet }
        .confirmationDialog(L10n.membersBlockConfirmation, isPresented: $showBlockConfirmation, titleVisibility: .visible) {
            Button(L10n.membersBlock, role: .destructive) { Task { await block() } }
            Button(L10n.commonCancel, role: .cancel) {}
        }
        .confirmationDialog(L10n.membersUnblockConfirmation, isPresented: $showUnblockConfirmation, titleVisibility: .visible) {
            Button(L10n.membersUnblock) { Task { await unblock() } }
            Button(L10n.commonCancel, role: .cancel) {}
        }
        .sheet(isPresented: $showBlockAndReport) {
            if let userID = Int(memberID) {
                ReportContentView(kind: .memberBlock(userID: userID)) { success in
                    if success { blockCompleted = true }
                }
            }
        }
        .alert(L10n.membersBlockCompleted, isPresented: $blockCompleted) {
            Button(L10n.commonClose) {}
        }
        .alert(L10n.membersUnblockCompleted, isPresented: $unblockCompleted) {
            Button(L10n.commonClose) {}
        }
        .alert(
            L10n.membersActionFailed,
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button(L10n.commonClose) { operationError = nil }
        } message: {
            Text(operationError ?? L10n.membersActionFailed)
        }
    }

    private var memberContent: some View {
        EKitapligimScreen {
            Group {
                if isLoading && profile == nil {
                    EKLoadingState(message: L10n.membersProfileLoading)
                } else if let errorMessage, profile == nil {
                    EKErrorState(title: L10n.membersUnavailableTitle, message: errorMessage) {
                        Task { await load() }
                    }
                } else if let profile {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if isSignedIn {
                                actionBar(profile)
                            }
                            memberHero(profile)
                            statsBand(profile)
                            sectionTabs
                            sectionContent(profile)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                    .refreshable { await load() }
                } else {
                    EKErrorState(title: L10n.membersProfileLoadFailed, message: nil) {
                        Task { await load() }
                    }
                }
            }
        }
    }

    private func actionBar(_ profile: MemberProfileDTO) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if profile.member.canFollow || profile.member.isFollowed {
                    Button {
                        Task { await toggleFollow(profile) }
                    } label: {
                        Label(
                            profile.member.isFollowed ? L10n.membersUnfollow : L10n.membersFollow,
                            systemImage: profile.member.isFollowed ? "person.badge.minus" : "person.badge.plus"
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(EKitapligimPalette.teal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isActing)
                }

                if profile.canConverse || profile.member.canConverse {
                    Button {
                        if isSignedIn {
                            showMessageSheet = true
                        } else {
                            showLogin = true
                        }
                    } label: {
                        Label(L10n.membersSendMessage, systemImage: "envelope.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(EKitapligimPalette.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !isSignedIn {
                Text(L10n.membersLoginForActions)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(14)
        .ekitapligimCard(radius: 16)
    }

    private func memberHero(_ profile: MemberProfileDTO) -> some View {
        let member = profile.member
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                EKitapligimPalette.profileBannerGradient
                EKitapligimPalette.profileHeroGradient.opacity(0.35)
            }
            .frame(height: 84)
            .clipped()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 13) {
                    EKAvatar(
                        urlString: member.avatarUrl,
                        username: member.username,
                        size: 76,
                        background: .white.opacity(0.16),
                        foreground: .white
                    )
                    .overlay { Circle().stroke(.white.opacity(0.6), lineWidth: 2) }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(member.username)
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if member.showVerifiedBadge {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.footnote)
                                    .foregroundStyle(EKitapligimPalette.profileGold)
                            }
                        }
                        Text(member.roleLabel.isEmpty ? member.userTitle : member.roleLabel)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                        HStack(spacing: 7) {
                            if member.isFollowed {
                                memberChip(L10n.membersFollowingBadge)
                            }
                            if profile.isIgnored {
                                memberChip(L10n.membersBlockedBadge)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }

                if member.registerDate > 0 || member.lastActivity > 0 {
                    HStack(spacing: 16) {
                        if let joined = EKitapligimFormat.date(member.registerDate) {
                            heroFootnote(L10n.profileJoinedOn(joined), systemImage: "calendar")
                        }
                        if let seen = EKitapligimFormat.date(member.lastActivity) {
                            heroFootnote(L10n.profileLastSeen(seen), systemImage: "clock")
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(16)
        }
        .background(EKitapligimPalette.profileHeroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func memberChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(EKitapligimPalette.profileGold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.13), in: Capsule())
    }

    private func heroFootnote(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 9))
            Text(text).font(.system(size: 10))
        }
        .foregroundStyle(.white.opacity(0.75))
        .lineLimit(1)
    }

    private func statsBand(_ profile: MemberProfileDTO) -> some View {
        let member = profile.member
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                EKStatCell(value: EKitapligimFormat.count(member.messageCount), label: L10n.membersMessagesLabel)
                statsDivider
                EKStatCell(value: EKitapligimFormat.count(member.reactionScore), label: L10n.membersReactionsLabel)
                statsDivider
                EKStatCell(value: EKitapligimFormat.count(profile.readingCount), label: L10n.membersStatReading)
                statsDivider
                EKStatCell(value: EKitapligimFormat.count(profile.readCount), label: L10n.membersStatRead)
                statsDivider
                EKStatCell(value: EKitapligimFormat.count(profile.listedCount), label: L10n.membersStatListed)
            }
            .padding(.vertical, 14)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(EKitapligimPalette.profileBorder) }
    }

    private var statsDivider: some View {
        Rectangle()
            .fill(EKitapligimPalette.profileBorder)
            .frame(width: 1, height: 28)
    }

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(MemberProfileSection.allCases) { item in
                    EKChip(title: item.title, isSelected: section == item) {
                        section = item
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder private func sectionContent(_ profile: MemberProfileDTO) -> some View {
        switch section {
        case .profile: profileSection(profile)
        case .library: librarySection(profile)
        case .about: aboutSection(profile)
        case .activity: activitySection
        }
    }

    private func profileSection(_ profile: MemberProfileDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            lastReadCard(profile)
            shelfOverview(profile)
            recentBooks(profile)
            if isSignedIn {
                safetyActions(profile)
            }
        }
    }

    private func lastReadCard(_ profile: MemberProfileDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.membersLastReadTitle.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(EKitapligimPalette.profileTealDeep)

            if let book = profile.lastReadBook, !book.bookId.isEmpty {
                NavigationLink { BookDetailDestination(bookIDString: book.bookId) } label: {
                    HStack(spacing: 13) {
                        EKitapligimRemoteCover(urlString: book.coverUrl)
                            .frame(width: 56, height: 82)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(book.title.isEmpty ? L10n.commonBookNumber(book.bookId) : book.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(EKitapligimPalette.profileInk)
                                .lineLimit(2)
                            if !book.author.isEmpty {
                                Text(book.author)
                                    .font(.caption)
                                    .foregroundStyle(EKitapligimPalette.profileMuted)
                            }
                            Text(L10n.continueReadingFromPage(max(book.lastReadPage, 1)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(EKitapligimPalette.profileTealDeep)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(EKitapligimPalette.profileTeal)
                    }
                }
                .buttonStyle(.plain)
            } else {
                ProfileEmptyState(message: L10n.membersNoSharedBooks)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ekitapligimCard()
    }

    private func shelfOverview(_ profile: MemberProfileDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeading(title: L10n.membersShelvesTitle, subtitle: nil)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                LibraryShelfCard(title: L10n.profileStatReading, count: profile.readingCount, systemImage: "book.pages.fill") {
                    section = .library
                }
                LibraryShelfCard(title: L10n.profileStatRead, count: profile.readCount, systemImage: "checkmark.seal.fill") {
                    section = .library
                }
                LibraryShelfCard(title: L10n.profileReadingList, count: profile.wantToReadCount, systemImage: "bookmark.fill") {
                    section = .library
                }
                LibraryShelfCard(title: L10n.libraryTabFavorites, count: profile.favoriteCount, systemImage: "heart.fill") {
                    section = .library
                }
            }
        }
    }

    private func recentBooks(_ profile: MemberProfileDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeading(title: L10n.membersRecentBooksTitle, subtitle: nil)
            let books = Array(profile.library.prefix(8))
            if books.isEmpty {
                ProfileEmptyState(message: L10n.membersNoSharedBooks)
            } else {
                ForEach(books, id: \.bookId) { item in
                    NavigationLink { BookDetailDestination(bookIDString: item.bookId) } label: {
                        ProfileBookRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func librarySection(_ profile: MemberProfileDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ProfileSectionHeading(title: L10n.membersTabLibrary, subtitle: nil)

            if !profile.canViewProfile && !profile.hasPublicLibrarySnapshot {
                ProfileEmptyState(message: L10n.membersLibraryHidden)
            } else {
                memberShelfSection(profile, state: "OKUYORUM", title: L10n.membersShelfReading)
                memberShelfSection(profile, state: "OKUDUM", title: L10n.membersShelfFinished)
                memberShelfSection(profile, state: "OKUYACAGIM", title: L10n.membersShelfWantToRead)
                memberShelfSection(profile, state: "FAVORI", title: L10n.membersShelfFavorites, favoritesOnly: true)
            }
        }
    }

    private func memberShelfSection(
        _ profile: MemberProfileDTO,
        state: String,
        title: String,
        favoritesOnly: Bool = false
    ) -> some View {
        let books = profile.library.filter { item in
            favoritesOnly ? item.isFavorite : item.shelfState == state || (state == "FAVORI" && item.isFavorite)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(EKitapligimPalette.profileInk)
            if books.isEmpty {
                Text(L10n.membersShelfEmpty)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.profileMuted)
            } else {
                ForEach(books.prefix(12), id: \.bookId) { item in
                    NavigationLink { BookDetailDestination(bookIDString: item.bookId) } label: {
                        ProfileBookRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func aboutSection(_ profile: MemberProfileDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeading(title: L10n.membersAboutSection, subtitle: nil)
            let about = EKitapligimFormat.plainText(profile.member.about)
            if about.isEmpty && profile.member.location.isEmpty && profile.member.website.isEmpty {
                ProfileEmptyState(message: L10n.profileAboutEmpty)
            } else {
                if !about.isEmpty {
                    Text(about)
                        .font(.subheadline)
                        .foregroundStyle(EKitapligimPalette.profileInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .ekitapligimCard()
                }
                if !profile.member.location.isEmpty {
                    EKInfoRow(label: L10n.profileInfoLocation, value: profile.member.location, systemImage: "mappin.and.ellipse")
                        .padding(16)
                        .ekitapligimCard()
                }
                if !profile.member.website.isEmpty {
                    EKInfoRow(label: L10n.profileInfoWebsite, value: profile.member.website, systemImage: "link")
                        .padding(16)
                        .ekitapligimCard()
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeading(title: L10n.membersTabActivity, subtitle: L10n.profileTabActivitySubtitle)
            ProfileActivityList(userID: memberID)
        }
    }

    private func safetyActions(_ profile: MemberProfileDTO) -> some View {
        VStack(spacing: 10) {
            if isBlocked {
                Button(L10n.membersUnblock) { showUnblockConfirmation = true }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EKitapligimPalette.tealDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(EKitapligimPalette.tealSoft, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(isActing)
            } else {
                Button(L10n.membersBlockAndReport) { showBlockAndReport = true }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(EKitapligimPalette.danger, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(isActing)

                Button(L10n.membersBlock) { showBlockConfirmation = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .disabled(isActing)
            }
        }
        .padding(16)
        .ekitapligimCard(radius: 14)
    }

    private var messageComposeSheet: some View {
        NavigationStack {
            EKitapligimScreen {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.membersMessagePrompt)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EKitapligimPalette.muted)
                    TextEditor(text: $messageDraft)
                        .accessibilityLabel(L10n.membersMessagePrompt)
                        .frame(minHeight: 140)
                        .padding(10)
                        .ekitapligimCard(radius: 14)
                    Button {
                        Task { await sendMessage() }
                    } label: {
                        Text(isSendingMessage ? L10n.commonLoading : L10n.membersSendMessage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(EKitapligimPalette.teal, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSendingMessage || messageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(18)
            }
            .navigationTitle(L10n.membersSendMessage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { showMessageSheet = false }
                }
            }
        }
    }

    private var isBlocked: Bool {
        Int(memberID).map(container.blockedUserIDs.contains) == true
    }

    private func load() async {
        guard !isOwnProfile else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            profile = try await container.members.memberProfile(id: memberID)
        } catch {
            errorMessage = L10n.membersProfileLoadFailed
        }
    }

    private func toggleFollow(_ current: MemberProfileDTO) async {
        guard !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            let result = current.member.isFollowed
                ? try await container.members.unfollow(id: current.member.id)
                : try await container.members.follow(id: current.member.id)
            if var updated = profile {
                updated = MemberProfileDTO(
                    member: result.member,
                    library: updated.library,
                    lastReadBook: updated.lastReadBook,
                    readingCount: updated.readingCount,
                    readCount: updated.readCount,
                    wantToReadCount: updated.wantToReadCount,
                    favoriteCount: updated.favoriteCount,
                    listedCount: updated.listedCount,
                    canViewProfile: updated.canViewProfile,
                    canConverse: updated.canConverse,
                    isIgnored: updated.isIgnored,
                    canBlock: updated.canBlock,
                    canUnblock: updated.canUnblock
                )
                profile = updated
            }
        } catch {
            operationError = L10n.membersActionFailed
        }
    }

    private func block() async {
        guard let userID = Int(memberID), !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            _ = try await container.safety.blockMember(userID: userID)
            container.rememberBlockedUser(userID)
            blockCompleted = true
        } catch {
            operationError = L10n.membersActionFailed
        }
    }

    private func unblock() async {
        guard let userID = Int(memberID), !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            _ = try await container.safety.unblockMember(userID: userID)
            container.forgetBlockedUser(userID)
            unblockCompleted = true
        } catch {
            operationError = L10n.membersActionFailed
        }
    }

    private func sendMessage() async {
        guard let username = profile?.member.username, !username.isEmpty else { return }
        let body = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isSendingMessage = true
        defer { isSendingMessage = false }
        do {
            let result = try await container.conversations.create(
                recipient: username,
                title: L10n.conversationsNew,
                message: body
            )
            showMessageSheet = false
            messageDraft = ""
            createdConversationRoute = MemberConversationRoute(id: result.conversation.id)
        } catch {
            operationError = L10n.membersMessageFailed
        }
    }
}

private struct MemberConversationRoute: Identifiable, Hashable {
    let id: String
}

private enum MemberProfileSection: String, CaseIterable, Identifiable {
    case profile, library, about, activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: L10n.membersTabProfile
        case .library: L10n.membersTabLibrary
        case .about: L10n.membersTabAbout
        case .activity: L10n.membersTabActivity
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
