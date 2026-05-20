package co.busha.pay.internal

import co.busha.pay.BushaPayCancelledReason
import co.busha.pay.BushaPayResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BridgeTest {

    @Test
    fun parseBridgeMessage_readyType() {
        assertEquals(BridgeMessage.Ready, parseBridgeMessage("""{"type":"ready"}"""))
    }

    @Test
    fun parseBridgeMessage_successCarriesCommerceJsPayload() {
        val msg = parseBridgeMessage(
            """{"type":"success","data":{"data":{"id":"PAYR_42","status":"completed"}}}""",
        )
        assertTrue(msg is BridgeMessage.Result)
        val result = (msg as BridgeMessage.Result).result
        assertTrue(result is BushaPayResult.Success)
        assertEquals("PAYR_42", (result as BushaPayResult.Success).paymentId)
    }

    @Test
    fun parseBridgeMessage_closeYieldsDismissedCancellation() {
        val msg = parseBridgeMessage("""{"type":"close"}""") as BridgeMessage.Result
        val cancelled = msg.result as BushaPayResult.Cancelled
        assertEquals(BushaPayCancelledReason.DISMISSED, cancelled.reason)
    }

    @Test
    fun parseBridgeMessage_errorCarriesMessageAndCode() {
        val msg = parseBridgeMessage(
            """{"type":"error","data":{"message":"No signal","code":"NET_DOWN"}}""",
        ) as BridgeMessage.Result
        val error = msg.result as BushaPayResult.Error
        assertEquals("No signal", error.message)
        assertEquals("NET_DOWN", error.code)
    }

    @Test
    fun parseBridgeMessage_errorDefaultsMessageWhenMissing() {
        val msg = parseBridgeMessage("""{"type":"error"}""") as BridgeMessage.Result
        val error = msg.result as BushaPayResult.Error
        assertEquals("An error occurred", error.message)
        assertEquals(null, error.code)
    }

    @Test
    fun parseBridgeMessage_unknownType() {
        assertEquals(
            BridgeMessage.Unknown,
            parseBridgeMessage("""{"type":"mystery"}"""),
        )
    }

    @Test
    fun parseBridgeMessage_nonJsonIsUnknown() {
        assertEquals(BridgeMessage.Unknown, parseBridgeMessage("not json {"))
    }
}
