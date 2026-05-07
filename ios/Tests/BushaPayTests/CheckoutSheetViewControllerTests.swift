import XCTest
import UIKit
import WebKit
@testable import BushaPay

@MainActor
final class CheckoutSheetViewControllerTests: XCTestCase {
    private static let config = BushaPayConfig(
        quoteAmount: "10000",
        quoteCurrency: "NGN",
        targetCurrency: "NGN",
        sourceCurrency: "USDT"
    )

    private func makeSheet(
        autoSelect: AutoSelect = .none,
        bootstrapTimeout: TimeInterval = 30,
        completion: @escaping (BushaPayResult) -> Void
    ) -> CheckoutSheetViewController {
        let sheet = CheckoutSheetViewController(
            config: Self.config,
            publicKey: "pub_x",
            callbackUrl: "co.example.testapp.busha-pay://callback",
            checkoutUrl: "https://pay.busha.io/pay",
            autoSelect: autoSelect,
            resourceBundle: .module,
            bootstrapTimeout: bootstrapTimeout,
            skipWebViewSetup: true,
            completion: completion
        )
        sheet.loadViewIfNeeded()
        return sheet
    }

    func testBridgeReadyMarksCheckoutInitializedAndCancelsTimeout() {
        let sheet = makeSheet { _ in XCTFail("completion should not fire on .ready") }
        XCTAssertFalse(sheet.checkoutInitialized)
        XCTAssertNotNil(sheet.bootstrapTimer)

        sheet.processBridgePayload(#"{"type":"ready"}"#)

        XCTAssertTrue(sheet.checkoutInitialized)
        XCTAssertNil(sheet.bootstrapTimer)
        XCTAssertFalse(sheet.didDeliverResult)
    }

    func testBridgeSuccessDeliversCommerceJsPayload() {
        var captured: BushaPayResult?
        let sheet = makeSheet { captured = $0 }
        sheet.processBridgePayload(#"""
        {"type":"success","data":{"data":{"id":"PAYR_42","status":"completed","source_amount":"0.01"}}}
        """#)

        guard case .success(let s) = captured else { return XCTFail() }
        XCTAssertEqual(s.paymentId, "PAYR_42")
        XCTAssertEqual(s.sourceAmount, "0.01")
        XCTAssertTrue(sheet.didDeliverResult)
    }

    func testBridgeCloseDeliversCancelled() {
        var captured: BushaPayResult?
        let sheet = makeSheet { captured = $0 }
        sheet.processBridgePayload(#"{"type":"close"}"#)
        guard case .cancelled = captured else { return XCTFail() }
    }

    func testBridgeErrorDeliversErrorWithMessageAndCode() {
        var captured: BushaPayResult?
        let sheet = makeSheet { captured = $0 }
        sheet.processBridgePayload(#"{"type":"error","data":{"message":"No signal","code":"NET_DOWN"}}"#)
        guard case .error(let err) = captured else { return XCTFail() }
        XCTAssertEqual(err.message, "No signal")
        XCTAssertEqual(err.code, "NET_DOWN")
    }

    func testBridgeUnknownTypeIsIgnored() {
        var fired = false
        let sheet = makeSheet { _ in fired = true }
        sheet.processBridgePayload(#"{"type":"mystery"}"#)
        XCTAssertFalse(fired)
        XCTAssertFalse(sheet.didDeliverResult)
    }

    func testBridgeMessageAfterDeliveryIsIgnored() {
        var fireCount = 0
        let sheet = makeSheet { _ in fireCount += 1 }
        sheet.processBridgePayload(#"{"type":"close"}"#)
        sheet.processBridgePayload(#"{"type":"success","data":{"data":{"id":"PAYR_X","status":"completed"}}}"#)
        XCTAssertEqual(fireCount, 1, "second result must not double-fire")
    }

    func testMainFrameLoadErrorDeliversWebviewLoadError() {
        var captured: BushaPayResult?
        let sheet = makeSheet { captured = $0 }
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [
            NSLocalizedDescriptionKey: "timeout",
        ])
        sheet.handleNavigationError(error)
        guard case .error(let err) = captured else { return XCTFail() }
        XCTAssertEqual(err.code, "WEBVIEW_LOAD_ERROR")
        XCTAssertTrue(err.message.contains("timeout"))
    }

    func testCancelledNavigationErrorIsIgnored() {
        var fired = false
        let sheet = makeSheet { _ in fired = true }
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        sheet.handleNavigationError(error)
        XCTAssertFalse(fired)
        XCTAssertFalse(sheet.didDeliverResult)
    }

    func testHttp2xxIsAllowed() {
        let sheet = makeSheet { _ in XCTFail() }
        let policy = sheet.handleHttpStatusForMainFrame(200)
        XCTAssertEqual(policy, .allow)
        XCTAssertFalse(sheet.didDeliverResult)
    }

    func testHttpStatusZeroIsAllowed() {
        // iOS doesn't fabricate `0` like Android does, but the branch is
        // there for parity. `.allow` keeps the page from being torn down
        // on a bogus status.
        let sheet = makeSheet { _ in XCTFail() }
        XCTAssertEqual(sheet.handleHttpStatusForMainFrame(0), .allow)
    }

    func testHttp404DeliversWebviewHttpError() {
        var captured: BushaPayResult?
        let sheet = makeSheet { captured = $0 }
        let policy = sheet.handleHttpStatusForMainFrame(404)
        XCTAssertEqual(policy, .cancel)
        guard case .error(let err) = captured else { return XCTFail() }
        XCTAssertEqual(err.code, "WEBVIEW_HTTP_ERROR")
        XCTAssertTrue(err.message.contains("404"))
    }

    func testHttp500DeliversWebviewHttpError() {
        var captured: BushaPayResult?
        let sheet = makeSheet { captured = $0 }
        _ = sheet.handleHttpStatusForMainFrame(503)
        guard case .error(let err) = captured else { return XCTFail() }
        XCTAssertEqual(err.code, "WEBVIEW_HTTP_ERROR")
    }

    func testNavigationDecisionAllowsHttpUrls() {
        let sheet = makeSheet { _ in }
        XCTAssertEqual(
            sheet.decideNavigation(for: URL(string: "https://pay.busha.io/foo")),
            .allow
        )
    }

    func testNavigationDecisionAllowsAboutBlank() {
        let sheet = makeSheet { _ in }
        XCTAssertEqual(sheet.decideNavigation(for: URL(string: "about:blank")), .allow)
    }

    func testNavigationDecisionRoutesNonWebSchemesExternally() {
        let sheet = makeSheet { _ in }
        let busha = URL(string: "co.busha.apple://busha.co/pay?x=1")!
        XCTAssertEqual(sheet.decideNavigation(for: busha), .openExternal(busha))
    }

    func testNavigationDecisionAllowsNilUrl() {
        let sheet = makeSheet { _ in }
        XCTAssertEqual(sheet.decideNavigation(for: nil), .allow)
    }

    func testBootstrapTimeoutDeliversWebviewTimeout() {
        let exp = expectation(description: "timeout fires")
        var captured: BushaPayResult?
        // Keep a strong reference — the timer holds `[weak self]`, so a
        // dropped sheet cancels the test silently.
        let sheet = makeSheet(bootstrapTimeout: 0.05) { result in
            captured = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertTrue(sheet.didDeliverResult)
        guard case .error(let err) = captured else { return XCTFail() }
        XCTAssertEqual(err.code, "WEBVIEW_TIMEOUT")
    }

    func testReadyBeforeTimeoutPreventsTimeoutDelivery() {
        let exp = expectation(description: "no timeout")
        exp.isInverted = true
        let sheet = makeSheet(bootstrapTimeout: 0.05) { _ in
            exp.fulfill()
        }
        sheet.processBridgePayload(#"{"type":"ready"}"#)
        wait(for: [exp], timeout: 0.3)
        XCTAssertNil(sheet.bootstrapTimer)
    }

    func testSwipeDismissDeliversCancelled() {
        var captured: BushaPayResult?
        let sheet = makeSheet { captured = $0 }
        // Caller is `presentationController` but we don't have a real one
        // in tests, so we pass a placeholder via UIPresentationController
        // initializer. The delegate method only inspects `didDeliverResult`.
        sheet.presentationControllerDidDismiss(
            UIPresentationController(presentedViewController: sheet, presenting: nil)
        )
        guard case .cancelled = captured else { return XCTFail() }
        XCTAssertTrue(sheet.didDeliverResult)
    }

    func testSwipeDismissAfterDeliveryIsIgnored() {
        var fireCount = 0
        let sheet = makeSheet { _ in fireCount += 1 }
        sheet.processBridgePayload(#"{"type":"success","data":{"data":{"id":"PAYR_X","status":"completed"}}}"#)
        sheet.presentationControllerDidDismiss(
            UIPresentationController(presentedViewController: sheet, presenting: nil)
        )
        XCTAssertEqual(fireCount, 1)
    }
}
