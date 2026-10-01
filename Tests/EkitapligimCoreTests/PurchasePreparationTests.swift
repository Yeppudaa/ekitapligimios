import XCTest
@testable import EkitapligimCore

final class PurchasePreparationTests: XCTestCase {
    func testPreparationUsesAuthenticatedPostWithCapturedAccount() {
        let endpoint = APIEndpoint.prepareAppStorePurchase(accountName: "reader")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.path, "billing/app-store/verify")
        XCTAssertTrue(endpoint.requiresAuthentication)
        XCTAssertEqual(endpoint.body, .form(["prepare_purchase": "1", "account_name": "reader"]))
    }

    func testPreparationDecodesServerUUID() throws {
        let data = Data(#"{"success":true,"app_account_token":"9249ceaa-60dd-4a61-917b-0057f22818aa"}"#.utf8)
        let response = try JSONDecoder.ekitapligim.decode(PurchaseAccountDTO.self, from: data)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.appAccountToken.uuidString.lowercased(), "9249ceaa-60dd-4a61-917b-0057f22818aa")
    }

    func testInvalidOrMissingUUIDCannotStartPurchase() {
        for json in [#"{"success":true}"#, #"{"success":true,"app_account_token":"invalid"}"#] {
            XCTAssertThrowsError(try JSONDecoder.ekitapligim.decode(PurchaseAccountDTO.self, from: Data(json.utf8)))
        }
    }
}
