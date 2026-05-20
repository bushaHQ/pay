package co.busha.pay.internal

import co.busha.pay.BushaEnvironment
import co.busha.pay.BushaPayCancelledReason
import co.busha.pay.BushaPayConfig
import co.busha.pay.BushaPayResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DeepLinkTest {

    private val config = BushaPayConfig(
        quoteAmount = "10000",
        quoteCurrency = "NGN",
        targetCurrency = "NGN",
        sourceCurrency = "USDT",
    )

    @Test
    fun isWebScheme_acceptsWebSchemesCaseInsensitively() {
        assertTrue(isWebScheme("http"))
        assertTrue(isWebScheme("https"))
        assertTrue(isWebScheme("HTTPS"))
        assertTrue(isWebScheme("about"))
        assertTrue(isWebScheme("data"))
        assertTrue(isWebScheme("blob"))
    }

    @Test
    fun isWebScheme_rejectsNonWebSchemes() {
        assertFalse(isWebScheme("mailto"))
        assertFalse(isWebScheme("co.busha.android"))
        assertFalse(isWebScheme("tel"))
    }

    @Test
    fun bushaAppScheme_mapsEnvironments() {
        assertEquals("co.busha.android", bushaAppScheme(BushaEnvironment.LIVE))
        assertEquals(
            "co.busha.android.development",
            bushaAppScheme(BushaEnvironment.SANDBOX),
        )
    }

    @Test
    fun buildBushaAppDeepLink_buildsHostAndPath() {
        val url = buildBushaAppDeepLink(
            scheme = "co.busha.android",
            config = config,
            publicKey = "pub_x",
            callbackUrl = "co.example.app.busha-pay://callback",
        )
        assertTrue(url.startsWith("co.busha.android://busha.co/pay?"))
    }

    @Test
    fun buildBushaAppDeepLink_embedsRequiredParams() {
        val url = buildBushaAppDeepLink(
            scheme = "co.busha.android",
            config = config,
            publicKey = "pub_test",
            callbackUrl = "co.example.app.busha-pay://callback",
        )
        assertTrue(url.contains("public_key=pub_test"))
        assertTrue(url.contains("quote_amount=10000"))
        assertTrue(url.contains("quote_currency=NGN"))
        assertTrue(url.contains("target_currency=NGN"))
        assertTrue(url.contains("callback_url=co.example.app.busha-pay%3A%2F%2Fcallback"))
    }

    @Test
    fun buildBushaAppDeepLink_omitsReferenceWhenAbsent() {
        val url = buildBushaAppDeepLink("co.busha.android", config, "pk", "cb://cb")
        assertFalse(url.contains("reference="))
    }

    @Test
    fun buildBushaAppDeepLink_includesReferenceWhenSet() {
        val url = buildBushaAppDeepLink(
            "co.busha.android",
            config.copy(reference = "ref-1"),
            "pk",
            "cb://cb",
        )
        assertTrue(url.contains("reference=ref-1"))
    }

    @Test
    fun parseCallback_completedYieldsSuccess() {
        val r = parseCallback(
            "co.x.busha-pay://callback?status=completed&paymentRequestId=PAYR_1",
        )
        assertTrue(r is BushaPayResult.Success)
        assertEquals("PAYR_1", (r as BushaPayResult.Success).paymentId)
    }

    @Test
    fun parseCallback_cancelledYieldsRejectedCancellationWithPaymentId() {
        val r = parseCallback(
            "co.x.busha-pay://callback?status=cancelled&paymentRequestId=PAYR_REJ",
        )
        assertTrue(r is BushaPayResult.Cancelled)
        r as BushaPayResult.Cancelled
        assertEquals(BushaPayCancelledReason.REJECTED, r.reason)
        assertEquals("PAYR_REJ", r.paymentId)
    }

    @Test
    fun parseCallback_failedYieldsErrorWithExplicitCodeAndMessage() {
        val r = parseCallback(
            "co.x.busha-pay://callback?status=failed" +
                "&error_code=card_declined&error_message=Card%20declined",
        )
        assertTrue(r is BushaPayResult.Error)
        r as BushaPayResult.Error
        assertEquals("card_declined", r.code)
        assertEquals("Card declined", r.message)
    }

    @Test
    fun parseCallback_fallsBackToStatusAsErrorCode() {
        val r = parseCallback("co.x.busha-pay://callback?status=failed") as BushaPayResult.Error
        assertEquals("failed", r.code)
        assertEquals("Payment failed", r.message)
    }

    @Test
    fun parseCallback_usesUnknownWhenStatusMissing() {
        val r = parseCallback("co.x.busha-pay://callback") as BushaPayResult.Error
        assertEquals("unknown", r.code)
    }
}
