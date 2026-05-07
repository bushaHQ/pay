import Foundation

enum DeepLink {
    /// Returns the Busha app's URL scheme for `env` on iOS.
    static func bushaAppScheme(_ env: BushaEnvironment) -> String {
        switch env {
        case .sandbox:
            return "co.busha.boro.development"
        case .live:
            return "co.busha.apple"
        }
    }

    /// Builds the Busha app deep link.
    ///
    /// `reference` is included only when set, mirroring the Flutter and RN
    /// SDKs' shape.
    static func buildBushaAppDeepLink(
        scheme: String,
        config: BushaPayConfig,
        publicKey: String,
        callbackUrl: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "busha.co"
        components.path = "/pay"
        var items: [URLQueryItem] = [
            URLQueryItem(name: "public_key", value: publicKey),
            URLQueryItem(name: "quote_amount", value: config.quoteAmount),
            URLQueryItem(name: "quote_currency", value: config.quoteCurrency),
            URLQueryItem(name: "target_currency", value: config.targetCurrency),
        ]
        if let reference = config.reference {
            items.append(URLQueryItem(name: "reference", value: reference))
        }
        items.append(URLQueryItem(name: "callback_url", value: callbackUrl))
        components.queryItems = items
        return components.url
    }
}

/// URI schemes that should stay inside the WebView.
let kWebSchemes: Set<String> = ["http", "https", "about", "data", "blob"]

func isWebScheme(_ scheme: String) -> Bool {
    kWebSchemes.contains(scheme.lowercased())
}
