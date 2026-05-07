import Foundation

/// A parsed message from the WebView bridge.
enum BridgeMessage {
    /// Finished bootstrapping the iframe — hide the shimmer.
    case ready
    /// Reported a terminal outcome (success, cancellation, error).
    case result(BushaPayResult)
    /// Unparseable JSON, missing `type`, or an unknown `type` value.
    case unknown
}

func parseBridgeMessage(_ raw: String) -> BridgeMessage {
    guard
        let data = raw.data(using: .utf8),
        let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        return .unknown
    }
    let type = decoded["type"] as? String
    let payload = decoded["data"]
    switch type {
    case "ready":
        return .ready
    case "success":
        guard let dict = payload as? [String: Any] else { return .unknown }
        return .result(.success(BushaPaySuccess.fromCommerceJs(dict)))
    case "close":
        return .result(.cancelled)
    case "error":
        let dict = (payload as? [String: Any]) ?? [:]
        let message = (dict["message"] as? String) ?? "An error occurred"
        let code = dict["code"] as? String
        return .result(.error(BushaPayError(message: message, code: code)))
    default:
        return .unknown
    }
}
