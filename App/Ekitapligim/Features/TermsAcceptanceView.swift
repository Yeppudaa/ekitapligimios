import SwiftUI
import EkitapligimCore

@MainActor
struct TermsAcceptanceView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var accepted = false
    @State private var statusMessage: String?
    @State private var isSubmitting = false
    @State private var requiredVersion = "2026-07"

    var body: some View {
        NavigationStack {
            Form {
                termsSection
                statusSection
                submitSection
            }
            .navigationTitle(L10n.termsTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonClose) { dismiss() }
                }
            }
            .task { await loadStatus() }
        }
    }

    private var termsSection: some View {
        Section(footer: Text(L10n.termsFooter)) {
            Text(L10n.termsIntro)
            Link(L10n.termsOpen, destination: container.config.termsURL)
            Toggle(L10n.termsAcceptToggle, isOn: $accepted)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let statusMessage {
            Section { Text(statusMessage) }
        }
    }

    private var submitSection: some View {
        Section {
            Button(L10n.termsAccept) { Task { await accept() } }
                .disabled(!accepted || isSubmitting)
        }
    }

    private func loadStatus() async {
        if let status = try? await container.account.termsStatus() {
            requiredVersion = status.requiredVersion
            accepted = !status.requiresAcceptance
        }
    }

    private func accept() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await container.account.acceptTerms(version: requiredVersion)
            statusMessage = L10n.termsAccepted
            dismiss()
        } catch {
            statusMessage = L10n.termsAcceptFailed
        }
    }
}
