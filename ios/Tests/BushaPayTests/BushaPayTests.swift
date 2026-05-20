import XCTest
@testable import BushaPay

@MainActor
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

    func testCallbackSchemeUsesBundleId() {
        BushaPay.initialize(publicKey: "pub_x")
        XCTAssertEqual(BushaPay.callbackScheme, "co.example.testapp.busha-pay")
        XCTAssertEqual(BushaPay.callbackUrl, "co.example.testapp.busha-pay://callback")
    }

    func testEnvironmentUrlsLive() {
        BushaPay.initialize(publicKey: "pub_x", environment: .live)
        XCTAssertEqual(BushaPay.checkoutUrl, "https://pay.busha.io/pay")
        XCTAssertEqual(BushaPay.platformUrl, "https://api.busha.io")
        XCTAssertFalse(BushaPay.isDevMode)
    }

    func testEnvironmentUrlsSandbox() {
        BushaPay.initialize(publicKey: "pub_x", environment: .sandbox)
        XCTAssertEqual(BushaPay.checkoutUrl, "https://staging.pay.busha.io/pay")
        XCTAssertEqual(BushaPay.platformUrl, "https://api.sandbox.busha.so")
        XCTAssertTrue(BushaPay.isDevMode)
    }

    func testParseCallbackCompleted() {
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_1")!
        guard case .success(let s) = BushaPay.parseCallback(url) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(s.paymentId, "PAYR_1")
        XCTAssertEqual(s.status, "completed")
    }

    func testParseCallbackCancelled() {
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=cancelled&paymentRequestId=PAYR_REJ")!
        guard case .cancelled(let cancelled) = BushaPay.parseCallback(url) else {
            return XCTFail("expected cancelled")
        }
        XCTAssertEqual(cancelled.reason, .rejected)
        XCTAssertEqual(cancelled.paymentId, "PAYR_REJ")
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

    func testHandleDeepLinkRejectsWrongScheme() {
        BushaPay.initialize(publicKey: "pub_x")
        let url = URL(string: "co.other.app.busha-pay://callback?status=completed")!
        XCTAssertFalse(BushaPay.handleDeepLink(url))
    }

    func testHandleDeepLinkRejectsWrongHost() {
        BushaPay.initialize(publicKey: "pub_x")
        let url = URL(string: "co.example.testapp.busha-pay://other?status=completed")!
        XCTAssertFalse(BushaPay.handleDeepLink(url))
    }

    func testHandleDeepLinkReturnsTrueWithoutPendingHandler() {
        // The SDK consumes the URL even when no listener is registered —
        // returning false would suggest the merchant should handle it.
        BushaPay.initialize(publicKey: "pub_x")
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=cancelled")!
        XCTAssertTrue(BushaPay.handleDeepLink(url))
    }

    func testUnregisterCallbackHandlerStopsForwarding() {
        BushaPay.initialize(publicKey: "pub_x")
        var hits = 0
        BushaPay.registerCallbackHandler { _ in hits += 1 }
        BushaPay.unregisterCallbackHandler()

        let url = URL(string: "co.example.testapp.busha-pay://callback?status=cancelled")!
        _ = BushaPay.handleDeepLink(url)
        XCTAssertEqual(hits, 0)
    }

    func testIsInitializedFlipsAfterInit() {
        XCTAssertFalse(BushaPay.isInitialized)
        BushaPay.initialize(publicKey: "pub_x")
        XCTAssertTrue(BushaPay.isInitialized)
    }

    func testIsCheckoutInProgressIsFalseInitially() {
        BushaPay.initialize(publicKey: "pub_x")
        XCTAssertFalse(BushaPay.isCheckoutInProgress)
    }

    func testResetForTestingClearsEverything() {
        BushaPay.initialize(publicKey: "pub_x", environment: .sandbox)
        BushaPay.registerCallbackHandler { _ in }

        BushaPay.resetForTesting()

        XCTAssertFalse(BushaPay.isInitialized)
        XCTAssertFalse(BushaPay.isCheckoutInProgress)
        XCTAssertFalse(BushaPay.isDevMode, "environment should reset to .live")

        var fired = false
        BushaPay.bundleIdOverride = "co.example.testapp"
        BushaPay.initialize(publicKey: "pub_y")
        BushaPay.registerCallbackHandler { _ in fired = true }
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=cancelled")!
        _ = BushaPay.handleDeepLink(url)
        XCTAssertTrue(fired)
    }

    func testParseCallbackMissingStatusFallsBackToUnknownError() {
        let url = URL(string: "co.example.testapp.busha-pay://callback")!
        guard case .error(let err) = BushaPay.parseCallback(url) else {
            return XCTFail("expected error")
        }
        XCTAssertEqual(err.code, "unknown")
        XCTAssertEqual(err.message, "Payment failed")
    }

    func testParseCallbackUsesEmptyPaymentIdWhenMissing() {
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=completed")!
        guard case .success(let s) = BushaPay.parseCallback(url) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(s.paymentId, "")
    }

    func testParseCallbackUrlEncodedMessageIsDecoded() {
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=failed&error_message=Card%20declined%20%E2%9C%97")!
        guard case .error(let err) = BushaPay.parseCallback(url) else {
            return XCTFail("expected error")
        }
        XCTAssertEqual(err.message, "Card declined ✗")
    }
}
