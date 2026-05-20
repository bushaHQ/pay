package co.busha.pay

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class BushaPayConfigTest {

    private val config = BushaPayConfig(
        quoteAmount = "10000",
        quoteCurrency = "NGN",
        targetCurrency = "NGN",
        sourceCurrency = "USDT",
    )

    private fun fields(c: BushaPayConfig = config, checkoutUrl: String = "https://pay.busha.io/pay") =
        c.toFormFields(
            publicKey = "pk",
            callbackUrl = "co.example.app.busha-pay://callback",
            checkoutUrl = checkoutUrl,
        )

    @Test
    fun toFormFields_emitsRequiredFields() {
        val f = fields()
        assertEquals("pk", f["public_key"])
        assertEquals("10000", f["quote_amount"])
        assertEquals("NGN", f["quote_currency"])
        assertEquals("NGN", f["target_currency"])
        assertEquals("USDT", f["source_currency"])
        assertEquals("co.example.app.busha-pay://callback", f["callback_url"])
    }

    @Test
    fun toFormFields_usesInlineDisplayMode() {
        assertEquals("INLINE", fields()["displayMode"])
    }

    @Test
    fun toFormFields_derivesParentOriginFromCheckoutUrl() {
        assertEquals("https://pay.busha.io", fields()["parentOrigin"])
    }

    @Test
    fun toFormFields_parentOriginIncludesPort() {
        assertEquals(
            "http://localhost:8080",
            fields(checkoutUrl = "http://localhost:8080/pay")["parentOrigin"],
        )
    }

    @Test
    fun toFormFields_omitsParentOriginForBogusUrl() {
        assertNull(fields(checkoutUrl = "")["parentOrigin"])
    }

    @Test
    fun toFormFields_omitsNullOptionals() {
        val f = fields()
        assertFalse(f.containsKey("reference"))
        assertFalse(f.containsKey("meta[name]"))
        assertFalse(f.containsKey("meta[email]"))
        assertFalse(f.containsKey("meta[phone_number]"))
    }

    @Test
    fun toFormFields_omitsEmptyOptionals() {
        val f = fields(config.copy(reference = "", metaName = ""))
        assertFalse(f.containsKey("reference"))
        assertFalse(f.containsKey("meta[name]"))
    }

    @Test
    fun toFormFields_includesMetaWithBracketedKeys() {
        val f = fields(
            config.copy(
                reference = "ref-1",
                metaName = "Alice",
                metaEmail = "a@b.co",
                metaPhone = "+2348000",
            ),
        )
        assertEquals("ref-1", f["reference"])
        assertEquals("Alice", f["meta[name]"])
        assertEquals("a@b.co", f["meta[email]"])
        assertEquals("+2348000", f["meta[phone_number]"])
    }
}
