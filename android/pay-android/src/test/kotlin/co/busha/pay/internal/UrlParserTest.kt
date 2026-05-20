package co.busha.pay.internal

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UrlParserTest {

    @Test
    fun getOrigin_extractsSchemeAndHost() {
        assertEquals("https://pay.busha.io", getOrigin("https://pay.busha.io/pay"))
    }

    @Test
    fun getOrigin_preservesPort() {
        assertEquals("http://localhost:3000", getOrigin("http://localhost:3000/foo"))
    }

    @Test
    fun getOrigin_returnsNullWhenNoScheme() {
        assertNull(getOrigin("not-a-url"))
    }

    @Test
    fun getOrigin_stopsAtQueryAndFragment() {
        assertEquals(
            "co.example.app.busha-pay://callback",
            getOrigin("co.example.app.busha-pay://callback?x=1"),
        )
    }

    @Test
    fun parseUrl_returnsNullForUnparseable() {
        assertNull(parseUrl("not a url"))
    }

    @Test
    fun parseUrl_parsesSchemeHostPath() {
        val p = parseUrl("https://pay.busha.io/pay/checkout")!!
        assertEquals("https", p.scheme)
        assertEquals("pay.busha.io", p.host)
        assertEquals("/pay/checkout", p.path)
        assertEquals(emptyMap<String, String>(), p.query)
    }

    @Test
    fun parseUrl_lowercasesScheme() {
        assertEquals("https", parseUrl("HTTPS://x.co/")!!.scheme)
    }

    @Test
    fun parseUrl_decodesQueryParameters() {
        val p = parseUrl(
            "co.example.app.busha-pay://callback?status=completed&paymentRequestId=PAYR_1",
        )!!
        assertEquals("completed", p.query["status"])
        assertEquals("PAYR_1", p.query["paymentRequestId"])
    }

    @Test
    fun parseUrl_decodesPercentEncodedValues() {
        val p = parseUrl("https://x.co/?msg=hello%20world")!!
        assertEquals("hello world", p.query["msg"])
    }

    @Test
    fun parseUrl_treatsKeysWithoutEqualsAsEmpty() {
        val p = parseUrl("https://x.co/?flag&k=v")!!
        assertEquals("", p.query["flag"])
        assertEquals("v", p.query["k"])
    }

    @Test
    fun parseUrl_skipsEmptyPairs() {
        val p = parseUrl("https://x.co/?a=1&&b=2")!!
        assertEquals(mapOf("a" to "1", "b" to "2"), p.query)
    }

    @Test
    fun parseUrl_stripsFragmentFromQuery() {
        val p = parseUrl("https://x.co/p?a=1#frag")!!
        assertEquals(mapOf("a" to "1"), p.query)
    }

    @Test
    fun parseUrl_parsesCustomSchemeCallback() {
        val p = parseUrl("co.example.testapp.busha-pay://callback?status=cancelled")!!
        assertEquals("co.example.testapp.busha-pay", p.scheme)
        assertEquals("callback", p.host)
        assertEquals("cancelled", p.query["status"])
    }
}
