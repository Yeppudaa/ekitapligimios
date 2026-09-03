import Foundation
import UIKit
import GoogleSignIn

enum GoogleSignInServiceError: Error {
    case notConfigured
    case missingPresenter
    case missingToken
    case canceled
}

enum GoogleSignInService {
    static func configureIfNeeded() {
        guard GIDSignIn.sharedInstance.configuration == nil else { return }
        guard let clientID = plistValue("GIDClientID"), !clientID.isEmpty else { return }
        let serverClientID = plistValue("GIDServerClientID")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID?.isEmpty == false ? serverClientID : nil
        )
    }

    static func handle(_ url: URL) -> Bool {
        configureIfNeeded()
        return GIDSignIn.sharedInstance.handle(url)
    }

    @MainActor
    static func signIn() async throws -> String {
        configureIfNeeded()
        guard GIDSignIn.sharedInstance.configuration != nil else {
            throw GoogleSignInServiceError.notConfigured
        }
        guard hasRegisteredGoogleURLScheme() else {
            throw GoogleSignInServiceError.notConfigured
        }
        guard let presenter = await presentationController() else {
            throw GoogleSignInServiceError.missingPresenter
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString, !idToken.isEmpty else {
                throw GoogleSignInServiceError.missingToken
            }
            return idToken
        } catch {
            if isCancellation(error) {
                throw GoogleSignInServiceError.canceled
            }
            throw error
        }
    }

    private static func presentationController() async -> UIViewController? {
        for _ in 0..<5 {
            if let presenter = UIViewController.ekitapligimForPresentation,
               presenter.view.window != nil,
               presenter.presentedViewController == nil {
                return presenter
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        let presenter = UIViewController.ekitapligimForPresentation
        guard presenter?.view.window != nil else { return nil }
        return presenter
    }

    private static func hasRegisteredGoogleURLScheme() -> Bool {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("$(") }
        if let clientID = plistValue("GIDClientID") {
            let expected = reversedClientID(from: clientID)
            if schemes.contains(expected) { return true }
        }
        return schemes.contains { $0.hasPrefix("com.googleusercontent.apps.") }
    }

    private static func reversedClientID(from clientID: String) -> String {
        let prefix = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(prefix)"
    }

    private static func plistValue(_ key: String) -> String? {
        guard let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty,
            !value.hasPrefix("$(")
        else {
            return nil
        }
        return value
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        if nsError.domain == kGIDSignInErrorDomain, nsError.code == -5 {
            return true
        }
        return false
    }
}

private extension UIViewController {
    static var ekitapligimForPresentation: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
