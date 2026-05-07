import XCTest
@testable import BushaPay

final class BushaPayResultTests: XCTestCase {
    func testFromCallbackProducesLimitedData() {
        let success = BushaPaySuccess.fromCallback(paymentId: "PAYR_42")
        XCTAssertEqual(success.paymentId, "PAYR_42")
        XCTAssertEqual(success.status, "completed")
        XCTAssertFalse(success.hasFullData)
        XCTAssertNil(success.sourceAmount)
        XCTAssertNil(success.targetAmount)
    }

    func testFromCommerceJsExtractsKnownFields() {
        let payload: [String: Any] = [
            "data": [
                "id": "PAYR_99",
                "status": "completed",
                "source_amount": "0.01",
                "source_currency": "BTC",
                "target_amount": "10000",
                "target_currency": "NGN",
                "requested_amount": "10000",
                "currency": "NGN",
            ],
        ]
        let success = BushaPaySuccess.fromCommerceJs(payload)
        XCTAssertEqual(success.paymentId, "PAYR_99")
        XCTAssertEqual(success.status, "completed")
        XCTAssertEqual(success.sourceAmount, "0.01")
        XCTAssertEqual(success.targetAmount, "10000")
        XCTAssertTrue(success.hasFullData)
    }

    func testFromCommerceJsFallsBackToReferenceWhenIdMissing() {
        let success = BushaPaySuccess.fromCommerceJs([
            "data": ["reference": "REF_X", "status": "completed"],
        ])
        XCTAssertEqual(success.paymentId, "REF_X")
    }

    func testFromCommerceJsHandlesFlatPayload() {
        let success = BushaPaySuccess.fromCommerceJs([
            "id": "PAYR_FLAT",
            "status": "completed",
        ])
        XCTAssertEqual(success.paymentId, "PAYR_FLAT")
    }
}
