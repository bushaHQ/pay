package co.busha.pay.internal

import co.busha.pay.BushaPayCancelledReason
import co.busha.pay.BushaPayResult
import org.json.JSONObject

/** A parsed message from the web checkout's JS bridge. */
internal sealed interface BridgeMessage {
    /** The checkout iframe finished bootstrapping. */
    data object Ready : BridgeMessage

    /** The checkout produced a terminal result. */
    data class Result(val result: BushaPayResult) : BridgeMessage

    /** Unrelated or unparseable traffic — ignore. */
    data object Unknown : BridgeMessage
}

/**
 * Parses a raw bridge payload (a JSON string posted from the WebView)
 * into a [BridgeMessage]. Tolerant: any parse failure yields
 * [BridgeMessage.Unknown].
 */
internal fun parseBridgeMessage(raw: String): BridgeMessage {
    val json = try {
        JSONObject(raw)
    } catch (_: Exception) {
        return BridgeMessage.Unknown
    }
    return when (json.optString("type")) {
        "ready" -> BridgeMessage.Ready
        "success" -> {
            val data = json.optJSONObject("data") ?: JSONObject()
            BridgeMessage.Result(successFromCommerceJs(data))
        }
        "close" -> BridgeMessage.Result(
            BushaPayResult.Cancelled(reason = BushaPayCancelledReason.DISMISSED),
        )
        "error" -> {
            val data = json.optJSONObject("data") ?: JSONObject()
            val message = data.optStringOrNull("message") ?: "An error occurred"
            val code = data.optStringOrNull("code")
            BridgeMessage.Result(BushaPayResult.Error(message = message, code = code))
        }
        else -> BridgeMessage.Unknown
    }
}
