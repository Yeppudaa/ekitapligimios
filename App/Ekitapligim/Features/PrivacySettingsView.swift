import SwiftUI
import EkitapligimCore

struct PrivacySettingsView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Form {
            Section(L10n.privacySummarySection) {
                LabeledContent(L10n.privacyTrackingLabel, value: L10n.profileNo)
                LabeledContent(L10n.privacyAnalyticsLabel, value: L10n.privacyNotUsed)
                LabeledContent(L10n.privacyAdvertisingLabel, value: L10n.privacyNotUsed)
            } footer: {
                Text(L10n.privacyTrackingNotice)
            }

            Section(L10n.privacyDataSection) {
                Text(L10n.privacyDataNotice)
                Text(L10n.privacyOfflineNotice)
            }

            Section(L10n.settingsLegalSection) {
                Link(L10n.settingsPrivacyPolicy, destination: container.config.privacyPolicyURL)
                Link(L10n.settingsTerms, destination: container.config.termsURL)
                Link(L10n.settingsSupport, destination: container.config.supportURL)
            }
        }
        .navigationTitle(L10n.privacyTitle)
    }
}
