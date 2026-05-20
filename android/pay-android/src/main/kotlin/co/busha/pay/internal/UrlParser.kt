package co.busha.pay.internal

import java.net.URLDecoder

/**
 * Minimal hand-rolled URL helpers. We parse by hand rather than lean on
 * `android.net.Uri` so this layer stays pure-JVM and unit-testable
 * without Robolectric.
 */

private val ORIGIN_REGEX =
    Regex("^([a-z][a-z0-9+.\\-]*://[^/?#]+)", RegexOption.IGNORE_CASE)

private val URL_REGEX =
    Regex("^([a-z][a-z0-9+.\\-]*)://([^/?#]*)([^?#]*)(\\?[^#]*)?", RegexOption.IGNORE_CASE)

/** `scheme://host[:port]` of an absolute URL, or null if unparseable. */
internal fun getOrigin(absoluteUrl: String): String? =
    ORIGIN_REGEX.find(absoluteUrl)?.groupValues?.get(1)

internal data class ParsedUrl(
    val scheme: String,
    val host: String,
    val path: String,
    val query: Map<String, String>,
)

/** Parses an absolute URL into scheme / host / path / decoded query. */
internal fun parseUrl(url: String): ParsedUrl? {
    val m = URL_REGEX.find(url) ?: return null
    val rawQuery = m.groupValues[4].removePrefix("?")
    val query = LinkedHashMap<String, String>()
    if (rawQuery.isNotEmpty()) {
        for (pair in rawQuery.split("&")) {
            if (pair.isEmpty()) continue
            val eq = pair.indexOf('=')
            val key = if (eq == -1) pair else pair.substring(0, eq)
            val value = if (eq == -1) "" else pair.substring(eq + 1)
            query[decode(key)] = decode(value)
        }
    }
    return ParsedUrl(
        scheme = m.groupValues[1].lowercase(),
        host = m.groupValues[2],
        path = m.groupValues[3],
        query = query,
    )
}

private fun decode(s: String): String =
    try {
        URLDecoder.decode(s, "UTF-8")
    } catch (_: Exception) {
        s
    }
