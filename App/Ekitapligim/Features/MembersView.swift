import SwiftUI
import EkitapligimCore

@MainActor
struct MembersView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var members: [MemberDTO] = []
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var sort = "alphabetical"
    @State private var currentPage = 0
    @State private var lastPage = 1
    @State private var total = 0
    @State private var isLoading = true
    @State private var loadGeneration = UUID()
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                CommunityHero(eyebrow: CommunityDesignL10n.text("members.eyebrow"),
                              title: CommunityDesignL10n.text("members.hero"),
                              subtitle: CommunityDesignL10n.text("members.subtitle"),
                              badge: total > 0 ? L10n.membersTotalLabel + ": " + EKitapligimFormat.count(total) : nil,
                              minHeight: 240)
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(CommunityStyle.teal).accessibilityHidden(true)
                    TextField(L10n.membersSearchPrompt, text: $query)
                        .focused($searchFocused).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.search).onSubmit { searchFocused = false }
                        .accessibilityIdentifier("members.search")
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                        }.accessibilityLabel(CommunityDesignL10n.text("members.clearSearch"))
                            .accessibilityIdentifier("members.clearSearch")
                    }
                }
                .padding(.horizontal, 16).frame(minHeight: 54)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(CommunityStyle.border) }
                Text(CommunityDesignL10n.text("members.discover"))
                    .font(.system(.title2, design: .serif).bold()).foregroundStyle(CommunityStyle.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        sortChip(L10n.membersSortAlphabetical, value: "alphabetical")
                        sortChip(L10n.membersSortNewest, value: "newest")
                        sortChip(L10n.membersSortActive, value: "active")
                    }
                }
                if isLoading && members.isEmpty {
                    ProgressView(L10n.membersLoading).frame(maxWidth: .infinity).padding(22)
                } else if let errorMessage, members.isEmpty {
                    EKErrorState(title: L10n.membersUnavailableTitle, message: errorMessage) {
                        Task { await load(reset: true) }
                    }
                } else if members.isEmpty {
                    EKEmptyState(title: L10n.membersEmptyTitle, message: L10n.membersEmptyDescription, systemImage: "person.3")
                } else {
                    ForEach(members) { member in
                        NavigationLink { MemberProfileView(memberID: member.id) } label: { MemberRow(member: member) }
                            .buttonStyle(.plain).accessibilityIdentifier("members.member.\(member.id)")
                    }
                }
                if let errorMessage, !members.isEmpty { EKInlineError(message: errorMessage) }
                if currentPage < lastPage {
                    EKLoadMoreButton(isLoading: isLoading) { Task { await load(reset: false) } }
                }
            }
            .frame(maxWidth: 760).padding(18).frame(maxWidth: .infinity)
        }
        .background(CommunityStyle.page.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L10n.membersTitle).navigationBarTitleDisplayMode(.inline)
        .task(id: sort + "|" + query + "|" + container.sessionRevision.uuidString) {
            if !query.isEmpty {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            }
            await load(reset: true)
        }
        .refreshable { await load(reset: true) }
    }

    private func sortChip(_ title: String, value: String) -> some View {
        Button { sort = value } label: {
            Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal, 17).padding(.vertical, 13)
                .frame(minHeight: 44).foregroundStyle(sort == value ? .white : CommunityStyle.muted)
                .background(sort == value ? CommunityStyle.ink : .white, in: Capsule())
                .overlay { Capsule().strokeBorder(sort == value ? .clear : CommunityStyle.border) }
        }.buttonStyle(.plain).accessibilityAddTraits(sort == value ? .isSelected : [])
            .accessibilityIdentifier("members.sort.\(value)")
    }

    private func load(reset: Bool) async {
        guard reset || !isLoading else { return }
        let generation = UUID()
        loadGeneration = generation
        isLoading = true
        errorMessage = nil
        defer { if loadGeneration == generation { isLoading = false } }
        do {
            let result = try await container.members.members(
                page: reset ? 1 : currentPage + 1,
                query: query.trimmed.nilIfEmpty,
                sort: sort
            )
            guard loadGeneration == generation, !Task.isCancelled else { return }
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
            guard loadGeneration == generation, !Task.isCancelled else { return }
            errorMessage = L10n.membersLoadFailed
        }
    }
}

@MainActor
private struct MemberRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let member: MemberDTO

    var body: some View {
        (dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))) {
            CommunityMemberAvatar(member: member, size: 58)
            VStack(alignment: .leading, spacing: 8) {
                PremiumMemberName(username: member.username, isPremium: member.isPremium)
                    .font(.headline.weight(.bold)).foregroundStyle(CommunityStyle.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if member.isPremium {
                    PremiumMemberPill()
                }
                if !member.isPremium || member.isStaff || ["admin", "moderator"].contains(member.roleType) {
                    Text(member.roleLabel.isEmpty ? (member.userTitle.isEmpty ? CommunityDesignL10n.text("member.role") : member.userTitle) : member.roleLabel)
                    .font(.caption.weight(.semibold)).foregroundStyle(CommunityStyle.muted)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(CommunityStyle.soft, in: Capsule())
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { counts }
                    VStack(alignment: .leading, spacing: 4) { counts }
                }.font(.caption).foregroundStyle(CommunityStyle.muted)
                if member.isOnline {
                    Text(L10n.profileOnline).font(.caption2.weight(.semibold)).foregroundStyle(CommunityStyle.teal)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "arrow.right").foregroundStyle(CommunityStyle.teal.opacity(0.6)).accessibilityHidden(true)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(CommunityStyle.border) }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var counts: some View {
        Text(L10n.membersMessageCount(member.messageCount))
        Label(EKitapligimFormat.count(member.reactionScore), systemImage: "heart")
            .accessibilityLabel(L10n.membersReactionsLabel + ": " + EKitapligimFormat.count(member.reactionScore))
    }
}

struct CommunityMemberAvatar: View {
    let member: MemberDTO
    let size: CGFloat
    @ViewBuilder
    var body: some View {
        if member.isPremium {
            PremiumAvatarFrame(size: size + 10) { diameter in
                EKAvatar(urlString: member.avatarUrl, username: member.username, size: diameter,
                    background: CommunityStyle.soft, foreground: CommunityStyle.teal)
            }
        } else {
            EKAvatar(urlString: member.avatarUrl, username: member.username, size: size,
                 background: CommunityStyle.soft, foreground: CommunityStyle.teal)
            .padding(5).background(.white, in: Circle())
            .overlay { Circle().strokeBorder(LinearGradient(colors: [Color(hex: 0xE5D6AB), Color(hex: 0xBBD9CD)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3) }
            .overlay(alignment: .bottomTrailing) {
                if member.showVerifiedBadge {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(CommunityStyle.teal)
                        .background(.white, in: Circle()).accessibilityLabel(L10n.membersVerified)
                }
            }
        }
    }
}

@MainActor
struct MemberProfileView: View {
    @EnvironmentObject private var container: AppContainer
    let memberID: String
    var body: some View {
        MemberProfileContentView(memberID: memberID)
            .id(memberID + "|" + container.sessionRevision.uuidString)
    }
}

@MainActor
private struct MemberProfileContentView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                            if isSignedIn && (profile.member.canFollow || profile.member.isFollowed || profile.canConverse || profile.member.canConverse) {
                                actionBar(profile)
                            }
                            memberHero(profile)
                            statsBand(profile)
                            sectionTabs
                            sectionContent(profile)
                        }
                        .frame(maxWidth: 760).padding(18).frame(maxWidth: .infinity)
                    }
                    .background(CommunityStyle.page.ignoresSafeArea())
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
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))) {
                if profile.member.canFollow || profile.member.isFollowed {
                    Button {
                        Task { await toggleFollow(profile) }
                    } label: {
                        Label(
                            profile.member.isFollowed ? L10n.membersUnfollow : L10n.membersFollow,
                            systemImage: profile.member.isFollowed ? "person.badge.minus" : "person.badge.plus"
                        )
                        .font(.subheadline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .frame(minHeight: 48).background(CommunityStyle.ink, in: RoundedRectangle(cornerRadius: 16))
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
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(CommunityStyle.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12).frame(minHeight: 48)
                            .background(CommunityStyle.soft, in: RoundedRectangle(cornerRadius: 16))
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
    }

    private func memberHero(_ profile: MemberProfileDTO) -> some View {
        let member = profile.member
        return CommunityCard(padding: 0) {
            VStack(spacing: 0) {
                Label(CommunityDesignL10n.text("member.eyebrow"), systemImage: "book.pages")
                    .font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(Color(hex: 0xE5D6AB))
                    .padding(22).frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
                    .background {
                        GeometryReader { geometry in
                            Image("agenda_reader_community").resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                                .overlay(CommunityStyle.ink.opacity(0.58))
                        }.accessibilityHidden(true)
                    }
                VStack(spacing: 14) {
                    CommunityMemberAvatar(member: member, size: 96).padding(.top, -48)
                    PremiumMemberName(username: member.username, isPremium: member.isPremium)
                        .font(.system(.largeTitle, design: .serif).bold())
                        .foregroundStyle(CommunityStyle.ink).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("member.username")
                    if member.isPremium {
                        PremiumMemberPill()
                    }
                    if !member.isPremium || member.isStaff || ["admin", "moderator"].contains(member.roleType) {
                        Text(member.roleLabel.isEmpty ? (member.userTitle.isEmpty ? CommunityDesignL10n.text("member.role") : member.userTitle) : member.roleLabel)
                        .font(.caption.weight(.semibold)).foregroundStyle(CommunityStyle.muted)
                        .padding(.horizontal, 12).padding(.vertical, 6).background(CommunityStyle.soft, in: Capsule())
                    }
                    if member.isOnline { memberChip(L10n.profileOnline) }
                    if member.isFollowed { memberChip(L10n.membersFollowingBadge) }
                    if profile.isIgnored || isBlocked { memberChip(L10n.membersBlockedBadge) }
                    if let joined = EKitapligimFormat.date(member.registerDate) {
                        heroFootnote(L10n.profileJoinedOn(joined), systemImage: "calendar")
                    }
                    if let seen = EKitapligimFormat.date(member.lastActivity) {
                        heroFootnote(L10n.profileLastSeen(seen), systemImage: "clock")
                    }
                }.padding(.horizontal, 20).padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private func memberChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.heavy))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(CommunityStyle.teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(CommunityStyle.soft, in: RoundedRectangle(cornerRadius: dynamicTypeSize.isAccessibilitySize ? 10 : 999))
    }

    private func heroFootnote(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 9))
            Text(text).font(.caption2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CommunityStyle.muted)
    }

    private func statsBand(_ profile: MemberProfileDTO) -> some View {
        CommunityCard {
            VStack(spacing: 17) {
                (dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 18))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) {
                    memberStat(profile.readingCount, label: L10n.membersStatReading)
                    memberStat(profile.readCount, label: L10n.membersStatRead)
                    memberStat(profile.listedCount, label: L10n.membersStatListed)
                }
                Divider().overlay(CommunityStyle.border)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { memberForumStats(profile.member) }
                    VStack(alignment: .leading, spacing: 8) { memberForumStats(profile.member) }
                }.font(.caption).foregroundStyle(CommunityStyle.muted)
            }
        }
    }

    private func memberStat(_ count: Int, label: String) -> some View {
        VStack(spacing: 7) {
            Text(EKitapligimFormat.count(count)).font(.system(.largeTitle, design: .serif).bold())
                .foregroundStyle(CommunityStyle.ink)
            Text(label).font(.caption).foregroundStyle(CommunityStyle.muted)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }

    @ViewBuilder private func memberForumStats(_ member: MemberDTO) -> some View {
        Text(L10n.membersMessageCount(member.messageCount))
        Label(EKitapligimFormat.count(member.reactionScore), systemImage: "heart")
            .accessibilityLabel(L10n.membersReactionsLabel + ": " + EKitapligimFormat.count(member.reactionScore))
    }

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(MemberProfileSection.allCases) { item in
                    Button { section = item } label: {
                        Text(item.title).font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 17).padding(.vertical, 13).frame(minHeight: 44)
                            .foregroundStyle(section == item ? .white : CommunityStyle.muted)
                            .background(section == item ? CommunityStyle.ink : .white, in: Capsule())
                            .overlay { Capsule().strokeBorder(section == item ? .clear : CommunityStyle.border) }
                    }.buttonStyle(.plain).accessibilityAddTraits(section == item ? .isSelected : [])
                        .accessibilityIdentifier("member.tab.\(item.rawValue)")
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
            Text(L10n.membersLastReadTitle.uppercased(with: Locale(identifier: "tr_TR")))
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(EKitapligimPalette.profileTealDeep)

            if let book = profile.lastReadBook, !book.bookId.isEmpty {
                NavigationLink { BookDetailDestination(bookIDString: book.bookId) } label: {
                    HStack(spacing: 13) {
                        EKitapligimRemoteCover(urlString: book.coverUrl, title: book.title, author: book.author)
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
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
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
                ScrollView {
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
        let visitingAccount = container.audioAccount
        let revision = container.sessionRevision
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await container.members.memberProfile(id: memberID)
            guard revision == container.sessionRevision, !Task.isCancelled else { return }
            profile = result
            if isSignedIn, container.audioAccount == visitingAccount, let id = Int(memberID) {
                _ = await container.profileVisitRecorder?.record(memberID: id, account: visitingAccount)
            }
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
        guard !isSendingMessage else { return }
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
