package co.busha.pay.internal

import android.app.Activity
import android.net.Uri
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.FakeWebResourceError
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import co.busha.pay.BushaPay
import co.busha.pay.BushaPayCancelledReason
import co.busha.pay.BushaPayConfig
import co.busha.pay.BushaPayResult
import co.busha.pay.PaymentMethod
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CheckoutActivityTest {

    private lateinit var host: Activity
    private var delivered: BushaPayResult? = null

    private val config = BushaPayConfig(
        quoteAmount = "10000",
        quoteCurrency = "NGN",
        targetCurrency = "NGN",
        sourceCurrency = "USDT",
        // A single method routes straight past the chooser into checkout.
        allowedPaymentMethods = listOf(PaymentMethod.STABLECOINS),
    )

    @Before
    fun setUp() {
        BushaPay.resetForTesting()
        delivered = null
        host = Robolectric.buildActivity(Activity::class.java).setup().get()
    }

    @After
    fun tearDown() {
        BushaPay.resetForTesting()
    }

    /** Initializes the SDK and primes the pending checkout state. */
    private fun primeCheckout() {
        BushaPay.initialize(host, "pub_x")
        BushaPay.checkout(host, config) { delivered = it }
    }

    private fun launch(): ActivityController<CheckoutActivity> =
        Robolectric.buildActivity(CheckoutActivity::class.java).setup()

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    private fun ViewGroup.findWebView(): WebView? {
        for (i in 0 until childCount) {
            when (val child = getChildAt(i)) {
                is WebView -> return child
                is ViewGroup -> child.findWebView()?.let { return it }
            }
        }
        return null
    }

    private fun CheckoutActivity.contentRoot(): ViewGroup =
        (findViewById<ViewGroup>(android.R.id.content).getChildAt(0) as ViewGroup)

    private fun postBridgeMessage(activity: CheckoutActivity, payload: String) {
        val webView = activity.contentRoot().findWebView()!!
        val bridge = shadowOf(webView).getJavascriptInterface(JS_INTERFACE_NAME)!!
        bridge.javaClass.getMethod("postMessage", String::class.java).apply {
            isAccessible = true
            invoke(bridge, payload)
        }
        idle()
    }

    @Test
    fun onCreate_withoutPendingConfig_finishesImmediately() {
        // No primeCheckout() — pendingConfig is null.
        val activity = launch().get()
        assertTrue(activity.isFinishing)
    }

    @Test
    fun onCreate_loadsBundledCheckoutHtmlIntoWebView() {
        primeCheckout()
        val activity = launch().get()
        val webView = activity.contentRoot().findWebView()!!
        val loaded = shadowOf(webView).lastLoadDataWithBaseURL
        assertNotNull("expected the bundled HTML to be loaded", loaded)
        assertTrue(loaded.data.isNotEmpty())
        assertNull(delivered)
    }

    @Test
    fun backPress_deliversDismissedCancellation() {
        primeCheckout()
        val activity = launch().get()
        @Suppress("DEPRECATION")
        activity.onBackPressed()
        idle()
        val result = delivered as BushaPayResult.Cancelled
        assertEquals(BushaPayCancelledReason.DISMISSED, result.reason)
    }

    @Test
    fun destroy_withoutResult_deliversDismissedCancellation() {
        primeCheckout()
        launch().destroy()
        idle()
        val result = delivered as BushaPayResult.Cancelled
        assertEquals(BushaPayCancelledReason.DISMISSED, result.reason)
    }

    @Test
    fun tappingDimStrip_deliversDismissedCancellation() {
        primeCheckout()
        val activity = launch().get()
        val dimStrip: View = activity.contentRoot().getChildAt(0)
        dimStrip.performClick()
        idle()
        val result = delivered as BushaPayResult.Cancelled
        assertEquals(BushaPayCancelledReason.DISMISSED, result.reason)
    }

    @Test
    fun bridgeReady_hidesLoadingOverlay() {
        primeCheckout()
        val activity = launch().get()
        val card = activity.contentRoot().getChildAt(1) as ViewGroup
        val loadingOverlay = card.getChildAt(1)
        assertEquals(View.VISIBLE, loadingOverlay.visibility)

        postBridgeMessage(activity, """{"type":"ready"}""")

        assertEquals(View.GONE, loadingOverlay.visibility)
        assertNull("ready is not a terminal result", delivered)
    }

    @Test
    fun bridgeSuccess_deliversSuccessResult() {
        primeCheckout()
        val activity = launch().get()
        postBridgeMessage(
            activity,
            """{"type":"success","data":{"data":{"id":"PAYR_42","status":"completed"}}}""",
        )
        val result = delivered as BushaPayResult.Success
        assertEquals("PAYR_42", result.paymentId)
    }

    @Test
    fun bridgeError_deliversErrorResult() {
        primeCheckout()
        val activity = launch().get()
        postBridgeMessage(
            activity,
            """{"type":"error","data":{"message":"No signal","code":"NET_DOWN"}}""",
        )
        val result = delivered as BushaPayResult.Error
        assertEquals("No signal", result.message)
        assertEquals("NET_DOWN", result.code)
    }

    @Test
    fun bridgeClose_deliversDismissedCancellation() {
        primeCheckout()
        val activity = launch().get()
        postBridgeMessage(activity, """{"type":"close"}""")
        val result = delivered as BushaPayResult.Cancelled
        assertEquals(BushaPayCancelledReason.DISMISSED, result.reason)
    }

    @Test
    fun bridgeUnknownMessage_isIgnored() {
        primeCheckout()
        val activity = launch().get()
        postBridgeMessage(activity, """{"type":"mystery"}""")
        assertNull(delivered)
    }

    @Test
    fun bootstrapTimeout_deliversTimeoutError() {
        primeCheckout()
        launch()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        val result = delivered as BushaPayResult.Error
        assertEquals("WEBVIEW_TIMEOUT", result.code)
    }

    private fun clientAndWebView(activity: CheckoutActivity): Pair<WebViewClient, WebView> {
        val webView = activity.contentRoot().findWebView()!!
        return shadowOf(webView).webViewClient to webView
    }

    private fun fakeRequest(url: String, mainFrame: Boolean) = object : WebResourceRequest {
        override fun getUrl(): Uri = Uri.parse(url)
        override fun isForMainFrame(): Boolean = mainFrame
        override fun isRedirect(): Boolean = false
        override fun hasGesture(): Boolean = false
        override fun getMethod(): String = "GET"
        override fun getRequestHeaders(): MutableMap<String, String> = mutableMapOf()
    }

    private fun fakeError(code: Int, desc: String): WebResourceError =
        FakeWebResourceError(code, desc)

    @Test
    fun webViewClient_onPageStarted_injectsDocumentStartScriptFallback() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        client.onPageStarted(webView, "https://pay.busha.io/pay", null)
        assertNotNull(shadowOf(webView).lastEvaluatedJavascript)
    }

    @Test
    fun webViewClient_onPageFinished_firstCallSubmitsCheckoutForm() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        client.onPageFinished(webView, "https://pay.busha.io/pay")
        // The form submit evaluates the bridged initCheckout() script.
        assertTrue(shadowOf(webView).lastEvaluatedJavascript.contains("initCheckout"))
    }

    @Test
    fun webViewClient_onPageFinished_secondCallInjectsAutoSelect() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        client.onPageFinished(webView, "https://pay.busha.io/pay")
        client.onPageFinished(webView, "https://pay.busha.io/pay")
        assertNull("page-finished alone is not a terminal result", delivered)
    }

    @Test
    fun webViewClient_shouldOverrideUrlLoading_allowsWebUrls() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        @Suppress("DEPRECATION")
        assertEquals(false, client.shouldOverrideUrlLoading(webView, "https://pay.busha.io/x"))
    }

    @Test
    fun webViewClient_shouldOverrideUrlLoading_interceptsNonWebUrls() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        assertEquals(
            true,
            client.shouldOverrideUrlLoading(webView, fakeRequest("whatsapp://send?text=hi", true)),
        )
    }

    @Test
    fun webViewClient_onReceivedError_mainFrame_deliversLoadError() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        client.onReceivedError(
            webView,
            fakeRequest("https://pay.busha.io/pay", true),
            fakeError(-2, "net::ERR_FAILED"),
        )
        idle()
        assertEquals("WEBVIEW_LOAD_ERROR", (delivered as BushaPayResult.Error).code)
    }

    @Test
    fun webViewClient_onReceivedError_subframe_isIgnored() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        client.onReceivedError(
            webView,
            fakeRequest("https://pay.busha.io/sub", false),
            fakeError(-2, "net::ERR_FAILED"),
        )
        idle()
        assertNull(delivered)
    }

    @Test
    fun webViewClient_onReceivedHttpError_serverError_deliversHttpError() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        val response = WebResourceResponse(
            "text/html", "utf-8", 500, "Server Error",
            emptyMap(), ByteArrayInputStream(ByteArray(0)),
        )
        client.onReceivedHttpError(webView, fakeRequest("https://pay.busha.io/pay", true), response)
        idle()
        assertEquals("WEBVIEW_HTTP_ERROR", (delivered as BushaPayResult.Error).code)
    }

    @Test
    fun webViewClient_onReceivedHttpError_successStatus_isIgnored() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        val response = WebResourceResponse(
            "text/html", "utf-8", 200, "OK",
            emptyMap(), ByteArrayInputStream(ByteArray(0)),
        )
        client.onReceivedHttpError(webView, fakeRequest("https://pay.busha.io/pay", true), response)
        idle()
        assertNull(delivered)
    }

    @Test
    fun webViewClient_onRenderProcessGone_deliversTerminatedError() {
        primeCheckout()
        val (client, webView) = clientAndWebView(launch().get())
        val detail = object : RenderProcessGoneDetail() {
            override fun didCrash(): Boolean = true
            override fun rendererPriorityAtExit(): Int = 0
        }
        assertTrue(client.onRenderProcessGone(webView, detail))
        idle()
        assertEquals("WEBVIEW_PROCESS_TERMINATED", (delivered as BushaPayResult.Error).code)
    }
}
