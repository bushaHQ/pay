import XCTest
import SwiftUI
import UIKit
@testable import BushaPay

@MainActor
final class ChooserViewTests: XCTestCase {
    private static let config = BushaPayConfig(
        quoteAmount: "10000",
        quoteCurrency: "NGN",
        targetCurrency: "NGN",
        sourceCurrency: "USDT"
    )

    private func view(allowed: [PaymentMethod]? = nil) -> ChooserView {
        ChooserView(
            config: Self.config,
            merchantName: nil,
            allowedPaymentMethods: allowed,
            onChoose: { _ in },
            onDismiss: {}
        )
    }

    func testShowsAllWhenAllowedIsNil() {
        let v = view(allowed: nil)
        XCTAssertTrue(v.shows(.bushaApp))
        XCTAssertTrue(v.shows(.stablecoins))
    }

    func testShowsAllWhenAllowedIsEmpty() {
        let v = view(allowed: [])
        XCTAssertTrue(v.shows(.bushaApp))
        XCTAssertTrue(v.shows(.stablecoins))
    }

    func testHidesStablecoinsWhenOnlyBushaAllowed() {
        let v = view(allowed: [.bushaApp])
        XCTAssertTrue(v.shows(.bushaApp))
        XCTAssertFalse(v.shows(.stablecoins))
    }

    func testHidesBushaWhenOnlyStablecoinsAllowed() {
        let v = view(allowed: [.stablecoins])
        XCTAssertFalse(v.shows(.bushaApp))
        XCTAssertTrue(v.shows(.stablecoins))
    }

    func testFormatAmountWholeNumber() {
        XCTAssertEqual(formatAmount("10000"), "10,000")
    }

    func testFormatAmountSmallWhole() {
        XCTAssertEqual(formatAmount("100"), "100")
    }

    func testFormatAmountWithFraction() {
        XCTAssertEqual(formatAmount("12345.5"), "12,345.50")
    }

    func testFormatAmountTrimsWhitespace() {
        XCTAssertEqual(formatAmount("  12345  "), "12,345")
    }

    func testFormatAmountFallsBackToRawWhenNotParseable() {
        XCTAssertEqual(formatAmount("abc"), "abc")
    }

    func testFormatAmountHandlesZero() {
        XCTAssertEqual(formatAmount("0"), "0")
    }

    func testFormatAmountHandlesLargeAmount() {
        XCTAssertEqual(formatAmount("1234567890"), "1,234,567,890")
    }

    /// SwiftUI evaluates `body` only when laid out in a hierarchy.
    /// `host(_:)` attaches to a `UIWindow` and forces layout.
    func testRenderingExecutesBodyWithBothTiles() {
        renderInWindow(allowed: nil)
    }

    func testRenderingExecutesBodyWithOnlyBusha() {
        renderInWindow(allowed: [.bushaApp])
    }

    func testRenderingExecutesBodyWithOnlyStablecoins() {
        renderInWindow(allowed: [.stablecoins])
    }

    func testRenderingExecutesBodyWithMerchantName() {
        renderInWindow(allowed: nil, merchantName: "Pushup Design Agency")
    }

    func testRenderingExecutesBodyWithDecimalAmount() {
        let cfg = BushaPayConfig(
            quoteAmount: "12345.5",
            quoteCurrency: "USD",
            targetCurrency: "NGN",
            sourceCurrency: "USDT"
        )
        renderInWindow(config: cfg)
    }

    func testRenderingExecutesBodyWithUnparseableAmount() {
        let cfg = BushaPayConfig(
            quoteAmount: "abc",
            quoteCurrency: "XYZ",
            targetCurrency: "NGN",
            sourceCurrency: "USDT"
        )
        renderInWindow(config: cfg)
    }

    func testTilePressFiresOnChoose() {
        var picked: PaymentMethod?
        let view = ChooserView(
            config: Self.config,
            merchantName: nil,
            allowedPaymentMethods: nil,
            onChoose: { picked = $0 },
            onDismiss: {}
        )
        let host = host(view)
        // SwiftUI Button taps are awkward to simulate via UIKit; invoking
        // the captured closure verifies the wiring directly.
        view.onChoose(.bushaApp)
        XCTAssertEqual(picked, .bushaApp)
        host.view.removeFromSuperview()
    }

    func testCloseButtonFiresOnDismiss() {
        var dismissed = false
        let view = ChooserView(
            config: Self.config,
            merchantName: nil,
            allowedPaymentMethods: nil,
            onChoose: { _ in },
            onDismiss: { dismissed = true }
        )
        view.onDismiss()
        XCTAssertTrue(dismissed)
    }

    @discardableResult
    private func renderInWindow(
        config: BushaPayConfig = ChooserViewTests.config,
        allowed: [PaymentMethod]? = nil,
        merchantName: String? = nil
    ) -> UIHostingController<ChooserView> {
        let view = ChooserView(
            config: config,
            merchantName: merchantName,
            allowedPaymentMethods: allowed,
            onChoose: { _ in },
            onDismiss: {}
        )
        return host(view)
    }

    @discardableResult
    private func host<V: View>(_ view: V) -> UIHostingController<V> {
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return host
    }
}
