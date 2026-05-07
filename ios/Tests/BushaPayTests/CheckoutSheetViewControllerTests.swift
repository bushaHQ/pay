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
        // Status 0 is an Android-only quirk; we keep the branch for parity.
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
        // Strong reference required — the timer captures `[weak self]`.
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
        sheet.handleInteractiveDismiss()
        guard case .cancelled = captured else { return XCTFail() }
        XCTAssertTrue(sheet.didDeliverResult)
    }

    func testPresentationControllerDidDismissForwardsToHandleInteractiveDismiss() {
        var captured: BushaPayResult?
        let sheet = makeSheet { captured = $0 }
        sheet.presentationControllerDidDismiss(
            UIPresentationController(presentedViewController: sheet, presenting: nil)
        )
        guard case .cancelled = captured else { return XCTFail() }
    }

    func testSwipeDismissAfterDeliveryIsIgnored() {
        var fireCount = 0
        let sheet = makeSheet { _ in fireCount += 1 }
        sheet.processBridgePayload(#"{"type":"success","data":{"data":{"id":"PAYR_X","status":"completed"}}}"#)
        sheet.handleInteractiveDismiss()
        XCTAssertEqual(fireCount, 1)
    }

    /// Drives the full WebView setup path against a real `UIWindow`.
    private func makeFullSheet(
        autoSelect: AutoSelect = .stablecoins,
        completion: @escaping (BushaPayResult) -> Void = { _ in }
    ) -> CheckoutSheetViewController {
        let sheet = CheckoutSheetViewController(
            config: Self.config,
            publicKey: "pub_x",
            callbackUrl: "co.example.testapp.busha-pay://callback",
            checkoutUrl: "https://pay.busha.io/pay",
            autoSelect: autoSelect,
            resourceBundle: .module,
            completion: completion
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = sheet
        window.makeKeyAndVisible()
        sheet.loadViewIfNeeded()
        sheet.view.layoutIfNeeded()
        return sheet
    }

    func testFullSetupCreatesViewHierarchyWithoutCrashing() {
        let sheet = makeFullSheet()
        XCTAssertNotNil(sheet.viewIfLoaded)
        XCTAssertFalse(sheet.didDeliverResult)
        XCTAssertNotNil(sheet.bootstrapTimer)
    }

    func testFullSetupRespectsAutoSelectNone() {
        let sheet = makeFullSheet(autoSelect: .none)
        XCTAssertNotNil(sheet.viewIfLoaded)
    }

    func testFullSetupWithBushaAppAutoSelect() {
        let sheet = makeFullSheet(autoSelect: .bushaApp)
        XCTAssertNotNil(sheet.viewIfLoaded)
    }

    func testHtmlLoadFailureWithBundleMissingResourceDeliversError() {
        let exp = expectation(description: "html load error")
        let sheet = CheckoutSheetViewController(
            config: Self.config,
            publicKey: "pub_x",
            callbackUrl: "co.example.testapp.busha-pay://callback",
            checkoutUrl: "https://pay.busha.io/pay",
            autoSelect: .none,
            resourceBundle: Bundle(for: Self.self),
            bootstrapTimeout: 30,
            skipWebViewSetup: false,
            completion: { result in
                if case .error(let err) = result, err.code == "HTML_LOAD_ERROR" {
                    exp.fulfill()
                }
            }
        )
        sheet.loadViewIfNeeded()
        wait(for: [exp], timeout: 1)
        XCTAssertTrue(sheet.didDeliverResult)
    }

    private func makeFullSheetWithCapturedWebView(
        autoSelect: AutoSelect = .stablecoins,
        completion: @escaping (BushaPayResult) -> Void = { _ in }
    ) -> (CheckoutSheetViewController, WKWebView) {
        let sheet = makeFullSheet(autoSelect: autoSelect, completion: completion)
        let wv = sheet.view.subviews.compactMap { $0 as? WKWebView }.first
        XCTAssertNotNil(wv, "expected a WKWebView in the view hierarchy")
        return (sheet, wv ?? WKWebView())
    }

    func testNavigationDidFailDelegateMapsToWebViewLoadError() {
        var captured: BushaPayResult?
        let (sheet, wv) = makeFullSheetWithCapturedWebView { captured = $0 }
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: [
            NSLocalizedDescriptionKey: "bad response",
        ])
        sheet.webView(wv, didFail: nil, withError: error)
        if case .error(let err) = captured {
            XCTAssertEqual(err.code, "WEBVIEW_LOAD_ERROR")
        } else {
            XCTFail("expected WEBVIEW_LOAD_ERROR")
        }
    }

    func testNavigationDidFailProvisionalDelegateMapsToWebViewLoadError() {
        var captured: BushaPayResult?
        let (sheet, wv) = makeFullSheetWithCapturedWebView { captured = $0 }
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
        sheet.webView(wv, didFailProvisionalNavigation: nil, withError: error)
        guard case .error(let err) = captured else { return XCTFail() }
        XCTAssertEqual(err.code, "WEBVIEW_LOAD_ERROR")
    }

    func testNavigationActionPolicyAllowsHttp() async {
        let (sheet, wv) = makeFullSheetWithCapturedWebView()
        let action = StubNavigationAction(stubURL: URL(string: "https://pay.busha.io/foo")!)
        let policy = await sheet.webView(wv, decidePolicyFor: action)
        XCTAssertEqual(policy, .allow)
    }

    func testCreateWebViewWithRoutesPopupExternallyAndReturnsNil() {
        var openedURL: URL?
        BushaPay.urlLauncher = { url, completion in
            openedURL = url
            completion(true)
        }
        defer { BushaPay.resetForTesting() }

        let (sheet, wv) = makeFullSheetWithCapturedWebView()
        let action = StubNavigationAction(stubURL: URL(string: "https://example.com/popup")!)
        let result = sheet.webView(wv, createWebViewWith: WKWebViewConfiguration(), for: action, windowFeatures: WKWindowFeatures())
        XCTAssertNil(result)
        XCTAssertEqual(openedURL?.absoluteString, "https://example.com/popup")
    }

    func testWebViewDidFinishFirstCallTriggersFormSubmission() {
        let (sheet, wv) = makeFullSheetWithCapturedWebView()
        sheet.webView(wv, didFinish: nil)
        XCTAssertNotNil(sheet.viewIfLoaded)
    }

    func testWebViewDidFinishSecondCallHidesLoadingOverlay() {
        let (sheet, wv) = makeFullSheetWithCapturedWebView(autoSelect: .bushaApp)
        sheet.webView(wv, didFinish: nil)
        sheet.webView(wv, didFinish: nil)
        XCTAssertTrue(sheet.checkoutInitialized)
    }

    func testWebViewDidFinishSecondCallNoneAutoSelectDoesNotInjectScript() {
        let (sheet, wv) = makeFullSheetWithCapturedWebView(autoSelect: .none)
        sheet.webView(wv, didFinish: nil)
        sheet.webView(wv, didFinish: nil)
        XCTAssertTrue(sheet.checkoutInitialized)
    }

    func testNavigationActionPolicyOpensExternalAndCancels() async {
        // Stub the launcher — `UIApplication.shared.open` hangs in XCTest.
        var openedURL: URL?
        BushaPay.urlLauncher = { url, completion in
            openedURL = url
            completion(true)
        }
        defer { BushaPay.resetForTesting() }

        let (sheet, wv) = makeFullSheetWithCapturedWebView()
        let action = StubNavigationAction(stubURL: URL(string: "mailto:foo@example.com")!)
        let policy = await sheet.webView(wv, decidePolicyFor: action)
        XCTAssertEqual(policy, .cancel)
        XCTAssertEqual(openedURL?.absoluteString, "mailto:foo@example.com")
    }

    func testNavigationResponsePolicyAllows2xxMainFrame() async {
        let (sheet, wv) = makeFullSheetWithCapturedWebView()
        let response = StubNavigationResponse(
            statusCode: 200,
            url: URL(string: "https://pay.busha.io/foo")!,
            isForMainFrame: true
        )
        let policy = await sheet.webView(wv, decidePolicyFor: response)
        XCTAssertEqual(policy, .allow)
    }

    func testNavigationResponsePolicyAllowsNonMainFrame() async {
        // Sub-resource failures must never tear down the page.
        let (sheet, wv) = makeFullSheetWithCapturedWebView()
        let response = StubNavigationResponse(
            statusCode: 500,
            url: URL(string: "https://pay.busha.io/foo")!,
            isForMainFrame: false
        )
        let policy = await sheet.webView(wv, decidePolicyFor: response)
        XCTAssertEqual(policy, .allow)
    }

    func testNavigationResponsePolicyDeliversErrorOn4xxMainFrame() async {
        var captured: BushaPayResult?
        let (sheet, wv) = makeFullSheetWithCapturedWebView { captured = $0 }
        let response = StubNavigationResponse(
            statusCode: 404,
            url: URL(string: "https://pay.busha.io/foo")!,
            isForMainFrame: true
        )
        let policy = await sheet.webView(wv, decidePolicyFor: response)
        XCTAssertEqual(policy, .cancel)
        guard case .error(let err) = captured else { return XCTFail() }
        XCTAssertEqual(err.code, "WEBVIEW_HTTP_ERROR")
    }
}

// `WKNavigationResponse` and `WKNavigationAction` are `final` and have
// no public init; subclassing lets tests fabricate values for the
// async `decidePolicyFor` shims.
private final class StubNavigationResponse: WKNavigationResponse {
    private let _response: HTTPURLResponse
    private let _isForMainFrame: Bool
    init(statusCode: Int, url: URL, isForMainFrame: Bool) {
        self._response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        self._isForMainFrame = isForMainFrame
        super.init()
    }
    override var response: URLResponse { _response }
    override var isForMainFrame: Bool { _isForMainFrame }
}

private final class StubNavigationAction: WKNavigationAction {
    private let _request: URLRequest
    init(stubURL: URL) {
        self._request = URLRequest(url: stubURL)
        super.init()
    }
    override var request: URLRequest { _request }
}
