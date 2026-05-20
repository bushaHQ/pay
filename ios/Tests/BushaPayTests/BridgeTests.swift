import XCTest
@testable import BushaPay

final class BridgeTests: XCTestCase {
    func testReady() {
        if case .ready = parseBridgeMessage(#"{"type":"ready"}"#) {} else {
            XCTFail("expected .ready")
        }
    }

    func testSuccessExtractsCommerceJsPayload() {
        let json = #"""
        {"type":"success","data":{"data":{"id":"PAYR_42","status":"completed","source_amount":"0.01"}}}
        """#
        guard case .result(.success(let success)) = parseBridgeMessage(json) else {
            return XCTFail("expected .success")
        }
        XCTAssertEqual(success.paymentId, "PAYR_42")
        XCTAssertEqual(success.sourceAmount, "0.01")
    }

    func testCloseMapsToCancelled() {
        if case .result(.cancelled(let cancelled)) = parseBridgeMessage(#"{"type":"close"}"#) {
            XCTAssertEqual(cancelled.reason, .dismissed)
        } else {
            XCTFail("expected .cancelled")
        }
    }

    func testErrorMessageAndCode() {
        let json = #"{"type":"error","data":{"message":"No signal","code":"NET_DOWN"}}"#
        guard case .result(.error(let err)) = parseBridgeMessage(json) else {
            return XCTFail("expected .error")
        }
        XCTAssertEqual(err.message, "No signal")
        XCTAssertEqual(err.code, "NET_DOWN")
    }

    func testErrorWithoutDataFallsBackToDefaults() {
        guard case .result(.error(let err)) = parseBridgeMessage(#"{"type":"error"}"#) else {
            return XCTFail("expected .error")
        }
        XCTAssertEqual(err.message, "An error occurred")
        XCTAssertNil(err.code)
    }

    func testUnparseableJsonIsUnknown() {
        if case .unknown = parseBridgeMessage("not json") {} else { XCTFail() }
    }

    func testUnknownTypeIsUnknown() {
        if case .unknown = parseBridgeMessage(#"{"type":"unknown"}"#) {} else { XCTFail() }
    }
}
