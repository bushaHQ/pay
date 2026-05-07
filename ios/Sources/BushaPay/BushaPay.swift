import Foundation
import UIKit

/// Busha Pay SDK for iOS.
///
/// Initialize once, then call ``checkout(config:from:onComplete:)`` to
/// launch the payment flow.
///
/// ```swift
/// BushaPay.initialize(publicKey: "pub_xxx", environment: .sandbox)
///
/// BushaPay.checkout(
///     config: BushaPayConfig(
///         quoteAmount: "10000",
///         quoteCurrency: "NGN",
///         targetCurrency: "NGN",
///         sourceCurrency: "USDT"
///     ),
///     from: viewController
/// ) { result in
///     switch result { ... }
/// }
/// ```
///
/// Every entry point — including ``handleDeepLink(_:)`` — must be called
/// on the main thread. The compiler enforces this via `@MainActor`.
@MainActor
public enum BushaPay {
    private static var _publicKey: String?
    private static var _environment: BushaEnvironment = .live
    private static var _bundleId: String?
    private static var _isCheckoutInProgress = false
    private static var _directLaunchHandler: ((URL) -> Void)?
    private static var _pendingCallbackHandler: ((URL) -> Void)?

    static var resourceBundleOverride: Bundle?
    static var bundleIdOverride: String?

    public static var isInitialized: Bool { _publicKey != nil }
    public static var isCheckoutInProgress: Bool { _isCheckoutInProgress }

    public static var publicKey: String {
        precondition(_publicKey != nil, "BushaPay.initialize() must be called first")
        return _publicKey!
    }

    public static var isDevMode: Bool { _environment == .sandbox }

    public static var checkoutUrl: String {
        isDevMode ? "https://staging.pay.busha.io/pay" : "https://pay.busha.io/pay"
    }

    public static var platformUrl: String {
        isDevMode ? "https://api.sandbox.busha.so" : "https://api.busha.io"
    }

    /// The callback URL scheme this app receives Busha Pay callbacks on.
    /// Derived as `<bundle-id>.busha-pay`.
    public static var callbackScheme: String {
        let bundleId = bundleIdOverride ?? _bundleId ?? Bundle.main.bundleIdentifier ?? "app"
        return "\(bundleId).busha-pay"
    }

    public static var callbackUrl: String { "\(callbackScheme)://callback" }

    /// Initialize the SDK. Call once at app startup before any
    /// ``checkout(config:from:onComplete:)`` invocation.
    public static func initialize(
        publicKey: String,
        environment: BushaEnvironment = .live
    ) {
        _publicKey = publicKey
        _environment = environment
        _bundleId = Bundle.main.bundleIdentifier
    }

    /// Launches the Busha Pay checkout flow. `onComplete` is called
    /// exactly once on the main thread.
    public static func checkout(
        config: BushaPayConfig,
        from presenter: UIViewController,
        onComplete: @escaping (BushaPayResult) -> Void
    ) {
        precondition(isInitialized, "BushaPay.initialize() must be called before checkout")

        if _isCheckoutInProgress {
            onComplete(.error(BushaPayError(message: "Another payment is already in progress", code: "CHECKOUT_IN_PROGRESS")))
            return
        }

        _isCheckoutInProgress = true
        runCheckout(config: config, from: presenter) { result in
            _isCheckoutInProgress = false
            DispatchQueue.main.async { onComplete(result) }
        }
    }

    /// Async overload. Failures surface as ``BushaPayResult/error(_:)`` —
    /// never throws.
    public static func checkout(
        config: BushaPayConfig,
        from presenter: UIViewController
    ) async -> BushaPayResult {
        await withCheckedContinuation { continuation in
            checkout(config: config, from: presenter) { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// Forwards a URL to the SDK. Returns `true` if the URL was a Busha
    /// Pay callback the SDK consumed. Wire into your app's URL handler
    /// (`onOpenURL`, `application(_:open:options:)`, or `scene(_:openURLContexts:)`).
    @discardableResult
    public static func handleDeepLink(_ url: URL) -> Bool {
        guard
            let scheme = url.scheme,
            let host = url.host,
            scheme == callbackScheme,
            host == "callback"
        else {
            return false
        }
        if let handler = _directLaunchHandler {
            handler(url)
            return true
        }
        _pendingCallbackHandler?(url)
        return true
    }

    static func registerCallbackHandler(_ handler: @escaping (URL) -> Void) {
        _pendingCallbackHandler = handler
    }

    static func unregisterCallbackHandler() {
        _pendingCallbackHandler = nil
    }

    static func parseCallback(_ url: URL) -> BushaPayResult {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let lookup = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        let status = lookup["status"]
        let paymentRequestId = lookup["paymentRequestId"] ?? ""
        switch status {
        case "completed":
            return .success(BushaPaySuccess.fromCallback(paymentId: paymentRequestId))
        case "cancelled":
            return .cancelled
        default:
            let code = lookup["error_code"] ?? status ?? "unknown"
            let message = lookup["error_message"] ?? "Payment failed"
            return .error(BushaPayError(message: message, code: code))
        }
    }

    private static func runCheckout(
        config: BushaPayConfig,
        from presenter: UIViewController,
        completion: @escaping (BushaPayResult) -> Void
    ) {
        let allowed = config.allowedPaymentMethods

        if let allowed, allowed.count == 1, let only = allowed.first {
            DispatchQueue.main.async {
                routeAfterChoice(method: only, config: config, from: presenter, completion: completion)
            }
            return
        }

        let chooser = ChooserViewController(
            config: config,
            allowedPaymentMethods: allowed,
            merchantNameLoader: {
                await MerchantAPI.fetchName(publicKey: publicKey, platformUrl: platformUrl)
            },
            completion: { method in
                guard let method else {
                    completion(.cancelled)
                    return
                }
                routeAfterChoice(method: method, config: config, from: presenter, completion: completion)
            }
        )
        DispatchQueue.main.async {
            presenter.present(chooser, animated: true)
        }
    }

    private static func routeAfterChoice(
        method: PaymentMethod,
        config: BushaPayConfig,
        from presenter: UIViewController,
        completion: @escaping (BushaPayResult) -> Void
    ) {
        if method == .bushaApp {
            let scheme = DeepLink.bushaAppScheme(_environment)
            if let deepLink = DeepLink.buildBushaAppDeepLink(scheme: scheme, config: config, publicKey: publicKey, callbackUrl: callbackUrl),
               UIApplication.shared.canOpenURL(deepLink) {
                launchBushaApp(deepLink, completion: completion)
                return
            }
        }
        let auto: AutoSelect = (method == .bushaApp) ? .bushaApp : .stablecoins
        presentSheet(config: config, autoSelect: auto, from: presenter, completion: completion)
    }

    static var resumeCancelDelay: TimeInterval = 1.5

    static var urlLauncher: (URL, @escaping (Bool) -> Void) -> Void = { url, completion in
        UIApplication.shared.open(url, options: [:], completionHandler: completion)
    }

    static func launchBushaApp(_ url: URL, completion: @escaping (BushaPayResult) -> Void) {
        var didFinish = false
        let resumeNotification = UIApplication.didBecomeActiveNotification
        var observer: NSObjectProtocol?

        let finish: (BushaPayResult) -> Void = { result in
            if didFinish { return }
            didFinish = true
            _directLaunchHandler = nil
            if let observer { NotificationCenter.default.removeObserver(observer) }
            DispatchQueue.main.async { completion(result) }
        }

        _directLaunchHandler = { url in finish(parseCallback(url)) }

        // Resume without a matching callback inside the grace window
        // means the user came back without paying.
        let delay = resumeCancelDelay
        observer = NotificationCenter.default.addObserver(forName: resumeNotification, object: nil, queue: .main) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if !didFinish { finish(.cancelled) }
            }
        }

        urlLauncher(url) { opened in
            if !opened {
                finish(.error(BushaPayError(message: "Could not open the Busha app", code: "BUSHA_APP_LAUNCH_FAILED")))
            }
        }
    }

    private static func presentSheet(
        config: BushaPayConfig,
        autoSelect: AutoSelect,
        from presenter: UIViewController,
        completion: @escaping (BushaPayResult) -> Void
    ) {
        let bundle = resourceBundleOverride ?? Bundle.module

        // Every terminal path tears down the pending-callback handler;
        // skipping this would leave a closure bound to a dismissed sheet
        // that a later (stale) callback could fire into.
        var didFire = false
        let wrappedCompletion: (BushaPayResult) -> Void = { result in
            guard !didFire else { return }
            didFire = true
            unregisterCallbackHandler()
            completion(result)
        }

        let sheet = CheckoutSheetViewController(
            config: config,
            publicKey: publicKey,
            callbackUrl: callbackUrl,
            checkoutUrl: checkoutUrl,
            autoSelect: autoSelect,
            resourceBundle: bundle,
            completion: wrappedCompletion
        )
        registerCallbackHandler { url in
            sheet.dismiss(animated: true) {
                wrappedCompletion(parseCallback(url))
            }
        }
        // Present from the topmost VC — the chooser may still be on screen.
        let presentOn: UIViewController = {
            var top = presenter
            while let presented = top.presentedViewController { top = presented }
            return top
        }()
        DispatchQueue.main.async {
            presentOn.present(sheet, animated: true)
        }
    }

    static func resetForTesting() {
        _publicKey = nil
        _environment = .live
        _bundleId = nil
        _isCheckoutInProgress = false
        _directLaunchHandler = nil
        _pendingCallbackHandler = nil
        resourceBundleOverride = nil
        bundleIdOverride = nil
        resumeCancelDelay = 1.5
        urlLauncher = { url, completion in
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
        }
    }
}
