import SwiftUI
import EkitapligimCore

@MainActor
struct BlockedMembersView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var members: [BlockedMemberDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(L10n.blockedMembersLoading)
            } else if let errorMessage {
                ContentUnavailableView(L10n.blockedMembersUnavailableTitle, systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if members.isEmpty {
                ContentUnavailableView(L10n.blockedMembersEmptyTitle, systemImage: "hand.raised")
            } else {
                List(members) { member in
                    HStack(spacing: 12) {
                        EKAvatar(urlString: member.avatarUrl, username: member.username, size: 40, cornerRadius: 20)
                        Text(member.username)
                            .font(.body.weight(.semibold))
                        Spacer()
                        Button(L10n.membersUnblock) {
                            Task { await unblock(member) }
                        }
                        .font(.subheadline.weight(.bold))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(L10n.blockedMembersTitle)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            members = try await container.safety.blockedMembers().members
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
