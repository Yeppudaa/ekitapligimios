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
                            LazyVStack(spacing: 14) {
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
            .navigationTitle(L10n.communityTitle)
            .task { await load() }
            .sheet(isPresented: $showingBlockUser) {
                BlockMemberView()
            }
        }
    }

    private var communityHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.communityTitle)
                .font(.title2.weight(.heavy))
                .foregroundStyle(EKitapligimPalette.ink)
            Text(L10n.communityHeroSubtitle)
                .font(.caption)
                .foregroundStyle(EKitapligimPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .ekitapligimCard()
    }

    private var forumCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.communityForumsSection)
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.ink)
            ForEach(forums) { forum in
                NavigationLink {
                    ForumThreadsView(forum: forum)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(forum.title)
                            .font(.headline)
                            .foregroundStyle(EKitapligimPalette.ink)
                        if !forum.description.isEmpty {
                            Text(forum.description)
                                .font(.caption)
                                .foregroundStyle(EKitapligimPalette.muted)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .ekitapligimCard(radius: 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var directoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.communityDirectorySection)
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.ink)
            NavigationLink {
                MembersView()
            } label: {
                Label(L10n.membersTitle, systemImage: "person.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.tealDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .ekitapligimCard(radius: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.communitySafetySection)
                .font(.headline)
                .foregroundStyle(EKitapligimPalette.ink)
            Button { showingBlockUser = true } label: {
                Label(L10n.communityBlockUser, systemImage: "person.crop.circle.badge.xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .ekitapligimCard(radius: 14)
            }
            .buttonStyle(.plain)
            NavigationLink {
                BlockedMembersView()
            } label: {
                Label(L10n.communityBlockedUsers, systemImage: "hand.raised")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EKitapligimPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .ekitapligimCard(radius: 14)
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
