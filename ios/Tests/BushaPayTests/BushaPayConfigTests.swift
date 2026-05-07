import XCTest
@testable import BushaPay

final class BushaPayConfigTests: XCTestCase {
    func testRequiredFormFieldsArePresent() {
        let config = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT"
        )
        let fields = config.toFormFields(
            publicKey: "pub_x",
            callbackUrl: "scheme://callback",
            checkoutUrl: "https://pay.busha.co/pay"
        )
        XCTAssertEqual(fields["public_key"], "pub_x")
        XCTAssertEqual(fields["quote_amount"], "10000")
        XCTAssertEqual(fields["quote_currency"], "NGN")
        XCTAssertEqual(fields["target_currency"], "NGN")
        XCTAssertEqual(fields["source_currency"], "USDT")
        XCTAssertEqual(fields["callback_url"], "scheme://callback")
        XCTAssertEqual(fields["displayMode"], "INLINE")
        XCTAssertEqual(fields["parentOrigin"], "https://pay.busha.co")
    }

    func testOptionalFieldsOmittedWhenNil() {
        let config = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT"
        )
        let fields = config.toFormFields(
            publicKey: "pub_x",
            callbackUrl: "scheme://callback",
            checkoutUrl: "https://pay.busha.co/pay"
        )
        XCTAssertNil(fields["reference"])
        XCTAssertNil(fields["meta[name]"])
        XCTAssertNil(fields["meta[email]"])
        XCTAssertNil(fields["meta[phone_number]"])
    }

    func testOptionalFieldsForwardedWhenSet() {
        let config = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT",
            reference: "ORDER_42",
            metaName: "Jane Doe",
            metaEmail: "jane@example.com",
            metaPhone: "+15551234567"
        )
        let fields = config.toFormFields(
            publicKey: "pub_x",
            callbackUrl: "scheme://callback",
            checkoutUrl: "https://pay.busha.co/pay"
        )
        XCTAssertEqual(fields["reference"], "ORDER_42")
        XCTAssertEqual(fields["meta[name]"], "Jane Doe")
        XCTAssertEqual(fields["meta[email]"], "jane@example.com")
        XCTAssertEqual(fields["meta[phone_number]"], "+15551234567")
    }

    func testAllowedPaymentMethodsRoundTripsThroughInit() {
        let config = BushaPayConfig(
            quoteAmount: "10000",
            quoteCurrency: "NGN",
            targetCurrency: "NGN",
            sourceCurrency: "USDT",
            allowedPaymentMethods: [.bushaApp]
        )
        XCTAssertEqual(config.allowedPaymentMethods, [.bushaApp])
    }
}
