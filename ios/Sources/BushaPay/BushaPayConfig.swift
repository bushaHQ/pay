import Foundation

/// Configuration for a Busha Pay checkout session.
public struct BushaPayConfig: Sendable {
    /// Amount to charge (e.g., `"10000"`).
    public let quoteAmount: String

    /// Currency for the quoted amount (e.g., `"NGN"`, `"USD"`).
    public let quoteCurrency: String

    /// Currency the payment settles into (e.g., `"NGN"`, `"USD"`).
    public let targetCurrency: String

    /// Asset the customer pays with (e.g., `"USDT"`, `"BTC"`).
    public let sourceCurrency: String

    /// Custom transaction reference. Auto-generated if not provided.
    public let reference: String?

    /// Customer or order name shown in the checkout.
    public let metaName: String?

    /// Customer email for order context.
    public let metaEmail: String?

    /// Customer phone number.
    public let metaPhone: String?

    /// Restricts which payment methods the chooser offers.
    ///
    /// - `nil` or empty → show the full chooser (default).
    /// - One method → skip the chooser and route straight to that method.
    /// - Multiple methods → show the chooser with only those tiles.
    public let allowedPaymentMethods: [PaymentMethod]?

    public init(
        quoteAmount: String,
        quoteCurrency: String,
        targetCurrency: String,
        sourceCurrency: String,
        reference: String? = nil,
        metaName: String? = nil,
        metaEmail: String? = nil,
        metaPhone: String? = nil,
        allowedPaymentMethods: [PaymentMethod]? = nil
    ) {
        self.quoteAmount = quoteAmount
        self.quoteCurrency = quoteCurrency
        self.targetCurrency = targetCurrency
        self.sourceCurrency = sourceCurrency
        self.reference = reference
        self.metaName = metaName
        self.metaEmail = metaEmail
        self.metaPhone = metaPhone
        self.allowedPaymentMethods = allowedPaymentMethods
    }

    /// Form fields for the WebView checkout's hidden POST.
    func toFormFields(
        publicKey: String,
        callbackUrl: String,
        checkoutUrl: String
    ) -> [String: String] {
        var fields: [String: String] = [
            "public_key": publicKey,
            "quote_amount": quoteAmount,
            "quote_currency": quoteCurrency,
            "target_currency": targetCurrency,
            "source_currency": sourceCurrency,
            "callback_url": callbackUrl,
            "displayMode": "INLINE",
        ]
        if let origin = URL(string: checkoutUrl)?.origin {
            fields["parentOrigin"] = origin
        }
        if let reference { fields["reference"] = reference }
        if let metaName { fields["meta[name]"] = metaName }
        if let metaEmail { fields["meta[email]"] = metaEmail }
        if let metaPhone { fields["meta[phone_number]"] = metaPhone }
        return fields
    }
}

private extension URL {
    /// `scheme://host[:port]` — matches `URL.origin` semantics from the
    /// other SDKs (Flutter `Uri.origin`, JS `URL.origin`).
    var origin: String? {
        guard let scheme, let host else { return nil }
        if let port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }
}
