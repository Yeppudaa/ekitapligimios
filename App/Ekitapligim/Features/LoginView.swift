import SwiftUI
import EkitapligimCore

@MainActor
struct LoginView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthFormMode
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var isPasswordVisible = false
    @State private var acceptsLegalTerms = false
    @State private var legalTerms: LegalTermsDTO?
    @State private var isLoadingLegalTerms = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSubmitting = false

    init(initialMode: AuthFormMode = .login) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    brandHeader
                    signalRow
                    authCard
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: 0xF7FAFC), Color(hex: 0xEFF8FA), Color(hex: 0xFFFBF3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonClose) { dismiss() }
                }
            }
            .task { await loadLegalTerms() }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 12) {
            EKitapligimBrandLogo()
                .frame(maxWidth: 340)
                .frame(height: 92)
            Text(L10n.loginCommunityTagline)
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0x657484))
                .multilineTextAlignment(.center)
        }
    }

    private var signalRow: some View {
        HStack(spacing: 10) {
            loginSignal(L10n.loginSignalShelf, systemImage: "books.vertical.fill")
            loginSignal(L10n.loginSignalAPI, systemImage: "checkmark.shield.fill")
            loginSignal(L10n.loginSignalPremium, systemImage: "crown.fill")
        }
    }

    private func loginSignal(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(hex: 0x0E7C86))
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color(hex: 0x657484))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var authCard: some View {
        VStack(spacing: 14) {
            modeBadge
            Text(headingTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color(hex: 0x172033))
            Text(headingSubtitle)
                .font(.footnote)
                .foregroundStyle(Color(hex: 0x657484))
                .multilineTextAlignment(.center)

            if let errorMessage {
                notice(errorMessage, isError: true)
            }
            if let successMessage {
                notice(successMessage, isError: false)
            }

            credentialsFields

            if mode != .passwordReset {
                legalBlock
            }

            if mode == .login {
                HStack {
                    Spacer()
                    Button(L10n.loginForgotPassword) {
                        mode = .passwordReset
                        clearMessages()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x0E7C86))
                }
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(submitTitle)
                            .font(.body.weight(.bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    canSubmit && !isSubmitting ? Color(hex: 0x0E7C86) : Color(hex: 0x0E7C86).opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSubmitting)

            Button(switchTitle) {
                switch mode {
                case .passwordReset:
                    mode = .login
                case .login:
                    mode = .register
                    acceptsLegalTerms = false
                case .register:
                    mode = .login
                    acceptsLegalTerms = false
                }
                clearMessages()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(hex: 0x244C73))
            .padding(.top, 2)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [.white, Color(hex: 0xFAFEFE)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white, lineWidth: 1)
        }
    }

    private var modeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: badgeIcon)
                .font(.caption.weight(.bold))
            Text(badgeTitle)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Color(hex: 0x0E7C86))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(hex: 0xEFF8FA), in: Capsule())
    }

    @ViewBuilder
    private var credentialsFields: some View {
        if mode != .passwordReset {
            authField(
                title: L10n.loginUsernamePlaceholder,
                text: $username,
                systemImage: "person.fill",
                contentType: .username
            )
        }
        if mode != .login {
            authField(
                title: L10n.loginEmailPlaceholder,
                text: $email,
                systemImage: "envelope.fill",
                contentType: .emailAddress,
                keyboard: .emailAddress
            )
        }
        if mode != .passwordReset {
            authSecureField
        }
        if mode == .register {
            authField(
                title: L10n.loginPasswordConfirmation,
                text: $passwordConfirmation,
                systemImage: "lock.fill",
                contentType: .newPassword,
                isSecure: true
            )
            if !passwordConfirmation.isEmpty && password != passwordConfirmation {
                Text(L10n.loginPasswordsMismatch)
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0xC53D3D))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var authSecureField: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color(hex: 0x657484))
            Group {
                if isPasswordVisible {
                    TextField(L10n.loginPasswordPlaceholder, text: $password)
                } else {
                    SecureField(L10n.loginPasswordPlaceholder, text: $password)
                }
            }
            .textContentType(mode == .register ? .newPassword : .password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(Color(hex: 0x657484))
            }
            .accessibilityLabel(isPasswordVisible ? L10n.loginHidePassword : L10n.loginShowPassword)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: 0xD7E3E6), lineWidth: 1)
        }
    }

    private func authField(
        title: String,
        text: Binding<String>,
        systemImage: String,
        contentType: UITextContentType?,
        keyboard: UIKeyboardType = .default,
        isSecure: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color(hex: 0x657484))
            Group {
                if isSecure {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                }
            }
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: 0xD7E3E6), lineWidth: 1)
        }
    }

    private var legalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $acceptsLegalTerms) {
                Text(L10n.loginAcceptLegal)
                    .font(.footnote)
                    .foregroundStyle(Color(hex: 0x435365))
            }
            .tint(Color(hex: 0x0E7C86))

            HStack(spacing: 12) {
                Link(L10n.loginEULA, destination: legalTerms?.eulaUrl ?? container.config.eulaURL)
                Link(L10n.settingsTerms, destination: legalTerms?.termsUrl ?? container.config.termsURL)
                Link(L10n.settingsPrivacyPolicy, destination: legalTerms?.privacyUrl ?? container.config.privacyPolicyURL)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(hex: 0x0E7C86))
            .lineLimit(1)

            if isLoadingLegalTerms {
                ProgressView(L10n.loginLegalLoading)
            } else if legalTerms == nil {
                Label(L10n.loginLegalUnavailable, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0xC53D3D))
            }

            Text(L10n.loginCommunityRulesSummary)
                .font(.caption2)
                .foregroundStyle(Color(hex: 0x657484))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xF7FAFC), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func notice(_ text: String, isError: Bool) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(isError ? Color(hex: 0xC53D3D) : Color(hex: 0x0E7C86))
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                (isError ? Color(hex: 0xFFF0F0) : Color(hex: 0xEFF8FA)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }

    private var badgeIcon: String {
        switch mode {
        case .login: "rectangle.portrait.and.arrow.right"
        case .register: "person.badge.plus"
        case .passwordReset: "lock.rotation"
        }
    }

    private var badgeTitle: String {
        switch mode {
        case .login: L10n.loginBadgeLogin
        case .register: L10n.loginBadgeRegister
        case .passwordReset: L10n.loginBadgeReset
        }
    }

    private var headingTitle: String {
        switch mode {
        case .login: L10n.loginHeadingLogin
        case .register: L10n.loginRegisterTitle
        case .passwordReset: L10n.loginResetTitle
        }
    }

    private var headingSubtitle: String {
        switch mode {
        case .login: L10n.loginSubtitleLogin
        case .register: L10n.loginSubtitleRegister
        case .passwordReset: L10n.loginSubtitleReset
        }
    }

    private var switchTitle: String {
        switch mode {
        case .passwordReset: L10n.loginBackToLogin
        case .register: L10n.loginSwitchToLogin
        case .login: L10n.loginSwitchToRegister
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
            !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !password.isEmpty
                && acceptsLegalTerms
                && legalTerms != nil
        case .register:
            !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && emailLooksValid
                && !password.isEmpty
                && password == passwordConfirmation
                && acceptsLegalTerms
                && legalTerms != nil
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
                guard let version = legalTerms?.version else { return }
                try await container.signIn(username: username, password: password, acceptedTermsVersion: version)
                dismiss()
            case .register:
                guard password == passwordConfirmation else {
                    errorMessage = L10n.loginPasswordsMismatch
                    return
                }
                guard let version = legalTerms?.version else { return }
                try await container.register(
                    username: username,
                    email: email,
                    password: password,
                    acceptedTermsVersion: version
                )
                dismiss()
            case .passwordReset:
                try await container.requestPasswordReset(email: email)
                successMessage = L10n.loginResetSubmitted
            }
        } catch {
            errorMessage = mode == .passwordReset
                ? L10n.loginResetFailed
                : (mode == .register ? L10n.loginRegisterFailed : L10n.loginInvalidCredentials)
        }
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func loadLegalTerms() async {
        guard legalTerms == nil, !isLoadingLegalTerms else { return }
        isLoadingLegalTerms = true
        defer { isLoadingLegalTerms = false }
        legalTerms = try? await container.account.legalTerms()
    }
}

enum AuthFormMode: Hashable {
    case login
    case register
    case passwordReset
}
