import UIKit
import WebKit

enum AutoSelect {
    case none, bushaApp, stablecoins

    var queryParam: String? {
        switch self {
        case .bushaApp: return "busha"
        case .stablecoins: return "stablecoins"
        case .none: return nil
        }
    }

    var rowTextPrefix: String? {
        switch self {
        case .bushaApp: return "Busha"
        case .stablecoins: return "Stablecoins"
        case .none: return nil
        }
    }
}

/// `processBridgePayload`, `handleNavigationError`, and
/// `handleHttpStatusForMainFrame` are split out from the delegate glue
/// because `WKScriptMessage` / `WKNavigation` are `final` and have no
/// public init — tests drive these helpers directly.
final class CheckoutSheetViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate, UIAdaptivePresentationControllerDelegate {
    static let defaultBootstrapTimeout: TimeInterval = 30

    private let config: BushaPayConfig
    private let publicKey: String
    private let callbackUrl: String
    private let checkoutUrl: String
    private let autoSelect: AutoSelect
    private let resourceBundle: Bundle
    private let bootstrapTimeout: TimeInterval
    private let skipWebViewSetup: Bool
    private let completion: (BushaPayResult) -> Void

    private var webView: WKWebView?
    private var loadingView: UIView?
    private(set) var didDeliverResult = false
    private var formSubmitted = false
    private(set) var checkoutInitialized = false
    private(set) var bootstrapTimer: Timer?

    init(
        config: BushaPayConfig,
        publicKey: String,
        callbackUrl: String,
        checkoutUrl: String,
        autoSelect: AutoSelect,
        resourceBundle: Bundle,
        bootstrapTimeout: TimeInterval = CheckoutSheetViewController.defaultBootstrapTimeout,
        skipWebViewSetup: Bool = false,
        completion: @escaping (BushaPayResult) -> Void
    ) {
        self.config = config
        self.publicKey = publicKey
        self.callbackUrl = callbackUrl
        self.checkoutUrl = checkoutUrl
        self.autoSelect = autoSelect
        self.resourceBundle = resourceBundle
        self.bootstrapTimeout = bootstrapTimeout
        self.skipWebViewSetup = skipWebViewSetup
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .pageSheet
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        bootstrapTimer?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // Without this, a swipe-down dismiss never delivers a result
        // and the merchant's completion hangs.
        presentationController?.delegate = self

        if !skipWebViewSetup {
            setupWebView()
            addLoadingOverlay()
            loadHtml()
        }

        bootstrapTimer = Timer.scheduledTimer(withTimeInterval: bootstrapTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.didDeliverResult || self.checkoutInitialized { return }
            self.deliver(
                .error(BushaPayError(message: "Checkout timed out before loading", code: "WEBVIEW_TIMEOUT"))
            )
        }
    }

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        let userContent = configuration.userContentController
        userContent.add(self, name: "BushaPayBridge")
        let scripts: [String] = [
            Scripts.deepLinkEnabler,
            Scripts.bushaPayBridgeShim,
            Scripts.messageListener,
        ]
        for source in scripts {
            let script = WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            userContent.addUserScript(script)
        }
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let wv = WKWebView(frame: .zero, configuration: configuration)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: view.topAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        webView = wv
    }

    private func addLoadingOverlay() {
        let overlay = UIView()
        overlay.backgroundColor = .systemBackground
        overlay.translatesAutoresizingMaskIntoConstraints = false
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(spinner)
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
        loadingView = overlay
    }

    private func loadHtml() {
        guard
            let url = resourceBundle.url(forResource: "busha_pay_checkout", withExtension: "html"),
            let html = try? String(contentsOf: url, encoding: .utf8)
        else {
            deliver(.error(BushaPayError(message: "Failed to load the bundled checkout page", code: "HTML_LOAD_ERROR")))
            return
        }
        webView?.loadHTMLString(html, baseURL: URL(string: checkoutUrl))
    }

    enum NavigationDecision: Equatable {
        case allow
        case openExternal(URL)
    }

    func decideNavigation(for url: URL?) -> NavigationDecision {
        guard let url, let scheme = url.scheme else { return .allow }
        if isWebScheme(scheme) { return .allow }
        return .openExternal(url)
    }

    func processBridgePayload(_ raw: String) {
        guard !didDeliverResult else { return }
        switch parseBridgeMessage(raw) {
        case .ready:
            bootstrapTimer?.invalidate()
            bootstrapTimer = nil
            if !checkoutInitialized {
                checkoutInitialized = true
                hideLoadingOverlay()
            }
        case .result(let result):
            deliver(result)
        case .unknown:
            break
        }
    }

    func handleNavigationError(_ error: Error) {
        guard isMainFrameError(error) else { return }
        deliver(
            .error(BushaPayError(
                message: "Could not load checkout (\(error.localizedDescription))",
                code: "WEBVIEW_LOAD_ERROR"
            ))
        )
    }

    func handleHttpStatusForMainFrame(_ statusCode: Int) -> WKNavigationResponsePolicy {
        if (200..<300).contains(statusCode) || statusCode == 0 {
            return .allow
        }
        deliver(
            .error(BushaPayError(message: "Checkout failed (HTTP \(statusCode))", code: "WEBVIEW_HTTP_ERROR"))
        )
        return .cancel
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "BushaPayBridge" else { return }
        processBridgePayload("\(message.body)")
    }

    private func hideLoadingOverlay() {
        loadingView?.removeFromSuperview()
        loadingView = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !formSubmitted {
            formSubmitted = true
            submitCheckoutForm()
            return
        }
        if !checkoutInitialized {
            checkoutInitialized = true
            hideLoadingOverlay()
        }
        if let prefix = autoSelect.rowTextPrefix {
            webView.evaluateJavaScript(Scripts.autoSelect(rowTextPrefix: prefix), completionHandler: nil)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        switch decideNavigation(for: navigationAction.request.url) {
        case .allow:
            return .allow
        case .openExternal(let url):
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                BushaPay.urlLauncher(url) { _ in cont.resume() }
            }
            return .cancel
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        guard
            navigationResponse.isForMainFrame,
            let response = navigationResponse.response as? HTTPURLResponse
        else {
            return .allow
        }
        return handleHttpStatusForMainFrame(response.statusCode)
    }

    private func isMainFrameError(_ error: Error) -> Bool {
        // Sub-resource failures (analytics, fonts, third-party iframes)
        // never reach this delegate, so anything we see is main-frame —
        // except cancellations, which we treat as benign.
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return false }
        return true
    }

    private func submitCheckoutForm() {
        let fields = config.toFormFields(
            publicKey: publicKey,
            callbackUrl: callbackUrl,
            checkoutUrl: checkoutUrl
        )
        let formAction: String
        if let queryMethod = autoSelect.queryParam {
            formAction = "\(checkoutUrl)?paymentMethod=\(queryMethod)"
        } else {
            formAction = checkoutUrl
        }
        var payload: [String: String] = ["_checkoutUrl": formAction]
        for (k, v) in fields { payload[k] = v }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript(Scripts.initCheckout(payloadJson: json), completionHandler: nil)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            BushaPay.urlLauncher(url) { _ in }
        }
        return nil
    }

    private func deliver(_ result: BushaPayResult) {
        guard !didDeliverResult else { return }
        didDeliverResult = true
        bootstrapTimer?.invalidate()
        bootstrapTimer = nil

        let cb = completion
        if presentingViewController != nil {
            dismiss(animated: true) { cb(result) }
        } else {
            cb(result)
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        handleInteractiveDismiss()
    }

    /// The OS has already dismissed the view by the time this fires;
    /// don't call `dismiss(animated:)`.
    func handleInteractiveDismiss() {
        guard !didDeliverResult else { return }
        didDeliverResult = true
        bootstrapTimer?.invalidate()
        bootstrapTimer = nil
        completion(.cancelled)
    }
}
