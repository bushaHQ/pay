package co.busha.pay.internal

import org.junit.Assert.assertTrue
import org.junit.Test

class ScriptsTest {

    @Test
    fun documentStartScripts_defineTheBridgeShim() {
        assertTrue(DOCUMENT_START_SCRIPTS.contains("window.BushaPayBridge"))
        assertTrue(DOCUMENT_START_SCRIPTS.contains("window.BushaPayAndroid"))
        assertTrue(DOCUMENT_START_SCRIPTS.contains(".postMessage"))
    }

    @Test
    fun documentStartScripts_routeCheckoutStatuses() {
        assertTrue(DOCUMENT_START_SCRIPTS.contains("status === 'INITIALIZED'"))
        assertTrue(DOCUMENT_START_SCRIPTS.contains("status === 'CANCELLED'"))
        assertTrue(DOCUMENT_START_SCRIPTS.contains("status === 'COMPLETED'"))
        assertTrue(DOCUMENT_START_SCRIPTS.contains("type: 'ready'"))
        assertTrue(DOCUMENT_START_SCRIPTS.contains("type: 'close'"))
        assertTrue(DOCUMENT_START_SCRIPTS.contains("type: 'success'"))
    }

    @Test
    fun documentStartScripts_removeGetInstalledRelatedApps() {
        assertTrue(DOCUMENT_START_SCRIPTS.contains("delete navigator.getInstalledRelatedApps"))
    }

    @Test
    fun documentStartScripts_defineInitCheckout() {
        assertTrue(DOCUMENT_START_SCRIPTS.contains("window.initCheckout"))
        assertTrue(DOCUMENT_START_SCRIPTS.contains("__bushaPayInitCheckoutDefined"))
    }

    @Test
    fun initCheckoutScript_wrapsPayloadAndReturnsTrue() {
        val js = initCheckoutScript("""{"a":1}""")
        assertTrue(js.contains("""initCheckout({"a":1})"""))
        assertTrue(js.trim().endsWith("true;"))
    }

    @Test
    fun autoSelectScript_jsonEncodesPrefix() {
        assertTrue(autoSelectScript("Busha").contains("var target = \"Busha\""))
    }

    @Test
    fun autoSelectScript_escapesEmbeddedQuotes() {
        assertTrue(autoSelectScript("She said \"hi\"").contains("\\\"hi\\\""))
    }

    @Test
    fun autoSelectScript_embedsGuardObserverAndTimeout() {
        val js = autoSelectScript("X")
        assertTrue(js.contains("__bushaPayAutoSelectDone"))
        assertTrue(js.contains("MutationObserver"))
        assertTrue(js.contains("10000"))
        assertTrue(js.trim().endsWith("true;"))
    }
}
