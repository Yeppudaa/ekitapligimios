import SwiftUI
import EkitapligimCore

@MainActor
struct CommunityView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var showingBlockUser = false
    @State private var forums: [ForumDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            EKitapligimScreen {
                Group {
                    if isLoading {
                        EKLoadingState(message: L10n.communityLoading)
                    } else if let errorMessage {
                        EKErrorState(title: L10n.communityUnavailableTitle, message: errorMessage) {
                            Task { await load() }
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                communityHero
                                forumCards
                                directoryCard
                                safetyCard
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
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

    private var communityHero: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(
                        colors: [EKitapligimPalette.forumBlue, Color(hex: 0x2A5FA8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: EKitapligimPalette.forumBlue.opacity(0.25), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(L10n.communityTitle)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(EKitapligimPalette.forumInk)
                    EKPill(
                        title: L10n.homeDiscoveryForumBadge,
                        foreground: EKitapligimPalette.forumBlue,
                        background: EKitapligimPalette.forumBlueSoft
                    )
                }
                Text(L10n.communityHeroSubtitle)
                    .font(.caption)
                    .foregroundStyle(EKitapligimPalette.forumMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .forumHeroSurface(radius: 18)
    }

    private var forumCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [EKitapligimPalette.forumTeal, EKitapligimPalette.forumGold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: 22)
                Text(L10n.communityForumsSection)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(EKitapligimPalette.forumInk)
            }

            ForEach(forums) { forum in
                NavigationLink {
                    ForumThreadsView(forum: forum)
                } label: {
                    EKForumListCard(forum: forum)
                }
                .buttonStyle(.plain)
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
        isLoading = true
        defer { isLoading = false }
        do {
            forums = try await container.community.forums().forums
        } catch {
            errorMessage = L10n.communityForumsLoadFailed
        }
    }
}
