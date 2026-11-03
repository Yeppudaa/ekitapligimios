import XCTest
@testable import EkitapligimCore

final class NotificationPresentationPolicyTests: XCTestCase {
    func testGrantedPermissionWithBannersDisabledIsNotPopupReady() {
        XCTAssertFalse(NotificationPresentationPolicy.bannersEnabled(fullyAuthorized: true, alertsEnabled: true, bannerStyleEnabled: false))
        XCTAssertFalse(NotificationPresentationPolicy.bannersEnabled(fullyAuthorized: true, alertsEnabled: false, bannerStyleEnabled: true))
    }
    func testQuietOrDeniedAuthorizationCannotClaimBannersEnabled() {
        XCTAssertFalse(NotificationPresentationPolicy.bannersEnabled(fullyAuthorized: false, alertsEnabled: true, bannerStyleEnabled: true))
    }
    func testAuthorizedAlertsAndBannerStyleAllowDisplayTest() {
        XCTAssertTrue(NotificationPresentationPolicy.bannersEnabled(fullyAuthorized: true, alertsEnabled: true, bannerStyleEnabled: true))
    }
}
