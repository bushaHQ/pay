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
public enum BushaPay {
    private static let queue = DispatchQueue(label: "co.busha.pay.sdk")
    private static var _publicKey: String?
    private static var _environment: BushaEnvironment = .live
    private static var _bundleId: String?
    private static var _isCheckoutInProgress = false
    private static var _directLaunchHandler: ((URL) -> Void)?
    private static var _pendingCallbackHandler: ((URL) -> Void)?

    /// Bundle override for testing — production reads `Bundle.module`.
    static var resourceBundleOverride: Bundle?
    /// Bundle override for the merchant app's bundle identifier.
    static var bundleIdOverride: String?

    // MARK: - Public state

    /// Whether the SDK has been initialized.
    public static var isInitialized: Bool { _publicKey != nil }

    /// Whether a checkout is currently in progress.
    public static var isCheckoutInProgress: Bool { _isCheckoutInProgress }

    /// The configured public key.
    public static var publicKey: String {
        precondition(_publicKey != nil, "BushaPay.initialize() must be called first")
        return _publicKey!
    }

    /// Whether the SDK is in dev/sandbox mode.
    public static var isDevMode: Bool { _environment == .sandbox }

    /// The checkout page URL for the current environment.
    public static var checkoutUrl: String {
        isDevMode ? "https://staging.pay.busha.co/pay" : "https://pay.busha.co/pay"
    }

    /// The Busha platform API base URL for the current environment.
    public static var platformUrl: String {
        isDevMode ? "https://api.sandbox.busha.so" : "https://api.busha.io"
    }

    /// The callback URL scheme for this app, derived from the bundle ID.
    public static var callbackScheme: String {
        let bundleId = bundleIdOverride ?? _bundleId ?? Bundle.main.bundleIdentifier ?? "app"
        return "\(bundleId).busha-pay"
    }

    /// The full callback URL for this app (e.g. `com.example.app.busha-pay://callback`).
    public static var callbackUrl: String { "\(callbackScheme)://callback" }

    // MARK: - Initialization

    /// Initialize the Busha Pay SDK.
    ///
    /// Call once at app startup, e.g. in `application(_:didFinishLaunchingWithOptions:)`.
    public static func initialize(
        publicKey: String,
        environment: BushaEnvironment = .live
    ) {
        _publicKey = publicKey
        _environment = environment
        _bundleId = Bundle.main.bundleIdentifier
    }

    /// Launches the Busha Pay checkout flow.
    ///
    /// `onComplete` is called exactly once on the main thread.
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

    /// Async/await variant. Returns the result; never throws — failures
    /// are surfaced as ``BushaPayResult/error(_:)``.
    public static func checkout(
        config: BushaPayConfig,
        from presenter: UIViewController
    ) async -> BushaPayResult {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                checkout(config: config, from: presenter) { result in
                    continuation.resume(returning: result)
                }
            }
        }
    }

    /// Forwards a deep-link URL to the SDK. Returns `true` if the URL was a
    /// Busha Pay callback the SDK consumed.
    ///
    /// Wire this into your app's URL handler (`UIApplicationDelegate
    /// .application(_:open:options:)` or `UIWindowSceneDelegate.scene(_:openURLContexts:)`).
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
            // Single allowed method — skip the chooser.
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

    private static func launchBushaApp(_ url: URL, completion: @escaping (BushaPayResult) -> Void) {
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

        observer = NotificationCenter.default.addObserver(forName: resumeNotification, object: nil, queue: .main) { _ in
            // If the merchant app resumes and no callback arrives within
            // 1.5s, treat it as the user backing out of the Busha app.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if !didFinish { finish(.cancelled) }
            }
        }

        UIApplication.shared.open(url, options: [:]) { opened in
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
        let sheet = CheckoutSheetViewController(
            config: config,
            publicKey: publicKey,
            callbackUrl: callbackUrl,
            checkoutUrl: checkoutUrl,
            autoSelect: autoSelect,
            resourceBundle: bundle,
            completion: completion
        )
        registerCallbackHandler { url in
            sheet.dismiss(animated: true) {
                unregisterCallbackHandler()
                completion(parseCallback(url))
            }
        }
        let presentOn: UIViewController = {
            // The chooser may still be on screen — present from the top.
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
    }
}
