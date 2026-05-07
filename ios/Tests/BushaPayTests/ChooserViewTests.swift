import XCTest
@testable import BushaPay

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
}
