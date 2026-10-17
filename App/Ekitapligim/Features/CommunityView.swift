import SwiftUI
import EkitapligimCore

@MainActor
struct CommunityView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var showingBlockUser = false
    @State private var forums: [ForumDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var query = ""

    private var visibleForums: [ForumDTO] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return search.isEmpty ? forums : forums.filter {
            $0.title.localizedStandardContains(search) || $0.description.localizedStandardContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            EKitapligimScreen {
                Group {
                    if isLoading && forums.isEmpty {
                        EKLoadingState(message: L10n.communityLoading)
                    } else if let errorMessage, forums.isEmpty {
                        EKErrorState(title: L10n.communityUnavailableTitle, message: errorMessage) {
                            Task { await load() }
                        }
                    } else {
                        ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                CommunityLiteraryHero(
                                    artwork: "forum_web_book_club",
                                    eyebrow: CommunityRefreshL10n.text("forum.eyebrow"),
                                    title: CommunityRefreshL10n.text("forum.title"),
                                    emphasis: CommunityRefreshL10n.text("forum.emphasis"),
                                    subtitle: CommunityRefreshL10n.text("forum.subtitle"),
                                    actionTitle: CommunityRefreshL10n.text("forum.browse")
                                ) { withAnimation { proxy.scrollTo("forums", anchor: .top) } }
                                forumIntroduction
                                forumCards
                                    .id("forums")
                                directoryCard
                                safetyCard
                                CommunityInvitationCard(
                                    eyebrow: CommunityRefreshL10n.text("forum.outroEyebrow"),
                                    title: CommunityRefreshL10n.text("forum.outroTitle"),
                                    subtitle: CommunityRefreshL10n.text("forum.outroBody"),
                                    actionTitle: CommunityRefreshL10n.text("forum.outroAction")
                                ) { withAnimation { proxy.scrollTo("forums", anchor: .top) } }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                        }
                        .refreshable { await load() }
                        }
                    }
                }
            }
            .forumPageBackground()
            .navigationTitle(L10n.communityTitle)
            .task { await load() }
            .sheet(isPresented: $showingBlockUser) {
                BlockMemberView()
            }
        }
    }

    private var forumIntroduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CommunityRefreshL10n.text("forum.headingEyebrow"))
                .font(.caption2.weight(.semibold)).tracking(1.2)
                .foregroundStyle(EKitapligimPalette.muted)
            Text(CommunityRefreshL10n.text("forum.heading"))
                .font(.system(.title, design: .serif)).foregroundStyle(EKitapligimPalette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(CommunityRefreshL10n.text("forum.headingBody"))
                .font(.subheadline).foregroundStyle(EKitapligimPalette.muted)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField(CommunityRefreshL10n.text("forum.search"), text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                    }.accessibilityLabel(L10n.commonClose)
                }
            }
            .foregroundStyle(EKitapligimPalette.ink)
            .padding(.horizontal, 14).frame(minHeight: 52)
            .background(EKitapligimPalette.paper, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(EKitapligimPalette.border))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var forumCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage { EKInlineError(message: errorMessage) }
            CommunityScenicBanner(
                artwork: "forum_web_book_club",
                title: CommunityRefreshL10n.text("forum.collection"),
                subtitle: CommunityRefreshL10n.count("forum.count", visibleForums.count)
            )
            if visibleForums.isEmpty {
                EKStateCard(title: L10n.communityForumsSection, message: CommunityRefreshL10n.text("forum.emptySearch"))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
            ForEach(visibleForums) { forum in
                NavigationLink {
                    ForumThreadsView(forum: forum)
                } label: {
                    CommunityForumCard(forum: forum)
                }
                .buttonStyle(.plain)
            }
            }
        }
    }

    private var directoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(EKitapligimPalette.forumTeal)
                    .frame(width: 4, height: 22)
                Text(L10n.communityDirectorySection)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.forumInk)
            }
            NavigationLink {
                MembersView()
            } label: {
                EKForumActionRow(title: L10n.membersTitle, systemImage: "person.3.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(EKitapligimPalette.forumGold)
                    .frame(width: 4, height: 22)
                Text(L10n.communitySafetySection)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.forumInk)
            }
            NavigationLink {
                CommunitySafetyView()
            } label: {
                EKForumActionRow(
                    title: L10n.communitySafetyTitle,
                    systemImage: "shield.checkered",
                    tint: EKitapligimPalette.forumGold
                )
            }
            .buttonStyle(.plain)
            Button { showingBlockUser = true } label: {
                EKForumActionRow(
                    title: L10n.communityBlockUser,
                    systemImage: "person.crop.circle.badge.xmark",
                    tint: Color(hex: 0xC75B5B)
                )
            }
            .buttonStyle(.plain)
            NavigationLink {
                BlockedMembersView()
            } label: {
                EKForumActionRow(
                    title: L10n.communityBlockedUsers,
                    systemImage: "hand.raised.fill",
                    tint: EKitapligimPalette.forumMuted
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            forums = try await container.community.forums().forums
        } catch {
            errorMessage = L10n.communityForumsLoadFailed
        }
    }
}

/// Shared literary treatment uses the exact Android/site artwork and native actions.
struct CommunityLiteraryHero: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicType
    let artwork: String
    var wideArtwork: String? = nil
    var artworkBehindCopy = false
    let eyebrow: String
    let title: String
    let emphasis: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    private let gold = Color(hex: 0xE4CB96)
    private let background = Color(hex: 0x153F48)

    var body: some View {
        Group {
            if artworkBehindCopy {
                HStack {
                    copy.frame(maxWidth: 500, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(sizeClass == .regular ? 28 : 22)
                .frame(maxWidth: .infinity, minHeight: 310, alignment: .leading)
                .background {
                    GeometryReader { geometry in
                        Image(artwork).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            .overlay(LinearGradient(stops: [
                                .init(color: Color(hex: 0x103A3C).opacity(0.98), location: 0),
                                .init(color: Color(hex: 0x103A3C).opacity(0.90), location: 0.42),
                                .init(color: Color(hex: 0x103A3C).opacity(sizeClass == .regular ? 0.18 : 0.48), location: 1)
                            ], startPoint: .leading, endPoint: .trailing))
                            .accessibilityHidden(true)
                    }
                }
            } else if sizeClass == .regular && !dynamicType.isAccessibilitySize {
                HStack(spacing: 0) {
                    copy.padding(28).frame(maxWidth: .infinity, alignment: .leading)
                    artworkView.frame(maxWidth: .infinity, minHeight: 360)
                }
            } else {
                VStack(spacing: 0) {
                    copy.padding(24)
                    artworkView.frame(height: 205)
                }
            }
        }
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(Color(hex: 0x37625E)))
        .accessibilityElement(children: .contain)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(eyebrow, systemImage: "sparkle")
                .font(.caption2.weight(.semibold)).tracking(0.8)
                .foregroundStyle(gold)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .overlay(Capsule().stroke(gold.opacity(0.35)))
            VStack(alignment: .leading, spacing: 0) {
                Text(title).foregroundStyle(Color(hex: 0xFFFAF0))
                Text(emphasis).italic().foregroundStyle(gold)
            }
            .font(.system(.largeTitle, design: .serif))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.subheadline).foregroundStyle(Color(hex: 0xD3E2DC))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            Button(action: action) {
                HStack {
                    Text(actionTitle).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 10)
                    Image(systemName: "arrow.down")
                }
                .foregroundStyle(background)
                .padding(.horizontal, 16).padding(.vertical, 13)
                .frame(minHeight: 48)
                .background(gold, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var artworkView: some View {
        GeometryReader { geometry in
            Image(sizeClass == .regular ? (wideArtwork ?? artwork) : artwork)
                .resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(alignment: .top) {
                    LinearGradient(colors: [background, background.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 90)
                }
        }
        .accessibilityHidden(true)
    }
}

struct CommunityInvitationCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(eyebrow).font(.caption2.weight(.semibold)).tracking(1)
                .foregroundStyle(Color(hex: 0xD1C391))
            Text(title).font(.system(.title, design: .serif)).foregroundStyle(Color(hex: 0xFFFAF0))
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            if !subtitle.isEmpty {
                Text(subtitle).font(.subheadline).foregroundStyle(Color(hex: 0xC2CED4))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: action) {
                HStack {
                    Text(actionTitle).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .frame(minHeight: 48)
                .foregroundStyle(Color(hex: 0x23484A))
                .background(Color(hex: 0xE4CB96), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0x173F48), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct CommunityScenicBanner: View {
    let artwork: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Color(hex: 0xFFF9EC)).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.caption).foregroundStyle(Color(hex: 0xD1E0D9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { geometry in
                Image(artwork).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    .overlay(LinearGradient(colors: [Color(hex: 0x17464B), Color(hex: 0x17464B).opacity(0.94), Color(hex: 0x234B5B).opacity(0.5)], startPoint: .leading, endPoint: .trailing))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }
}

private struct CommunityForumCard: View {
    let forum: ForumDTO
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: forum.isBookForum == true ? "books.vertical" : "text.bubble")
                    .font(.title3).foregroundStyle(Color(hex: 0x426374))
                    .frame(width: 42, height: 42)
                    .background(Color(hex: 0xEDF1F3), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 8) {
                    Text(forum.title).font(.headline).foregroundStyle(EKitapligimPalette.ink)
                    if !forum.description.isEmpty {
                        Text(EKitapligimFormat.plainText(forum.description)).font(.caption)
                            .foregroundStyle(EKitapligimPalette.muted).lineLimit(3)
                    }
                    if let stats = forum.stats, !stats.isEmpty {
                        Text(stats).font(.caption2).foregroundStyle(Color(hex: 0x3D6473))
                    } else if let count = forum.threadCount {
                        Text(L10n.forumThreadsCollapsedCount(count)).font(.caption2)
                            .foregroundStyle(Color(hex: 0x3D6473))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(18)
            HStack {
                Text(CommunityRefreshL10n.text("forum.join")).font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.right").font(.caption)
            }
            .foregroundStyle(Color(hex: 0x385C6C))
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(Color(hex: 0xF3F5F6))
        }
        .multilineTextAlignment(.leading)
        .background(Color(hex: 0xFFFEFA))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(EKitapligimPalette.border))
    }
}
