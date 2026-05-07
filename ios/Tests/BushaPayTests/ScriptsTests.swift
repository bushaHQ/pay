import XCTest
@testable import BushaPay

final class ScriptsTests: XCTestCase {
    func testAutoSelectEscapesPrefixSafely() {
        let script = Scripts.autoSelect(rowTextPrefix: #"Bus"ha"#)
        XCTAssertTrue(script.contains(#""Bus\"ha""#))
    }

    func testInitCheckoutEmbedsPayload() {
        let script = Scripts.initCheckout(payloadJson: #"{"a":1}"#)
        XCTAssertEqual(script, #"initCheckout({"a":1});"#)
    }

    func testJsonEncodeMatchesJsonStringify() {
        XCTAssertEqual(jsonEncode("plain"), #""plain""#)
        XCTAssertEqual(jsonEncode(#"with "quotes""#), #""with \"quotes\"""#)
    }
}
