import SwiftUI
import EkitapligimCore

@MainActor
struct CommunityView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var showingBlockUser = false
    @State private var forums: [ForumDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(L10n.communityLoading)
                } else if let errorMessage {
                    ContentUnavailableView(L10n.communityUnavailableTitle, systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else {
                    List {
                        Section(L10n.communityForumsSection) {
                            ForEach(forums) { forum in
                                NavigationLink {
                                    ForumThreadsView(forum: forum)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(forum.title)
                                            .font(.headline)
                                        if !forum.description.isEmpty {
                                            Text(forum.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                        }

                        Section(L10n.communityDirectorySection) {
                            NavigationLink {
                                MembersView()
                            } label: {
                                Label(L10n.membersTitle, systemImage: "person.3")
                            }
                        }

                        Section(L10n.communitySafetySection) {
                            Button {
                                showingBlockUser = true
                            } label: {
                                Label(L10n.communityBlockUser, systemImage: "person.crop.circle.badge.xmark")
                            }
                            NavigationLink {
                                BlockedMembersView()
                            } label: {
                                Label(L10n.communityBlockedUsers, systemImage: "hand.raised")
                            }
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
