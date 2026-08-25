import SwiftUI
import EkitapligimCore

@MainActor
struct LoginView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthFormMode = .login
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var acceptsLegalTerms = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L10n.loginModePicker, selection: $mode) {
                        Text(L10n.loginModeLogin).tag(AuthFormMode.login)
                        Text(L10n.loginModeRegister).tag(AuthFormMode.register)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in clearMessages() }
                }

                credentialsSection

                if mode == .register {
                    legalSection
                }

                messageSection
                actionsSection
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonClose) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var credentialsSection: some View {
        Section {
            if mode != .passwordReset {
                TextField(L10n.loginUsernamePlaceholder, text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if mode != .login {
                TextField(L10n.loginEmailPlaceholder, text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if mode != .passwordReset {
                SecureField(L10n.loginPasswordPlaceholder, text: $password)
                    .textContentType(mode == .register ? .newPassword : .password)
            }
            if mode == .register {
                SecureField(L10n.loginPasswordConfirmation, text: $passwordConfirmation)
                    .textContentType(.newPassword)
            }
        } footer: {
            if mode == .passwordReset {
                Text(L10n.loginResetPrivacyNotice)
            } else if mode == .register && !passwordConfirmation.isEmpty && password != passwordConfirmation {
                Text(L10n.loginPasswordsMismatch)
                    .foregroundStyle(.red)
            }
        }
    }

    private var legalSection: some View {
        Section {
            Toggle(L10n.loginAcceptLegal, isOn: $acceptsLegalTerms)
            Link(L10n.settingsTerms, destination: container.config.termsURL)
            Link(L10n.settingsPrivacyPolicy, destination: container.config.privacyPolicyURL)
        }
    }

    @ViewBuilder
    private var messageSection: some View {
        if let errorMessage {
            Section {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        if let successMessage {
            Section {
                Label(successMessage, systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Task { await submit() }
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text(submitTitle)
                }
            }
            .disabled(!canSubmit || isSubmitting)

            Button(mode == .passwordReset ? L10n.loginBackToLogin : L10n.loginForgotPassword) {
                mode = mode == .passwordReset ? .login : .passwordReset
                clearMessages()
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .login: L10n.loginTitle
        case .register: L10n.loginRegisterTitle
        case .passwordReset: L10n.loginResetTitle
        }
    }

    private var submitTitle: String {
        switch mode {
        case .login: L10n.loginSubmit
        case .register: L10n.loginRegisterSubmit
        case .passwordReset: L10n.loginResetSubmit
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .login:
            !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
        case .register:
            !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && emailLooksValid
                && !password.isEmpty
                && password == passwordConfirmation
                && acceptsLegalTerms
        case .passwordReset:
            emailLooksValid
        }
    }

    private var emailLooksValid: Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && parts[1].contains(".")
    }

    private func submit() async {
        isSubmitting = true
        clearMessages()
        defer { isSubmitting = false }
        do {
            switch mode {
            case .login:
                try await container.signIn(username: username, password: password)
                dismiss()
            case .register:
                guard password == passwordConfirmation else {
                    errorMessage = L10n.loginPasswordsMismatch
                    return
                }
                try await container.register(username: username, email: email, password: password)
                dismiss()
            case .passwordReset:
                try await container.requestPasswordReset(email: email)
                successMessage = L10n.loginResetSubmitted
            }
        } catch {
            errorMessage = mode == .passwordReset ? L10n.loginResetFailed : (mode == .register ? L10n.loginRegisterFailed : L10n.loginInvalidCredentials)
        }
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

}

private enum AuthFormMode: Hashable {
    case login
    case register
    case passwordReset
}
