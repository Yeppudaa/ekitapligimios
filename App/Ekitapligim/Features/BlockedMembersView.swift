import SwiftUI
import EkitapligimCore

@MainActor
struct BlockedMembersView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var members: [BlockedMemberDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(L10n.blockedMembersLoading)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    ContentUnavailableView(L10n.blockedMembersUnavailableTitle, systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    Button(L10n.commonRetry) {
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if members.isEmpty {
                ContentUnavailableView(L10n.blockedMembersEmptyTitle, systemImage: "hand.raised")
            } else {
                List(members) { member in
                    (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))) {
                        MemberProfileLink(memberID: member.id) {
                            HStack(spacing: 12) {
                                EKAvatar(urlString: member.avatarUrl, username: member.username, size: 40, cornerRadius: 20)
                                Text(member.username)
                                    .font(.body.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                        Button(L10n.membersUnblock) {
                            Task { await unblock(member) }
                        }
                        .font(.subheadline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle(L10n.blockedMembersTitle)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loadedMembers = try await container.safety.blockedMembers().members
            members = loadedMembers
            container.replaceBlockedUsers(Set(loadedMembers.compactMap { Int($0.id) }))
        } catch {
            errorMessage = L10n.blockedMembersLoadFailed
        }
    }

    private func unblock(_ member: BlockedMemberDTO) async {
        guard let id = Int(member.id) else { return }
        do {
            _ = try await container.safety.unblockMember(userID: id)
            container.forgetBlockedUser(id)
            await load()
        } catch {
            errorMessage = L10n.membersActionFailed
        }
    }
}
