import SwiftUI
import EkitapligimCore

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
                    HStack {
                        Text(member.username)
                        Spacer()
                        Button(L10n.blockedMembersRemove) {
                            Task { await unblock(member) }
                        }
                    }
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
        try? await container.safety.unblockMember(userID: id)
        await load()
    }
}
