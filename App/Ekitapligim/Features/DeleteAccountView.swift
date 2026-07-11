import SwiftUI
import EkitapligimCore

@MainActor
struct DeleteAccountView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var confirmationText = ""
    @State private var currentPassword = ""
    @State private var reason = ""
    @State private var statusMessage: String?
    @State private var isSubmitting = false
    @State private var isSubmitted = false

    var body: some View {
        Form {
            Section {
                Text(L10n.deleteAccountWarning)
                Text(L10n.deleteAccountConfirmationPrompt)
                    .foregroundStyle(.secondary)
                TextField(L10n.deleteAccountConfirmationPlaceholder, text: $confirmationText)
                    .textInputAutocapitalization(.characters)
                SecureField(L10n.deleteAccountPasswordPlaceholder, text: $currentPassword)
                    .textContentType(.password)
                TextEditor(text: $reason)
                    .frame(minHeight: 90)
                    .accessibilityLabel(L10n.deleteAccountReasonLabel)
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                }
            }

            Section {
                Button(L10n.deleteAccountSubmit, role: .destructive) {
                    Task { await submit() }
                }
                .disabled(confirmationText.uppercased() != "SIL" || isSubmitting || isSubmitted)
            }
        }
        .navigationTitle(L10n.deleteAccountTitle)
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await container.requestAccountDeletion(
                currentPassword: currentPassword,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            )
            currentPassword = ""
            isSubmitted = true
            statusMessage = L10n.deleteAccountSubmitted
        } catch {
            statusMessage = L10n.deleteAccountSubmitFailed
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
