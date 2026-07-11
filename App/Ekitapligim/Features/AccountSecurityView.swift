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
            emailSection
            passwordSection
        }
        .navigationTitle(L10n.accountSecurityTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emailSection: some View {
        Section(header: Text(L10n.accountSecurityEmailSection), footer: Text(L10n.accountSecurityEmailFooter)) {
            securityRow(title: L10n.accountSecurityCurrentEmail, value: currentEmail)
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
        }
    }

    private var passwordSection: some View {
        Section(header: Text(L10n.accountSecurityPasswordSection), footer: Text(L10n.accountSecurityPasswordFooter)) {
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
        }
    }

    @ViewBuilder
    private func statusView(_ message: StatusMessage?) -> some View {
        if let message {
            HStack {
                Image(systemName: message.isError ? "exclamationmark.triangle" : "checkmark.circle")
                Text(message.text)
            }
            .foregroundStyle(message.isError ? .red : .green)
        }
    }

    private func securityRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
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
