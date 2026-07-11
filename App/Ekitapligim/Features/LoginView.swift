import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
import EkitapligimCore

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
    @State private var appleNonce: String?

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
            if mode != .passwordReset {
                SignInWithAppleButton(mode == .register ? .signUp : .signIn) { request in
                    let nonce = Self.makeAppleNonce()
                    appleNonce = nonce
                    request.nonce = Self.sha256(nonce)
                    request.requestedScopes = [.email]
                } onCompletion: { result in
                    Task { await handleAppleResult(result) }
                }
                .frame(height: 48)
                .disabled(isSubmitting || (mode == .register && !acceptsLegalTerms))
            }

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

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        isSubmitting = true
        clearMessages()
        defer {
            isSubmitting = false
            appleNonce = nil
        }
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let authorizationCodeData = credential.authorizationCode,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
                  let nonce = appleNonce
            else {
                errorMessage = L10n.loginAppleInvalid
                return
            }
            try await container.signInWithApple(identityToken: identityToken, authorizationCode: authorizationCode, nonce: nonce)
            dismiss()
        } catch {
            errorMessage = L10n.loginAppleFailed
        }
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private static func makeAppleNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString + UUID().uuidString
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

}

private enum AuthFormMode: Hashable {
    case login
    case register
    case passwordReset
}
