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
    let clientID = resolvedClientID()
    let serverClientID = resolvedServerClientID()
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(
      clientID: clientID,
      serverClientID: serverClientID
    )
  }

  static func handle(_ url: URL) -> Bool {
    configureIfNeeded()
    return GIDSignIn.sharedInstance.handle(url)
  }

  @MainActor
  static func signIn(presenting preferredPresenter: UIViewController? = nil) async throws -> String {
    configureIfNeeded()
    guard GIDSignIn.sharedInstance.configuration != nil else {
      throw GoogleSignInServiceError.notConfigured
    }
    guard hasRegisteredGoogleURLScheme() else {
      throw GoogleSignInServiceError.notConfigured
    }

    let presenter: UIViewController
    if let preferredPresenter, isPresenterReady(preferredPresenter) {
      presenter = preferredPresenter
    } else if let resolvedPresenter = await presentationController() {
      presenter = resolvedPresenter
    } else {
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

  private static func resolvedClientID() -> String {
    GoogleOAuthCredentials.resolvedPlistString(
      forKey: "GIDClientID",
      fallback: GoogleOAuthCredentials.iosClientID
    )
  }

  private static func resolvedServerClientID() -> String {
    GoogleOAuthCredentials.resolvedPlistString(
      forKey: "GIDServerClientID",
      fallback: GoogleOAuthCredentials.serverClientID
    )
  }

  @MainActor
  private static func presentationController() async -> UIViewController? {
    for _ in 0..<10 {
      if let presenter = UIViewController.ekitapligimForPresentation,
         isPresenterReady(presenter) {
        return presenter
      }
      try? await Task.sleep(for: .milliseconds(100))
    }
    guard let presenter = UIViewController.ekitapligimForPresentation,
          isPresenterReady(presenter) else {
      return nil
    }
    return presenter
  }

  @MainActor
  private static func isPresenterReady(_ presenter: UIViewController) -> Bool {
    if presenter.viewIfLoaded?.window != nil { return true }
    if presenter.view.window != nil { return true }
    if let windowScene = presenter.view.window?.windowScene,
       windowScene.windows.contains(where: \.isKeyWindow) {
      return true
    }
    return UIViewController.ekitapligimKeyWindow != nil
  }

  private static func hasRegisteredGoogleURLScheme() -> Bool {
    let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
    let schemes = types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
      .compactMap(GoogleOAuthCredentials.sanitized)
    let expectedScheme = GoogleOAuthCredentials.reversedClientID(from: resolvedClientID())
    if schemes.contains(expectedScheme) { return true }
    if schemes.contains(GoogleOAuthCredentials.urlScheme) { return true }
    return schemes.contains { $0.hasPrefix("com.googleusercontent.apps.") }
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
  static var ekitapligimKeyWindow: UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
  }

  static var ekitapligimForPresentation: UIViewController? {
    var controller = ekitapligimKeyWindow?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}
