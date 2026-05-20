package co.busha.pay.internal

import co.busha.pay.BushaPayResult
import org.json.JSONArray
import org.json.JSONObject

/** Success result from a callback deep link (Busha-app path — limited data). */
internal fun successFromCallback(paymentId: String): BushaPayResult.Success =
    BushaPayResult.Success(paymentId = paymentId, status = "completed")

/** Success result from the web checkout's COMPLETED bridge message (full data). */
internal fun successFromCommerceJs(payload: JSONObject): BushaPayResult.Success {
    val data = payload.optJSONObject("data") ?: payload
    val id = data.optStringOrNull("id") ?: data.optStringOrNull("reference") ?: ""
    return BushaPayResult.Success(
        paymentId = id,
        status = data.optStringOrNull("status") ?: "completed",
        sourceAmount = data.optStringOrNull("source_amount"),
        sourceCurrency = data.optStringOrNull("source_currency"),
        targetAmount = data.optStringOrNull("target_amount"),
        targetCurrency = data.optStringOrNull("target_currency"),
        requestedAmount = data.optStringOrNull("requested_amount"),
        currency = data.optStringOrNull("currency"),
        rate = data.optJSONObject("rate")?.toMap(),
        merchantInfo = data.optJSONObject("merchant_info")?.toMap(),
        timeline = data.optJSONObject("timeline")?.toMap(),
        rawData = payload.toMap(),
    )
}

/** `optString` that returns null for missing / JSON-null values. */
internal fun JSONObject.optStringOrNull(key: String): String? =
    if (has(key) && !isNull(key)) optString(key) else null

/** Recursively converts a [JSONObject] into a plain [Map]. */
internal fun JSONObject.toMap(): Map<String, Any?> {
    val out = LinkedHashMap<String, Any?>()
    for (key in keys()) {
        out[key] = unwrap(get(key))
    }
    return out
}

private fun JSONArray.toList(): List<Any?> =
    (0 until length()).map { unwrap(get(it)) }

private fun unwrap(value: Any?): Any? = when (value) {
    is JSONObject -> value.toMap()
    is JSONArray -> value.toList()
    JSONObject.NULL -> null
    else -> value
}
