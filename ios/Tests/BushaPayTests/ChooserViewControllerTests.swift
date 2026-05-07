import XCTest
import UIKit
@testable import BushaPay

@MainActor
final class ChooserViewControllerTests: XCTestCase {
    private static let config = BushaPayConfig(
        quoteAmount: "10000",
        quoteCurrency: "NGN",
        targetCurrency: "NGN",
        sourceCurrency: "USDT"
    )

    private func makeChooser(
        allowed: [PaymentMethod]? = nil,
        loader: @escaping () async -> String? = { nil },
        completion: @escaping (PaymentMethod?) -> Void
    ) -> ChooserViewController {
        let chooser = ChooserViewController(
            config: Self.config,
            allowedPaymentMethods: allowed,
            merchantNameLoader: loader,
            completion: completion
        )
        chooser.loadViewIfNeeded()
        return chooser
    }

    func testResolveWithBushaAppFiresCompletion() {
        var captured: PaymentMethod??
        let chooser = makeChooser { captured = $0 }
        chooser.resolve(with: .bushaApp)
        XCTAssertEqual(captured, .some(.bushaApp))
        XCTAssertTrue(chooser.didComplete)
    }

    func testResolveWithStablecoinsFiresCompletion() {
        var captured: PaymentMethod??
        let chooser = makeChooser { captured = $0 }
        chooser.resolve(with: .stablecoins)
        XCTAssertEqual(captured, .some(.stablecoins))
    }

    func testBackdropTapResolvesWithNil() {
        var captured: PaymentMethod??
        let chooser = makeChooser { captured = $0 }
        chooser.handleBackdropTap()
        XCTAssertEqual(captured, .some(nil))
    }

    func testRepeatResolveIsIgnored() {
        var fireCount = 0
        let chooser = makeChooser { _ in fireCount += 1 }
        chooser.resolve(with: .bushaApp)
        chooser.resolve(with: .stablecoins)
        chooser.handleBackdropTap()
        XCTAssertEqual(fireCount, 1)
    }

    func testMerchantNameLoaderIsCalled() async {
        let loaderCalled = expectation(description: "loader called")
        let chooser = makeChooser(
            loader: {
                loaderCalled.fulfill()
                return "Pushup Design Agency"
            },
            completion: { _ in }
        )
        await fulfillment(of: [loaderCalled], timeout: 1)
        // Also verify the chooser stays alive long enough for the async
        // task to resolve without crashing.
        XCTAssertNotNil(chooser.view)
    }

    func testNilMerchantNameDoesNotCrash() async {
        let loaderCalled = expectation(description: "loader returns nil")
        // Keep a strong reference — the loader Task holds `[weak self]`,
        // so a dropped chooser would silently never run the loader.
        let chooser = makeChooser(
            loader: {
                loaderCalled.fulfill()
                return nil
            },
            completion: { _ in }
        )
        await fulfillment(of: [loaderCalled], timeout: 1)
        XCTAssertNotNil(chooser.view)
    }

    func testAllowedPaymentMethodsAreStoredOnTheView() {
        // The chooser view isn't easy to introspect from XCTest without
        // ViewInspector, but we can confirm the controller accepts the
        // value without crashing across all expected shapes.
        for allowed: [PaymentMethod]? in [nil, [], [.bushaApp], [.stablecoins], [.bushaApp, .stablecoins]] {
            let chooser = makeChooser(allowed: allowed) { _ in }
            chooser.resolve(with: nil)
            XCTAssertTrue(chooser.didComplete)
        }
    }
}
