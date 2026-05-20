package co.busha.pay.internal

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Resolves the merchant's display name for a given public key.
 *
 * Hits `GET <platformUrl>/v1/merchants` with `X-BU-PUBLIC-KEY` and reads
 * `data.username`. Returns null on any failure (network error, non-2xx,
 * missing field) so callers can omit the merchant line silently.
 *
 * Blocking — call off the main thread.
 */
internal fun fetchMerchantName(publicKey: String, platformUrl: String): String? {
    return try {
        val conn = URL("$platformUrl/v1/merchants").openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "GET"
            conn.setRequestProperty("X-BU-PUBLIC-KEY", publicKey)
            conn.connectTimeout = TIMEOUT_MS
            conn.readTimeout = TIMEOUT_MS
            if (conn.responseCode !in 200..299) return null
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            JSONObject(body).optJSONObject("data")
                ?.optStringOrNull("username")
                ?.takeIf { it.isNotEmpty() }
        } finally {
            conn.disconnect()
        }
    } catch (_: Exception) {
        null
    }
}

private const val TIMEOUT_MS = 5000
