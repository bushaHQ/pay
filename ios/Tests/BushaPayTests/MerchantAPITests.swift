import XCTest
@testable import BushaPay

final class MerchantAPITests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        session = nil
        super.tearDown()
    }

    func testReturnsUsernameOn200WithValidJson() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/merchants")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-BU-PUBLIC-KEY"), "pub_x")
            let body = #"{"data": {"username": "Pushup Design Agency"}}"#.data(using: .utf8)!
            return (Self.response(200), body)
        }

        let name = await MerchantAPI.fetchName(
            publicKey: "pub_x",
            platformUrl: "https://api.busha.io",
            session: session
        )
        XCTAssertEqual(name, "Pushup Design Agency")
    }

    func testReturnsNilOn4xx() async {
        MockURLProtocol.requestHandler = { _ in (Self.response(404), Data()) }
        let name = await MerchantAPI.fetchName(publicKey: "pub_x", platformUrl: "https://api.busha.io", session: session)
        XCTAssertNil(name)
    }

    func testReturnsNilOn5xx() async {
        MockURLProtocol.requestHandler = { _ in (Self.response(500), Data()) }
        let name = await MerchantAPI.fetchName(publicKey: "pub_x", platformUrl: "https://api.busha.io", session: session)
        XCTAssertNil(name)
    }

    func testReturnsNilOnNon2xxEvenWithValidJson() async {
        MockURLProtocol.requestHandler = { _ in
            (Self.response(401), #"{"data": {"username": "Foo"}}"#.data(using: .utf8)!)
        }
        let name = await MerchantAPI.fetchName(publicKey: "pub_x", platformUrl: "https://api.busha.io", session: session)
        XCTAssertNil(name)
    }

    func testReturnsNilWhenJsonMalformed() async {
        MockURLProtocol.requestHandler = { _ in (Self.response(200), Data("not json".utf8)) }
        let name = await MerchantAPI.fetchName(publicKey: "pub_x", platformUrl: "https://api.busha.io", session: session)
        XCTAssertNil(name)
    }

    func testReturnsNilWhenDataKeyMissing() async {
        MockURLProtocol.requestHandler = { _ in (Self.response(200), Data(#"{"foo": "bar"}"#.utf8)) }
        let name = await MerchantAPI.fetchName(publicKey: "pub_x", platformUrl: "https://api.busha.io", session: session)
        XCTAssertNil(name)
    }

    func testReturnsNilWhenUsernameMissing() async {
        MockURLProtocol.requestHandler = { _ in
            (Self.response(200), Data(#"{"data": {"name": "Foo"}}"#.utf8))
        }
        let name = await MerchantAPI.fetchName(publicKey: "pub_x", platformUrl: "https://api.busha.io", session: session)
        XCTAssertNil(name)
    }

    func testReturnsNilWhenUsernameEmptyString() async {
        MockURLProtocol.requestHandler = { _ in
            (Self.response(200), Data(#"{"data": {"username": ""}}"#.utf8))
        }
        let name = await MerchantAPI.fetchName(publicKey: "pub_x", platformUrl: "https://api.busha.io", session: session)
        XCTAssertNil(name)
    }

    func testReturnsNilOnNetworkError() async {
        MockURLProtocol.errorToThrow = URLError(.notConnectedToInternet)
        let name = await MerchantAPI.fetchName(publicKey: "pub_x", platformUrl: "https://api.busha.io", session: session)
        XCTAssertNil(name)
        MockURLProtocol.errorToThrow = nil
    }

    func testReturnsNilOnInvalidPlatformUrl() async {
        let name = await MerchantAPI.fetchName(publicKey: "pub_x", platformUrl: "not a url", session: session)
        XCTAssertNil(name)
    }

    private static func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.busha.io/v1/merchants")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

/// Stubs URLSession requests for tests. Set `requestHandler` to return a
/// response/body pair, or `errorToThrow` to simulate a network failure.
final class MockURLProtocol: URLProtocol {
    static var requestHandler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data?))?
    static var errorToThrow: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = MockURLProtocol.errorToThrow {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
