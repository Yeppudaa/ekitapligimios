import SwiftUI
import EkitapligimCore

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
                Section {
                    Text(L10n.termsIntro)
                    Link(L10n.termsOpen, destination: container.config.termsURL)
                    Toggle(L10n.termsAcceptToggle, isOn: $accepted)
                } footer: {
                    Text(L10n.termsFooter)
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                    }
                }

                Section {
                    Button(L10n.termsAccept) {
                        Task { await accept() }
                    }
                    .disabled(!accepted || isSubmitting)
                }
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
