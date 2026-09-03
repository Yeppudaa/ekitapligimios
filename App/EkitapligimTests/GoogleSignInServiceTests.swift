import XCTest
@testable import Ekitapligim

final class GoogleSignInServiceTests: XCTestCase {
  func testReversedClientIDMatchesBundledURLScheme() {
    let reversed = GoogleOAuthCredentials.reversedClientID(
      from: GoogleOAuthCredentials.iosClientID
    )
    XCTAssertEqual(reversed, GoogleOAuthCredentials.urlScheme)
  }

  func testSanitizedRejectsUnresolvedBuildPlaceholders() {
    XCTAssertNil(GoogleOAuthCredentials.sanitized("$(EKITAPLIGIM_GOOGLE_IOS_CLIENT_ID)"))
    XCTAssertNil(GoogleOAuthCredentials.sanitized(""))
    XCTAssertNil(GoogleOAuthCredentials.sanitized("   "))
  }

  func testSanitizedAcceptsResolvedClientID() {
    XCTAssertEqual(
      GoogleOAuthCredentials.sanitized("  \(GoogleOAuthCredentials.iosClientID)  "),
      GoogleOAuthCredentials.iosClientID
    )
  }

  func testResolvedPlistStringFallsBackWhenPlistValueMissing() {
    XCTAssertEqual(
      GoogleOAuthCredentials.resolvedPlistString(
        forKey: "EKITAPLIGIM_TEST_MISSING_GOOGLE_KEY",
        fallback: GoogleOAuthCredentials.serverClientID
      ),
      GoogleOAuthCredentials.serverClientID
    )
  }

  func testBundledInfoPlistContainsResolvedGoogleClientID() throws {
    let plist = try XCTUnwrap(
      Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
    )
    XCTAssertEqual(
      GoogleOAuthCredentials.sanitized(plist),
      GoogleOAuthCredentials.iosClientID
    )
  }

  func testBundledInfoPlistContainsResolvedGoogleURLScheme() throws {
    let urlTypes = try XCTUnwrap(
      Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
    )
    let schemes = urlTypes.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
    XCTAssertTrue(schemes.contains(GoogleOAuthCredentials.urlScheme))
  }
}
