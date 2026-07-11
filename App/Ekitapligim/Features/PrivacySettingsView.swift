import SwiftUI
import EkitapligimCore

@MainActor
struct PrivacySettingsView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Form {
            Section(header: Text(L10n.privacySummarySection), footer: Text(L10n.privacyTrackingNotice)) {
                privacyRow(title: L10n.privacyTrackingLabel, value: L10n.profileNo)
                privacyRow(title: L10n.privacyAnalyticsLabel, value: L10n.privacyNotUsed)
                privacyRow(title: L10n.privacyAdvertisingLabel, value: L10n.privacyNotUsed)
            }

            Section(header: Text(L10n.privacyDataSection)) {
                Text(L10n.privacyDataNotice)
                Text(L10n.privacyOfflineNotice)
            }

            Section(header: Text(L10n.settingsLegalSection)) {
                Link(L10n.settingsPrivacyPolicy, destination: container.config.privacyPolicyURL)
                Link(L10n.settingsTerms, destination: container.config.termsURL)
                Link(L10n.settingsSupport, destination: container.config.supportURL)
            }
        }
        .navigationTitle(L10n.privacyTitle)
    }

    private func privacyRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
