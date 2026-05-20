package co.busha.pay

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BushaPayResultTest {

    @Test
    fun cancelled_defaultsToDismissedWithNoPaymentId() {
        val c = BushaPayResult.Cancelled()
        assertEquals(BushaPayCancelledReason.DISMISSED, c.reason)
        assertNull(c.paymentId)
    }

    @Test
    fun cancelled_carriesRejectedReasonAndPaymentId() {
        val c = BushaPayResult.Cancelled(
            reason = BushaPayCancelledReason.REJECTED,
            paymentId = "PAYR_42",
        )
        assertEquals(BushaPayCancelledReason.REJECTED, c.reason)
        assertEquals("PAYR_42", c.paymentId)
    }

    @Test
    fun cancelled_carriesAbandonedReason() {
        val c = BushaPayResult.Cancelled(reason = BushaPayCancelledReason.ABANDONED)
        assertEquals(BushaPayCancelledReason.ABANDONED, c.reason)
        assertNull(c.paymentId)
    }

    @Test
    fun success_hasFullDataReflectsRawData() {
        assertFalse(BushaPayResult.Success(paymentId = "p", status = "completed").hasFullData)
        assertTrue(
            BushaPayResult.Success(
                paymentId = "p",
                status = "completed",
                rawData = mapOf("id" to "p"),
            ).hasFullData,
        )
    }

    @Test
    fun result_isExhaustivelyMatchable() {
        val cases: List<BushaPayResult> = listOf(
            BushaPayResult.Success(paymentId = "p", status = "completed"),
            BushaPayResult.Cancelled(),
            BushaPayResult.Error("oops", "E1"),
        )
        val tags = cases.map { result ->
            when (result) {
                is BushaPayResult.Success -> "success"
                is BushaPayResult.Cancelled -> "cancelled"
                is BushaPayResult.Error -> "error"
            }
        }
        assertEquals(listOf("success", "cancelled", "error"), tags)
    }
}
