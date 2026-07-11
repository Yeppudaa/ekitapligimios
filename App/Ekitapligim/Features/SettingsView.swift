import SwiftUI
import EkitapligimCore

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var showingLogin = false

    var body: some View {
        NavigationStack {
            List {
                authenticationSection
                profileSection
                accountSection
                legalSection
                privacySection
            }
            .navigationTitle(L10n.settingsTitle)
            .sheet(isPresented: $showingLogin) {
                LoginView()
            }
        }
    }

    @ViewBuilder
    private var authenticationSection: some View {
        Section {
            switch container.authState {
            case .signedIn(let session):
                HStack {
                    Text(L10n.settingsUser)
                    Spacer()
                    Text(session.username).foregroundStyle(.secondary)
                }
                Button(L10n.settingsSignOut, role: .destructive) { Task { await container.logout() } }
            case .authenticating:
                ProgressView(L10n.settingsSigningIn)
            default:
                Button(L10n.settingsSignIn) { showingLogin = true }
            }
        }
    }

    private var profileSection: some View {
        Section(L10n.settingsProfileSection) {
            settingsLink(L10n.settingsProfile, icon: "person.text.rectangle", destination: ProfileView())
            settingsLink(L10n.settingsNotifications, icon: "bell", destination: NotificationsView())
            settingsLink(L10n.conversationsTitle, icon: "envelope", destination: ConversationsView())
            settingsLink(L10n.myCommentsTitle, icon: "text.bubble", destination: MyCommentsView())
        }
    }

    private var accountSection: some View {
        Section(L10n.settingsAccountSection) {
            NavigationLink { PremiumView() } label: { Label(L10n.premiumTitle, systemImage: "crown") }
            NavigationLink { DeleteAccountView() } label: { Text(L10n.settingsStartAccountDeletion) }
                .disabled(!isSignedIn)
        }
    }

    private var legalSection: some View {
        Section(L10n.settingsLegalSection) {
            Link(L10n.settingsPrivacyPolicy, destination: container.config.privacyPolicyURL)
            Link(L10n.settingsTerms, destination: container.config.termsURL)
            Link(L10n.settingsSupport, destination: container.config.supportURL)
        }
    }

    private var privacySection: some View {
        Section(L10n.settingsPrivacySection) {
            NavigationLink { PrivacySettingsView() } label: {
                Label(L10n.settingsPrivacyPreferences, systemImage: "hand.raised")
            }
        }
    }

    private func settingsLink<Destination: View>(_ title: String, icon: String, destination: Destination) -> some View {
        NavigationLink { destination } label: { Label(title, systemImage: icon) }
            .disabled(!isSignedIn)
    }

    private var isSignedIn: Bool {
        if case .signedIn = container.authState { return true }
        return false
    }
}
