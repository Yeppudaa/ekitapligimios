import SwiftUI
import EkitapligimCore

struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var showingLogin = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    switch container.authState {
                    case .signedIn(let session):
                        LabeledContent(L10n.settingsUser, value: session.username)
                        Button(L10n.settingsSignOut, role: .destructive) {
                            Task { await container.logout() }
                        }
                    case .authenticating:
                        ProgressView(L10n.settingsSigningIn)
                    default:
                        Button(L10n.settingsSignIn) { showingLogin = true }
                    }
                }

                Section(L10n.settingsProfileSection) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label(L10n.settingsProfile, systemImage: "person.text.rectangle")
                    }
                    .disabled(!isSignedIn)

                    NavigationLink {
                        NotificationsView()
                    } label: {
                        Label(L10n.settingsNotifications, systemImage: "bell")
                    }
                    .disabled(!isSignedIn)

                    NavigationLink {
                        ConversationsView()
                    } label: {
                        Label(L10n.conversationsTitle, systemImage: "envelope")
                    }
                    .disabled(!isSignedIn)
                }

                Section(L10n.settingsAccountSection) {
                    NavigationLink {
                        PremiumView()
                    } label: {
                        Label(L10n.premiumTitle, systemImage: "crown")
                    }
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        Text(L10n.settingsStartAccountDeletion)
                    }
                    .disabled(!isSignedIn)
                }

                Section(L10n.settingsLegalSection) {
                    Link(L10n.settingsPrivacyPolicy, destination: container.config.privacyPolicyURL)
                    Link(L10n.settingsTerms, destination: container.config.termsURL)
                    Link(L10n.settingsSupport, destination: container.config.supportURL)
                }

                Section(L10n.settingsPrivacySection) {
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label(L10n.settingsPrivacyPreferences, systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle(L10n.settingsTitle)
            .sheet(isPresented: $showingLogin) {
                LoginView()
            }
        }
    }

    private var isSignedIn: Bool {
        if case .signedIn = container.authState { return true }
        return false
    }
}
