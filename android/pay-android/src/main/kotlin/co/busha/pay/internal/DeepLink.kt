package co.busha.pay.internal

import co.busha.pay.BushaEnvironment
import co.busha.pay.BushaPayCancelledReason
import co.busha.pay.BushaPayConfig
import co.busha.pay.BushaPayResult
import java.net.URLEncoder

/** URI schemes that should stay inside the WebView. */
internal val WEB_SCHEMES = setOf("http", "https", "about", "data", "blob")

internal fun isWebScheme(scheme: String): Boolean =
    WEB_SCHEMES.contains(scheme.lowercase())

/** The Busha app's URL scheme for [env] on Android. */
internal fun bushaAppScheme(env: BushaEnvironment): String = when (env) {
    BushaEnvironment.SANDBOX -> "co.busha.android.development"
    BushaEnvironment.LIVE -> "co.busha.android"
}

/**
 * Builds the Busha app deep link. `reference` is included only when set,
 * mirroring the Flutter, iOS, and React Native SDKs.
 */
internal fun buildBushaAppDeepLink(
    scheme: String,
    config: BushaPayConfig,
    publicKey: String,
    callbackUrl: String,
): String {
    val params = LinkedHashMap<String, String>()
    params["public_key"] = publicKey
    params["quote_amount"] = config.quoteAmount
    params["quote_currency"] = config.quoteCurrency
    params["target_currency"] = config.targetCurrency
    config.reference?.let { params["reference"] = it }
    params["callback_url"] = callbackUrl
    val query = params.entries.joinToString("&") { "${encode(it.key)}=${encode(it.value)}" }
    return "$scheme://busha.co/pay?$query"
}

/**
 * Parses a callback deep link into a result.
 *
 * `status=cancelled` maps to a [BushaPayCancelledReason.REJECTED]
 * cancellation — the Busha app reports an explicit rejection and hands
 * back the request id. A resume-without-callback is `ABANDONED` instead,
 * and is decided by the launcher, not here.
 */
internal fun parseCallback(url: String): BushaPayResult {
    val query = parseUrl(url)?.query ?: emptyMap()
    val status = query["status"]
    val paymentRequestId = query["paymentRequestId"] ?: ""
    return when (status) {
        "completed" -> successFromCallback(paymentRequestId)
        "cancelled" -> BushaPayResult.Cancelled(
            reason = BushaPayCancelledReason.REJECTED,
            paymentId = paymentRequestId,
        )
        else -> {
            val code = query["error_code"] ?: status ?: "unknown"
            val message = query["error_message"] ?: "Payment failed"
            BushaPayResult.Error(message = message, code = code)
        }
    }
}

private fun encode(s: String): String =
    URLEncoder.encode(s, "UTF-8").replace("+", "%20")
