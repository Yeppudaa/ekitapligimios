import SwiftUI
import EkitapligimCore

struct AccountSecurityView: View {
    @EnvironmentObject private var container: AppContainer
    let currentEmail: String
    let didChangeEmail: () -> Void

    @State private var email = ""
    @State private var emailPassword = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirmation = ""
    @State private var isChangingEmail = false
    @State private var isChangingPassword = false
    @State private var emailMessage: StatusMessage?
    @State private var passwordMessage: StatusMessage?

    var body: some View {
        Form {
            Section(L10n.accountSecurityEmailSection) {
                LabeledContent(L10n.accountSecurityCurrentEmail, value: currentEmail)
                TextField(L10n.accountSecurityNewEmail, text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField(L10n.accountSecurityCurrentPassword, text: $emailPassword)
                    .textContentType(.password)
                statusView(emailMessage)
                Button(isChangingEmail ? L10n.accountSecuritySaving : L10n.accountSecurityUpdateEmail) {
                    Task { await changeEmail() }
                }
                .disabled(!emailLooksValid || emailPassword.isEmpty || isChangingEmail || isChangingPassword)
            } footer: {
                Text(L10n.accountSecurityEmailFooter)
            }

            Section(L10n.accountSecurityPasswordSection) {
                SecureField(L10n.accountSecurityCurrentPassword, text: $currentPassword)
                    .textContentType(.password)
                SecureField(L10n.accountSecurityNewPassword, text: $newPassword)
                    .textContentType(.newPassword)
                SecureField(L10n.accountSecurityConfirmPassword, text: $newPasswordConfirmation)
                    .textContentType(.newPassword)
                if !newPasswordConfirmation.isEmpty && newPassword != newPasswordConfirmation {
                    Text(L10n.loginPasswordsMismatch)
                        .foregroundStyle(.red)
                }
                statusView(passwordMessage)
                Button(isChangingPassword ? L10n.accountSecuritySaving : L10n.accountSecurityUpdatePassword) {
                    Task { await changePassword() }
                }
                .disabled(!canChangePassword || isChangingEmail || isChangingPassword)
            } footer: {
                Text(L10n.accountSecurityPasswordFooter)
            }
        }
        .navigationTitle(L10n.accountSecurityTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func statusView(_ message: StatusMessage?) -> some View {
        if let message {
            Label(message.text, systemImage: message.isError ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(message.isError ? .red : .green)
        }
    }

    private var emailLooksValid: Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && parts[1].contains(".") && email != currentEmail
    }

    private var canChangePassword: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && newPassword == newPasswordConfirmation
    }

    private func changeEmail() async {
        isChangingEmail = true
        emailMessage = nil
        defer { isChangingEmail = false }
        do {
            let response = try await container.account.updateEmail(
                currentPassword: emailPassword,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            emailPassword = ""
            emailMessage = StatusMessage(
                text: response.confirmationRequired ? L10n.accountSecurityEmailConfirmation : L10n.accountSecurityEmailUpdated,
                isError: false
            )
            didChangeEmail()
        } catch {
            emailMessage = StatusMessage(text: L10n.accountSecurityEmailFailed, isError: true)
        }
    }

    private func changePassword() async {
        isChangingPassword = true
        passwordMessage = nil
        defer { isChangingPassword = false }
        do {
            try await container.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
            currentPassword = ""
            newPassword = ""
            newPasswordConfirmation = ""
            passwordMessage = StatusMessage(text: L10n.accountSecurityPasswordUpdated, isError: false)
        } catch {
            passwordMessage = StatusMessage(text: L10n.accountSecurityPasswordFailed, isError: true)
        }
    }
}

private struct StatusMessage {
    let text: String
    let isError: Bool
}
