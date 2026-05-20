package co.busha.pay.internal

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ResultsTest {

    @Test
    fun successFromCallback_buildsLimitedData() {
        val s = successFromCallback("PAYR_1")
        assertEquals("PAYR_1", s.paymentId)
        assertEquals("completed", s.status)
        assertFalse(s.hasFullData)
        assertNull(s.rawData)
        assertNull(s.sourceAmount)
    }

    @Test
    fun successFromCommerceJs_readsDataEnvelope() {
        val payload = JSONObject(
            """
            {"data":{"id":"PAYR_2","status":"completed","source_amount":"0.0001",
            "source_currency":"BTC","target_amount":"13.42","target_currency":"USDT",
            "requested_amount":"10","currency":"NGN","rate":{"value":1},
            "merchant_info":{"name":"Acme"},"timeline":{"steps":[]}}}
            """.trimIndent(),
        )
        val s = successFromCommerceJs(payload)
        assertEquals("PAYR_2", s.paymentId)
        assertEquals("completed", s.status)
        assertEquals("0.0001", s.sourceAmount)
        assertEquals("BTC", s.sourceCurrency)
        assertEquals("13.42", s.targetAmount)
        assertEquals("USDT", s.targetCurrency)
        assertEquals("10", s.requestedAmount)
        assertEquals("NGN", s.currency)
        assertEquals(mapOf("name" to "Acme"), s.merchantInfo)
        assertTrue(s.hasFullData)
        assertNotNull(s.rawData)
    }

    @Test
    fun successFromCommerceJs_fallsBackToFlatPayload() {
        val s = successFromCommerceJs(JSONObject("""{"id":"PAYR_3","status":"completed"}"""))
        assertEquals("PAYR_3", s.paymentId)
        assertEquals("completed", s.status)
    }

    @Test
    fun successFromCommerceJs_fallsBackToReferenceWhenIdMissing() {
        val s = successFromCommerceJs(
            JSONObject("""{"data":{"reference":"ref-x","status":"completed"}}"""),
        )
        assertEquals("ref-x", s.paymentId)
    }

    @Test
    fun successFromCommerceJs_defaultsWhenBothMissing() {
        val s = successFromCommerceJs(JSONObject("""{"data":{}}"""))
        assertEquals("", s.paymentId)
        assertEquals("completed", s.status)
    }
}
