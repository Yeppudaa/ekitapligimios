import SwiftUI
import EkitapligimCore

@MainActor
struct CommunitySafetyView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var showingBlockUser = false

    var body: some View {
        List {
            Section(L10n.communitySafetyCommitmentTitle) {
                Label(L10n.communitySafetySLA, systemImage: "clock.badge.checkmark")
                Text(L10n.communitySafetyRulesSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.communitySafetyControlsTitle) {
                Button { showingBlockUser = true } label: {
                    Label(L10n.communityBlockUser, systemImage: "person.crop.circle.badge.xmark")
                }
                NavigationLink {
                    BlockedMembersView()
                } label: {
                    Label(L10n.communityBlockedUsers, systemImage: "hand.raised")
                }
            }

            Section(L10n.settingsSupport) {
                Link(destination: container.config.supportURL) {
                    Label(L10n.communitySafetyContactSupport, systemImage: "envelope")
                }
            }
        }
        .navigationTitle(L10n.communitySafetyTitle)
        .sheet(isPresented: $showingBlockUser) { BlockMemberView() }
    }
}
