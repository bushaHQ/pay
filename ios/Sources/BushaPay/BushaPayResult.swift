import Foundation

/// Result of a Busha Pay checkout.
///
/// Use a `switch` to handle each case:
/// ```swift
/// switch result {
/// case .success(let payment):
///     print("Paid: \(payment.paymentId)")
/// case .cancelled:
///     print("User cancelled")
/// case .error(let err):
///     print("Error: \(err.message)")
/// }
/// ```
public enum BushaPayResult: Sendable {
    case success(BushaPaySuccess)
    case cancelled
    case error(BushaPayError)
}

/// Payment completed successfully.
///
/// Full payment data (amounts, rates, timeline) is available when payment
/// was completed in the web checkout flow. When completed via the Busha
/// app, only ``paymentId`` and ``status`` are available.
///
/// **Important:** Always verify the payment server-side via webhooks. The
/// client result is a UX hint, not the source of truth.
public struct BushaPaySuccess: Sendable {
    /// Payment request ID (e.g., `"PAYR_EhDmpnPwDSjO"`). Always present.
    public let paymentId: String

    /// Payment status (e.g., `"completed"`). Always present.
    public let status: String

    /// Amount paid in the source currency (web flow only).
    public let sourceAmount: String?

    /// Source currency the user paid with (web flow only).
    public let sourceCurrency: String?

    /// Amount received in the target currency (web flow only).
    public let targetAmount: String?

    /// Target settlement currency (web flow only).
    public let targetCurrency: String?

    /// Originally requested amount (web flow only).
    public let requestedAmount: String?

    /// Currency of the requested amount (web flow only).
    public let currency: String?

    /// Whether full payment data is available.
    ///
    /// `true` when payment completed in the web checkout.
    /// `false` when payment completed via the Busha app.
    public var hasFullData: Bool { sourceAmount != nil || targetAmount != nil }

    public init(
        paymentId: String,
        status: String,
        sourceAmount: String? = nil,
        sourceCurrency: String? = nil,
        targetAmount: String? = nil,
        targetCurrency: String? = nil,
        requestedAmount: String? = nil,
        currency: String? = nil
    ) {
        self.paymentId = paymentId
        self.status = status
        self.sourceAmount = sourceAmount
        self.sourceCurrency = sourceCurrency
        self.targetAmount = targetAmount
        self.targetCurrency = targetCurrency
        self.requestedAmount = requestedAmount
        self.currency = currency
    }

    static func fromCallback(paymentId: String) -> BushaPaySuccess {
        BushaPaySuccess(paymentId: paymentId, status: "completed")
    }

    static func fromCommerceJs(_ payload: [String: Any]) -> BushaPaySuccess {
        let data = (payload["data"] as? [String: Any]) ?? payload
        return BushaPaySuccess(
            paymentId: (data["id"] as? String) ?? (data["reference"] as? String) ?? "",
            status: (data["status"] as? String) ?? "completed",
            sourceAmount: data["source_amount"] as? String,
            sourceCurrency: data["source_currency"] as? String,
            targetAmount: data["target_amount"] as? String,
            targetCurrency: data["target_currency"] as? String,
            requestedAmount: data["requested_amount"] as? String,
            currency: data["currency"] as? String
        )
    }
}

/// An error from the Busha Pay flow.
///
/// `message` is **diagnostic** — useful for logs and support tickets but
/// not safe to surface to end users verbatim. Branch on ``code`` for UX
/// decisions and craft your own user-facing copy.
public struct BushaPayError: Sendable, Error {
    /// Human-readable diagnostic message.
    public let message: String

    /// Machine-readable error code, when available.
    ///
    /// Common values:
    /// - `"CHECKOUT_IN_PROGRESS"` — a previous `checkout` hasn't resolved.
    /// - `"WEBVIEW_LOAD_ERROR"` — network / DNS / platform load failure.
    /// - `"WEBVIEW_HTTP_ERROR"` — non-2xx HTTP response.
    /// - `"WEBVIEW_TIMEOUT"` — checkout didn't bootstrap within 30s.
    /// - `"HTML_LOAD_ERROR"` — bundled checkout HTML failed to load.
    public let code: String?

    public init(message: String, code: String? = nil) {
        self.message = message
        self.code = code
    }
}
