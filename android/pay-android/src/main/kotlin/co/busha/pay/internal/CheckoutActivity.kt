package co.busha.pay.internal

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import androidx.annotation.RequiresApi
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import co.busha.pay.BushaPay
import co.busha.pay.BushaPayCancelledReason
import co.busha.pay.BushaPayResult
import org.json.JSONObject

/**
 * Hosts the WebView that runs the Busha web checkout. Translucent
 * Activity — the merchant's screen stays dimmed behind it.
 */
internal class CheckoutActivity : Activity() {

    private lateinit var webView: WebView
    private lateinit var loadingOverlay: View

    private val mainHandler = Handler(Looper.getMainLooper())
    private var bootstrapTimer: Runnable? = null

    private var delivered = false
    private var formSubmitted = false
    private var autoSelectInjected = false

    private val config = BushaPay.pendingConfig
    private val autoSelect = BushaPay.pendingAutoSelect
    private val checkoutUrl = runCatching { BushaPay.checkoutUrl }.getOrNull()
    private val callbackUrl = runCatching { BushaPay.callbackUrl }.getOrNull()

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val cfg = config
        if (cfg == null || checkoutUrl == null || callbackUrl == null) {
            // Launched without state (e.g. process death). Nothing to do.
            finish()
            return
        }

        setContentView(buildContentView())

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            javaScriptCanOpenWindowsAutomatically = true
        }
        if (isDebuggable()) WebView.setWebContentsDebuggingEnabled(true)

        webView.addJavascriptInterface(BridgeInterface(), JS_INTERFACE_NAME)
        webView.webViewClient = CheckoutWebViewClient()
        injectDocumentStartScripts()

        BushaPay.registerCallbackHandler { url -> deliver(BushaPay.resultFromCallback(url)) }

        loadCheckoutHtml(cfg)
        startBootstrapTimer()
    }

    private fun buildContentView(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.TRANSPARENT)
        }
        // Tapping the dimmed strip above the sheet dismisses checkout.
        root.addView(
            View(this).apply {
                isClickable = true
                setOnClickListener {
                    deliver(BushaPayResult.Cancelled(BushaPayCancelledReason.DISMISSED))
                }
            },
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 8f),
        )

        val card = FrameLayout(this).apply {
            setBackgroundColor(Color.WHITE)
        }
        webView = WebView(this)
        card.addView(
            webView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        loadingOverlay = FrameLayout(this).apply {
            setBackgroundColor(Color.WHITE)
            addView(
                ProgressBar(this@CheckoutActivity),
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER,
                ),
            )
        }
        card.addView(
            loadingOverlay,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        root.addView(
            card,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 92f),
        )
        return root
    }

    private fun loadCheckoutHtml(cfg: co.busha.pay.BushaPayConfig) {
        val html = try {
            assets.open("busha_pay_checkout.html").bufferedReader().use { it.readText() }
        } catch (_: Exception) {
            deliver(
                BushaPayResult.Error(
                    message = "Failed to load the bundled checkout page",
                    code = "HTML_LOAD_ERROR",
                ),
            )
            return
        }
        webView.loadDataWithBaseURL(checkoutUrl, html, "text/html", "utf-8", null)
    }

    private fun injectDocumentStartScripts() {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(webView, DOCUMENT_START_SCRIPTS, setOf("*"))
        }
        // When the feature is unavailable the WebViewClient's
        // onPageStarted fallback injects the scripts instead.
    }

    private fun submitCheckoutForm(cfg: co.busha.pay.BushaPayConfig) {
        val fields = cfg.toFormFields(
            publicKey = BushaPay.publicKey,
            callbackUrl = callbackUrl!!,
            checkoutUrl = checkoutUrl!!,
        )
        val queryMethod = autoSelect.queryParam
        val formAction =
            if (queryMethod != null) "$checkoutUrl?paymentMethod=$queryMethod" else checkoutUrl
        val payload = JSONObject().apply {
            put("_checkoutUrl", formAction)
            fields.forEach { (k, v) -> put(k, v) }
        }.toString()
        webView.evaluateJavascript(initCheckoutScript(payload), null)
    }

    private inner class BridgeInterface {
        @JavascriptInterface
        fun postMessage(payload: String) {
            // Runs on a JavaBridge thread — marshal onto the main thread.
            mainHandler.post { onBridgeMessage(payload) }
        }
    }

    private fun onBridgeMessage(payload: String) {
        when (val msg = parseBridgeMessage(payload)) {
            is BridgeMessage.Ready -> {
                cancelBootstrapTimer()
                loadingOverlay.visibility = View.GONE
            }
            is BridgeMessage.Result -> deliver(msg.result)
            BridgeMessage.Unknown -> Unit
        }
    }

    private inner class CheckoutWebViewClient : WebViewClient() {

        override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
            // Fallback for devices without the DOCUMENT_START_SCRIPT
            // feature — inject as early as the framework allows.
            if (!WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
                view.evaluateJavascript(DOCUMENT_START_SCRIPTS, null)
            }
        }

        override fun onPageFinished(view: WebView, url: String?) {
            val cfg = config ?: return
            if (!formSubmitted) {
                formSubmitted = true
                submitCheckoutForm(cfg)
                return
            }
            // The page is rendered but commerce-js may not have wired up
            // its handlers yet — keep the overlay until the bridge fires
            // `ready`. Only inject the auto-select hint here.
            if (!autoSelectInjected) {
                autoSelectInjected = true
                autoSelect.rowTextPrefix?.let {
                    view.evaluateJavascript(autoSelectScript(it), null)
                }
            }
        }

        @RequiresApi(Build.VERSION_CODES.M)
        override fun onReceivedError(
            view: WebView,
            request: WebResourceRequest,
            error: WebResourceError,
        ) {
            if (!request.isForMainFrame) return
            deliver(
                BushaPayResult.Error(
                    message = "Could not load checkout (${error.description})",
                    code = "WEBVIEW_LOAD_ERROR",
                ),
            )
        }

        @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
        override fun onReceivedError(
            view: WebView,
            errorCode: Int,
            description: String?,
            failingUrl: String?,
        ) {
            // Legacy callback — only meaningful on API 21-22; the
            // WebResourceRequest overload handles 23+.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) return
            deliver(
                BushaPayResult.Error(
                    message = "Could not load checkout (${description ?: "unknown error"})",
                    code = "WEBVIEW_LOAD_ERROR",
                ),
            )
        }

        @RequiresApi(Build.VERSION_CODES.M)
        override fun onReceivedHttpError(
            view: WebView,
            request: WebResourceRequest,
            errorResponse: WebResourceResponse,
        ) {
            if (!request.isForMainFrame) return
            val status = errorResponse.statusCode
            if (status in 200..299) return
            deliver(
                BushaPayResult.Error(
                    message = "Checkout failed (HTTP $status)",
                    code = "WEBVIEW_HTTP_ERROR",
                ),
            )
        }

        @RequiresApi(Build.VERSION_CODES.O)
        override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
            deliver(
                BushaPayResult.Error(
                    message = "The checkout WebView was terminated",
                    code = "WEBVIEW_PROCESS_TERMINATED",
                ),
            )
            return true
        }

        @RequiresApi(Build.VERSION_CODES.N)
        override fun shouldOverrideUrlLoading(
            view: WebView,
            request: WebResourceRequest,
        ): Boolean = handleNavigation(request.url?.toString())

        @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
        override fun shouldOverrideUrlLoading(view: WebView, url: String?): Boolean =
            handleNavigation(url)
    }

    /** Returns true (override) for non-web URLs, opening them externally. */
    private fun handleNavigation(url: String?): Boolean {
        if (url == null) return false
        val scheme = parseUrl(url)?.scheme ?: return false
        if (isWebScheme(scheme)) return false
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        } catch (_: ActivityNotFoundException) {
            // No app to handle it — swallow rather than crash.
        }
        return true
    }

    private fun startBootstrapTimer() {
        val timer = Runnable {
            if (!delivered) {
                deliver(
                    BushaPayResult.Error(
                        message = "Checkout timed out before loading",
                        code = "WEBVIEW_TIMEOUT",
                    ),
                )
            }
        }
        bootstrapTimer = timer
        mainHandler.postDelayed(timer, BOOTSTRAP_TIMEOUT_MS)
    }

    private fun cancelBootstrapTimer() {
        bootstrapTimer?.let { mainHandler.removeCallbacks(it) }
        bootstrapTimer = null
    }

    private fun deliver(result: BushaPayResult) {
        if (delivered) return
        delivered = true
        cancelBootstrapTimer()
        BushaPay.registerCallbackHandler(null)
        BushaPay.deliverResult(result)
        finish()
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        deliver(BushaPayResult.Cancelled(BushaPayCancelledReason.DISMISSED))
    }

    override fun onDestroy() {
        // If the Activity is torn down without a result (task swipe,
        // system kill), treat it as a dismissal.
        if (!delivered) {
            delivered = true
            cancelBootstrapTimer()
            BushaPay.registerCallbackHandler(null)
            BushaPay.deliverResult(
                BushaPayResult.Cancelled(BushaPayCancelledReason.DISMISSED),
            )
        }
        if (::webView.isInitialized) webView.destroy()
        super.onDestroy()
    }

    private fun isDebuggable(): Boolean =
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    companion object {
        private const val BOOTSTRAP_TIMEOUT_MS = 30_000L
    }
}
