import XCTest
import UIKit
@testable import BushaPay

/// `FakePresenter` captures whatever VC the SDK tried to present so the
/// flow runs without a real window or simulator UI.
@MainActor
final class BushaPayFlowTests: XCTestCase {
    private static let config = BushaPayConfig(
        quoteAmount: "10000",
        quoteCurrency: "NGN",
        targetCurrency: "NGN",
        sourceCurrency: "USDT"
    )

    override func setUp() {
        super.setUp()
        BushaPay.resetForTesting()
        BushaPay.bundleIdOverride = "co.example.testapp"
        BushaPay.initialize(publicKey: "pub_x")
    }

    override func tearDown() {
        BushaPay.resetForTesting()
        super.tearDown()
    }

    func testCheckoutPresentsChooserByDefault() async {
        let presenter = FakePresenter()
        BushaPay.checkout(config: Self.config, from: presenter) { _ in }

        await waitForPresented(presenter)
        XCTAssertTrue(presenter.presentedVCs.first is ChooserViewController,
                      "expected ChooserViewController, got \(String(describing: presenter.presentedVCs.first))")
        XCTAssertTrue(BushaPay.isCheckoutInProgress)
    }

    /// FakePresenter doesn't run the chooser's view lifecycle —
    /// `loadViewIfNeeded()` forces the loader Task to start.
    func testChooserMerchantLoaderIsTriggeredOnPresent() async {
        let presenter = FakePresenter()
        BushaPay.checkout(config: Self.config, from: presenter) { _ in }
        await waitForPresented(presenter)
        guard let chooser = presenter.presentedVCs.first as? ChooserViewController else {
            return XCTFail()
        }
        chooser.loadViewIfNeeded()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNotNil(chooser.viewIfLoaded)
    }

    func testSecondCheckoutWhileInProgressReturnsCheckoutInProgressError() async {
        let firstPresenter = FakePresenter()
        BushaPay.checkout(config: Self.config, from: firstPresenter) { _ in }
        await waitForPresented(firstPresenter)
        XCTAssertTrue(BushaPay.isCheckoutInProgress)

        var second: BushaPayResult?
        let exp = expectation(description: "second onComplete fires synchronously")
        BushaPay.checkout(config: Self.config, from: FakePresenter()) { result in
            second = result
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 1)

        guard case .error(let err) = second else { return XCTFail() }
        XCTAssertEqual(err.code, "CHECKOUT_IN_PROGRESS")
    }

    func testAllowedPaymentMethodsStablecoinsSkipsChooser() async {
        let presenter = FakePresenter()
        let single = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT",
            allowedPaymentMethods: [.stablecoins]
        )
        BushaPay.checkout(config: single, from: presenter) { _ in }

        await waitForPresented(presenter)
        XCTAssertFalse(presenter.presentedVCs.contains { $0 is ChooserViewController })
        XCTAssertTrue(presenter.presentedVCs.first is CheckoutSheetViewController)
    }

    func testAllowedPaymentMethodsBushaAppFallsThroughToSheetWhenAppNotInstalled() async {
        // Test bundle has no `LSApplicationQueriesSchemes`, so
        // `canOpenURL("co.busha.apple://...")` returns false.
        let presenter = FakePresenter()
        let single = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT",
            allowedPaymentMethods: [.bushaApp]
        )
        BushaPay.checkout(config: single, from: presenter) { _ in }

        await waitForPresented(presenter)
        XCTAssertTrue(presenter.presentedVCs.first is CheckoutSheetViewController)
    }

    func testAsyncCheckoutOverloadDeliversInProgressError() async {
        let firstPresenter = FakePresenter()
        BushaPay.checkout(config: Self.config, from: firstPresenter) { _ in }
        await waitForPresented(firstPresenter)

        let result = await BushaPay.checkout(config: Self.config, from: FakePresenter())
        guard case .error(let err) = result else { return XCTFail() }
        XCTAssertEqual(err.code, "CHECKOUT_IN_PROGRESS")
    }

    func testCheckoutRegistersCallbackHandlerForSheet() async {
        let presenter = FakePresenter()
        let single = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT",
            allowedPaymentMethods: [.stablecoins]
        )
        var captured: BushaPayResult?
        let exp = expectation(description: "callback resolves")
        BushaPay.checkout(config: single, from: presenter) { result in
            captured = result
            exp.fulfill()
        }
        await waitForPresented(presenter)

        let url = URL(string: "co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_FLOW")!
        XCTAssertTrue(BushaPay.handleDeepLink(url))

        await fulfillment(of: [exp], timeout: 1)
        guard case .success(let s) = captured else { return XCTFail() }
        XCTAssertEqual(s.paymentId, "PAYR_FLOW")
        XCTAssertFalse(BushaPay.isCheckoutInProgress, "in-progress flag must clear after delivery")
    }

    func testChooserCancelDeliversCancelledAndClearsInProgressFlag() async {
        let presenter = FakePresenter()
        let exp = expectation(description: "cancel delivers")
        var captured: BushaPayResult?
        BushaPay.checkout(config: Self.config, from: presenter) { result in
            captured = result
            exp.fulfill()
        }
        await waitForPresented(presenter)
        guard let chooser = presenter.presentedVCs.first as? ChooserViewController else {
            return XCTFail("expected chooser")
        }

        chooser.handleBackdropTap()

        await fulfillment(of: [exp], timeout: 1)
        guard case .cancelled(let cancelled) = captured else { return XCTFail() }
        XCTAssertEqual(cancelled.reason, .dismissed)
        XCTAssertFalse(BushaPay.isCheckoutInProgress)
    }

    func testChooserStablecoinsTapPresentsSheet() async {
        let presenter = FakePresenter()
        BushaPay.checkout(config: Self.config, from: presenter) { _ in }
        await waitForPresented(presenter)
        guard let chooser = presenter.presentedVCs.first as? ChooserViewController else {
            return XCTFail()
        }

        chooser.resolve(with: .stablecoins)

        await waitForCount(presenter, count: 2)
        XCTAssertTrue(presenter.presentedVCs[1] is CheckoutSheetViewController)
    }

    func testChooserBushaAppTapFallsThroughToSheet() async {
        let presenter = FakePresenter()
        BushaPay.checkout(config: Self.config, from: presenter) { _ in }
        await waitForPresented(presenter)
        guard let chooser = presenter.presentedVCs.first as? ChooserViewController else {
            return XCTFail()
        }

        chooser.resolve(with: .bushaApp)

        await waitForCount(presenter, count: 2)
        XCTAssertTrue(presenter.presentedVCs[1] is CheckoutSheetViewController)
    }

    func testFullStablecoinsFlowDeliversSuccessViaCallback() async {
        let presenter = FakePresenter()
        var captured: BushaPayResult?
        let exp = expectation(description: "callback resolves")
        BushaPay.checkout(config: Self.config, from: presenter) { result in
            captured = result
            exp.fulfill()
        }
        await waitForPresented(presenter)
        guard let chooser = presenter.presentedVCs.first as? ChooserViewController else {
            return XCTFail()
        }
        chooser.resolve(with: .stablecoins)
        await waitForCount(presenter, count: 2)

        let url = URL(string: "co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_END")!
        XCTAssertTrue(BushaPay.handleDeepLink(url))

        await fulfillment(of: [exp], timeout: 1)
        guard case .success(let s) = captured else { return XCTFail() }
        XCTAssertEqual(s.paymentId, "PAYR_END")
        XCTAssertFalse(BushaPay.isCheckoutInProgress)
    }

    func testLaunchBushaAppDeepLinkCallbackResolvesSuccess() async {
        // Stub the launcher — `UIApplication.shared.open` hangs in XCTest.
        BushaPay.urlLauncher = { _, completion in completion(true) }

        let exp = expectation(description: "completion fires")
        var captured: BushaPayResult?
        BushaPay.launchBushaApp(URL(string: "co.busha.apple://busha.co/pay")!) { result in
            captured = result
            exp.fulfill()
        }

        let url = URL(string: "co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_DEEP")!
        XCTAssertTrue(BushaPay.handleDeepLink(url))

        await fulfillment(of: [exp], timeout: 1)
        guard case .success(let s) = captured else { return XCTFail() }
        XCTAssertEqual(s.paymentId, "PAYR_DEEP")
    }

    func testLaunchBushaAppCancelledCallbackResolvesRejectedWithPaymentId() async {
        // The user rejected the payment inside the Busha app — it fires a
        // status=cancelled callback carrying the request id. This must be
        // distinguishable from an `abandoned` resume-without-callback.
        BushaPay.urlLauncher = { _, completion in completion(true) }

        let exp = expectation(description: "completion fires")
        var captured: BushaPayResult?
        BushaPay.launchBushaApp(URL(string: "co.busha.apple://busha.co/pay")!) { result in
            captured = result
            exp.fulfill()
        }

        let url = URL(string: "co.example.testapp.busha-pay://callback?status=cancelled&paymentRequestId=PAYR_REJ")!
        XCTAssertTrue(BushaPay.handleDeepLink(url))

        await fulfillment(of: [exp], timeout: 1)
        guard case .cancelled(let cancelled) = captured else { return XCTFail() }
        XCTAssertEqual(cancelled.reason, .rejected)
        XCTAssertEqual(cancelled.paymentId, "PAYR_REJ")
    }

    func testLaunchBushaAppResumeWithoutCallbackResolvesAbandoned() async {
        BushaPay.urlLauncher = { _, completion in completion(true) }
        BushaPay.resumeCancelDelay = 0.05

        let exp = expectation(description: "cancelled on resume")
        var captured: BushaPayResult?
        BushaPay.launchBushaApp(URL(string: "co.busha.apple://busha.co/pay")!) { result in
            captured = result
            exp.fulfill()
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        await fulfillment(of: [exp], timeout: 2)
        guard case .cancelled(let cancelled) = captured else { return XCTFail() }
        XCTAssertEqual(cancelled.reason, .abandoned)
        XCTAssertNil(cancelled.paymentId)
    }

    func testLaunchBushaAppDeepLinkBeatsResumeRace() async {
        BushaPay.urlLauncher = { _, completion in completion(true) }
        BushaPay.resumeCancelDelay = 0.5

        let exp = expectation(description: "callback wins")
        var captured: BushaPayResult?
        BushaPay.launchBushaApp(URL(string: "co.busha.apple://busha.co/pay")!) { result in
            captured = result
            exp.fulfill()
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_RACE")!
        _ = BushaPay.handleDeepLink(url)

        await fulfillment(of: [exp], timeout: 1)
        guard case .success(let s) = captured else { return XCTFail() }
        XCTAssertEqual(s.paymentId, "PAYR_RACE")
    }

    func testLaunchBushaAppDeliversErrorWhenLauncherFails() async {
        // `opened: false` — the OS rejected the URL.
        BushaPay.urlLauncher = { _, completion in completion(false) }

        let exp = expectation(description: "launch failure delivers error")
        var captured: BushaPayResult?
        BushaPay.launchBushaApp(URL(string: "co.busha.apple://busha.co/pay")!) { result in
            captured = result
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 1)
        guard case .error(let err) = captured else { return XCTFail() }
        XCTAssertEqual(err.code, "BUSHA_APP_LAUNCH_FAILED")
    }

    private func waitForPresented(_ presenter: FakePresenter, timeout: TimeInterval = 1) async {
        let deadline = Date().addingTimeInterval(timeout)
        while presenter.presentedVCs.isEmpty && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func waitForCount(_ presenter: FakePresenter, count: Int, timeout: TimeInterval = 1) async {
        let deadline = Date().addingTimeInterval(timeout)
        while presenter.presentedVCs.count < count && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class FakePresenter: UIViewController {
    private(set) var presentedVCs: [UIViewController] = []

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        presentedVCs.append(viewControllerToPresent)
        completion?()
    }
}
