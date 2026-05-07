import XCTest
@testable import BushaPay

final class DeepLinkTests: XCTestCase {
    func testLiveScheme() {
        XCTAssertEqual(DeepLink.bushaAppScheme(.live), "co.busha.apple")
    }

    func testSandboxScheme() {
        XCTAssertEqual(DeepLink.bushaAppScheme(.sandbox), "co.busha.boro.development")
    }

    func testBuildIncludesAllRequiredFields() throws {
        let config = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT"
        )
        let url = try XCTUnwrap(DeepLink.buildBushaAppDeepLink(
            scheme: "co.busha.apple",
            config: config,
            publicKey: "pub_x",
            callbackUrl: "co.example.app.busha-pay://callback"
        ))
        XCTAssertEqual(url.scheme, "co.busha.apple")
        XCTAssertEqual(url.host, "busha.co")
        XCTAssertEqual(url.path, "/pay")

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let dict = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
        XCTAssertEqual(dict["public_key"], "pub_x")
        XCTAssertEqual(dict["quote_amount"], "10000")
        XCTAssertEqual(dict["quote_currency"], "NGN")
        XCTAssertEqual(dict["target_currency"], "NGN")
        XCTAssertEqual(dict["callback_url"], "co.example.app.busha-pay://callback")
        XCTAssertNil(dict["reference"], "reference must be omitted when nil")
    }

    func testBuildOmitsReferenceWhenNil() throws {
        let config = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT",
            reference: nil
        )
        let url = try XCTUnwrap(DeepLink.buildBushaAppDeepLink(
            scheme: "co.busha.apple",
            config: config,
            publicKey: "pub_x",
            callbackUrl: "scheme://callback"
        ))
        XCTAssertFalse(url.absoluteString.contains("reference"))
    }

    func testBuildIncludesReferenceWhenSet() throws {
        let config = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT",
            reference: "ORDER_42"
        )
        let url = try XCTUnwrap(DeepLink.buildBushaAppDeepLink(
            scheme: "co.busha.apple",
            config: config,
            publicKey: "pub_x",
            callbackUrl: "scheme://callback"
        ))
        XCTAssertTrue(url.absoluteString.contains("reference=ORDER_42"))
    }

    func testIsWebScheme() {
        XCTAssertTrue(isWebScheme("http"))
        XCTAssertTrue(isWebScheme("HTTPS"))
        XCTAssertTrue(isWebScheme("about"))
        XCTAssertFalse(isWebScheme("co.busha.apple"))
        XCTAssertFalse(isWebScheme("mailto"))
    }
}
