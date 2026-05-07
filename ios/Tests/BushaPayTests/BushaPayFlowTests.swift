import XCTest
import UIKit
@testable import BushaPay

/// End-to-end-ish tests for ``BushaPay/checkout(config:from:onComplete:)``.
/// We intercept `UIViewController.present(_:animated:completion:)` on a
/// fake presenter so we can observe which VC the SDK tried to show
/// without needing a real window or simulator UI.
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
        // The test bundle has no `LSApplicationQueriesSchemes` for the
        // Busha app, so `UIApplication.canOpenURL(...)` returns false
        // and the SDK should fall through to the WebView checkout.
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
        // For the stablecoins path we go straight to the sheet, which
        // must be wired to receive deep-link callbacks.
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

        // Simulate the Busha app firing back via a deep link.
        let url = URL(string: "co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_FLOW")!
        XCTAssertTrue(BushaPay.handleDeepLink(url))

        await fulfillment(of: [exp], timeout: 1)
        guard case .success(let s) = captured else { return XCTFail() }
        XCTAssertEqual(s.paymentId, "PAYR_FLOW")
        XCTAssertFalse(BushaPay.isCheckoutInProgress, "in-progress flag must clear after delivery")
    }

    // MARK: helpers

    private func waitForPresented(_ presenter: FakePresenter, timeout: TimeInterval = 1) async {
        let deadline = Date().addingTimeInterval(timeout)
        while presenter.presentedVCs.isEmpty && Date() < deadline {
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
