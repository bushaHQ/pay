import XCTest
@testable import BushaPay

final class BushaPayTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BushaPay.resetForTesting()
        BushaPay.bundleIdOverride = "co.example.testapp"
    }

    override func tearDown() {
        BushaPay.resetForTesting()
        super.tearDown()
    }

    // MARK: - URLs and environment

    func testCallbackSchemeUsesBundleId() {
        BushaPay.initialize(publicKey: "pub_x")
        XCTAssertEqual(BushaPay.callbackScheme, "co.example.testapp.busha-pay")
        XCTAssertEqual(BushaPay.callbackUrl, "co.example.testapp.busha-pay://callback")
    }

    func testEnvironmentUrlsLive() {
        BushaPay.initialize(publicKey: "pub_x", environment: .live)
        XCTAssertEqual(BushaPay.checkoutUrl, "https://pay.busha.co/pay")
        XCTAssertEqual(BushaPay.platformUrl, "https://api.busha.io")
        XCTAssertFalse(BushaPay.isDevMode)
    }

    func testEnvironmentUrlsSandbox() {
        BushaPay.initialize(publicKey: "pub_x", environment: .sandbox)
        XCTAssertEqual(BushaPay.checkoutUrl, "https://staging.pay.busha.co/pay")
        XCTAssertEqual(BushaPay.platformUrl, "https://api.sandbox.busha.so")
        XCTAssertTrue(BushaPay.isDevMode)
    }

    // MARK: - parseCallback

    func testParseCallbackCompleted() {
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_1")!
        guard case .success(let s) = BushaPay.parseCallback(url) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(s.paymentId, "PAYR_1")
        XCTAssertEqual(s.status, "completed")
    }

    func testParseCallbackCancelled() {
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=cancelled")!
        guard case .cancelled = BushaPay.parseCallback(url) else {
            return XCTFail("expected cancelled")
        }
    }

    func testParseCallbackErrorUsesErrorCodeAndMessage() {
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=failed&error_code=NET_DOWN&error_message=No%20signal")!
        guard case .error(let err) = BushaPay.parseCallback(url) else {
            return XCTFail("expected error")
        }
        XCTAssertEqual(err.code, "NET_DOWN")
        XCTAssertEqual(err.message, "No signal")
    }

    func testParseCallbackErrorFallsBackToStatusWhenErrorCodeMissing() {
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=mystery")!
        guard case .error(let err) = BushaPay.parseCallback(url) else {
            return XCTFail("expected error")
        }
        XCTAssertEqual(err.code, "mystery")
        XCTAssertEqual(err.message, "Payment failed")
    }

    // MARK: - handleDeepLink

    func testHandleDeepLinkRejectsNonCallbackUrls() {
        BushaPay.initialize(publicKey: "pub_x")
        let url = URL(string: "https://example.com/")!
        XCTAssertFalse(BushaPay.handleDeepLink(url))
    }

    func testHandleDeepLinkForwardsToPendingHandler() {
        BushaPay.initialize(publicKey: "pub_x")
        var seen: URL?
        BushaPay.registerCallbackHandler { seen = $0 }
        defer { BushaPay.unregisterCallbackHandler() }

        let url = URL(string: "co.example.testapp.busha-pay://callback?status=cancelled")!
        XCTAssertTrue(BushaPay.handleDeepLink(url))
        XCTAssertEqual(seen, url)
    }
}
