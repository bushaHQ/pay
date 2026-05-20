package co.busha.pay

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import co.busha.pay.internal.AutoSelect
import co.busha.pay.internal.CheckoutActivity
import co.busha.pay.internal.ChooserDialog
import co.busha.pay.internal.bushaAppScheme
import co.busha.pay.internal.buildBushaAppDeepLink
import co.busha.pay.internal.fetchMerchantName
import co.busha.pay.internal.parseCallback
import co.busha.pay.internal.parseUrl

/**
 * Busha Pay SDK for Android.
 *
 * Initialize once, then call [checkout] to launch the payment flow.
 *
 * ```kotlin
 * BushaPay.initialize(context, publicKey = "pub_xxx")
 *
 * BushaPay.checkout(activity, config) { result ->
 *     when (result) {
 *         is BushaPayResult.Success -> { /* ... */ }
 *         is BushaPayResult.Cancelled -> { /* ... */ }
 *         is BushaPayResult.Error -> { /* ... */ }
 *     }
 * }
 * ```
 */
object BushaPay {

    private var appContext: Context? = null
    private var publicKeyValue: String? = null
    private var environmentValue: BushaEnvironment = BushaEnvironment.LIVE
    private var checkoutInProgress = false

    private var pendingCompletion: ((BushaPayResult) -> Unit)? = null
    private var directLaunchResolver: ((String) -> Unit)? = null
    private var pendingCallbackHandler: ((String) -> Unit)? = null

    /** Config + auto-select handed to [CheckoutActivity] when it starts. */
    internal var pendingConfig: BushaPayConfig? = null
    internal var pendingAutoSelect: AutoSelect = AutoSelect.NONE

    private val mainHandler = Handler(Looper.getMainLooper())

    /** Whether the SDK has been initialized. */
    val isInitialized: Boolean get() = publicKeyValue != null

    /** Whether a checkout is currently in progress. */
    val isCheckoutInProgress: Boolean get() = checkoutInProgress

    internal val publicKey: String
        get() = requireNotNull(publicKeyValue) {
            "BushaPay.initialize() must be called first"
        }

    internal val isDevMode: Boolean get() = environmentValue == BushaEnvironment.SANDBOX

    internal val checkoutUrl: String
        get() = if (isDevMode) "https://staging.pay.busha.io/pay" else "https://pay.busha.io/pay"

    internal val platformUrl: String
        get() = if (isDevMode) "https://api.sandbox.busha.so" else "https://api.busha.io"

    internal val callbackScheme: String
        get() = "${appContext?.packageName ?: "app"}.busha-pay"

    internal val callbackUrl: String get() = "$callbackScheme://callback"

    /**
     * Initialize the Busha Pay SDK. Call once at app startup.
     */
    fun initialize(
        context: Context,
        publicKey: String,
        environment: BushaEnvironment = BushaEnvironment.LIVE,
    ) {
        appContext = context.applicationContext
        publicKeyValue = publicKey
        environmentValue = environment
    }

    /**
     * Launches the Busha Pay checkout flow. [onComplete] is called
     * exactly once, on the main thread.
     */
    fun checkout(
        activity: Activity,
        config: BushaPayConfig,
        onComplete: (BushaPayResult) -> Unit,
    ) {
        check(isInitialized) { "BushaPay.initialize() must be called before checkout()" }
        if (checkoutInProgress) {
            onComplete(
                BushaPayResult.Error(
                    message = "Another payment is already in progress",
                    code = "CHECKOUT_IN_PROGRESS",
                ),
            )
            return
        }
        checkoutInProgress = true
        pendingCompletion = onComplete
        runCheckout(activity, config)
    }

    /**
     * Forwards a deep-link URL to the SDK. Returns `true` if the URL was
     * a Busha Pay callback the SDK consumed. Wire this into your app's
     * deep-link / `Intent` handling.
     */
    fun handleDeepLink(url: String): Boolean {
        if (!isBushaCallback(url)) return false
        val resolver = directLaunchResolver
        if (resolver != null) {
            directLaunchResolver = null
            resolver(url)
            return true
        }
        pendingCallbackHandler?.invoke(url)
        return true
    }

    private fun runCheckout(activity: Activity, config: BushaPayConfig) {
        val allowed = config.allowedPaymentMethods
        if (allowed != null && allowed.size == 1) {
            routeChoice(activity, config, allowed.first())
            return
        }
        ChooserDialog.show(
            activity = activity,
            config = config,
            allowedPaymentMethods = allowed,
            merchantNameLoader = { fetchMerchantName(publicKey, platformUrl) },
            onChoose = { method ->
                if (method == null) {
                    deliverResult(
                        BushaPayResult.Cancelled(BushaPayCancelledReason.DISMISSED),
                    )
                } else {
                    routeChoice(activity, config, method)
                }
            },
        )
    }

    private fun routeChoice(activity: Activity, config: BushaPayConfig, method: PaymentMethod) {
        if (method == PaymentMethod.BUSHA_APP) {
            val deepLink = buildBushaAppDeepLink(
                scheme = bushaAppScheme(environmentValue),
                config = config,
                publicKey = publicKey,
                callbackUrl = callbackUrl,
            )
            if (canOpen(activity, deepLink)) {
                launchBushaApp(activity, deepLink)
                return
            }
        }
        val autoSelect =
            if (method == PaymentMethod.BUSHA_APP) AutoSelect.BUSHA_APP else AutoSelect.STABLECOINS
        presentCheckout(activity, config, autoSelect)
    }

    private fun presentCheckout(activity: Activity, config: BushaPayConfig, autoSelect: AutoSelect) {
        pendingConfig = config
        pendingAutoSelect = autoSelect
        activity.startActivity(Intent(activity, CheckoutActivity::class.java))
    }

    private fun launchBushaApp(activity: Activity, deepLink: String) {
        var finished = false
        val app = appContext as? Application
        var callbacks: Application.ActivityLifecycleCallbacks? = null

        val finish: (BushaPayResult) -> Unit = { result ->
            if (!finished) {
                finished = true
                directLaunchResolver = null
                callbacks?.let { app?.unregisterActivityLifecycleCallbacks(it) }
                deliverResult(result)
            }
        }

        directLaunchResolver = { url -> finish(parseCallback(url)) }

        callbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityResumed(a: Activity) {
                // The app returned to the foreground. If no callback
                // lands within 1.5s, the user came back without a
                // result — the outcome is unverified (ABANDONED), not a
                // confirmed cancellation.
                mainHandler.postDelayed({
                    if (!finished) {
                        finish(
                            BushaPayResult.Cancelled(BushaPayCancelledReason.ABANDONED),
                        )
                    }
                }, 1500)
            }

            override fun onActivityCreated(a: Activity, b: Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
            override fun onActivityPaused(a: Activity) {}
            override fun onActivityStopped(a: Activity) {}
            override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
            override fun onActivityDestroyed(a: Activity) {}
        }
        app?.registerActivityLifecycleCallbacks(callbacks)

        try {
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)))
        } catch (_: Exception) {
            finish(
                BushaPayResult.Error(
                    message = "Could not open the Busha app",
                    code = "BUSHA_APP_LAUNCH_FAILED",
                ),
            )
        }
    }

    private fun canOpen(context: Context, url: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        return intent.resolveActivity(context.packageManager) != null
    }

    private fun isBushaCallback(url: String): Boolean {
        val parsed = parseUrl(url) ?: return false
        return parsed.scheme == callbackScheme && parsed.host == "callback"
    }

    /** Registers the active checkout's deep-link callback handler. */
    internal fun registerCallbackHandler(handler: ((String) -> Unit)?) {
        pendingCallbackHandler = handler
    }

    /** Parses a callback URL into a result. */
    internal fun resultFromCallback(url: String): BushaPayResult = parseCallback(url)

    /**
     * Delivers the final result to the merchant's callback exactly once
     * and clears all checkout state.
     */
    internal fun deliverResult(result: BushaPayResult) {
        val completion = pendingCompletion ?: return
        pendingCompletion = null
        pendingCallbackHandler = null
        directLaunchResolver = null
        pendingConfig = null
        pendingAutoSelect = AutoSelect.NONE
        checkoutInProgress = false
        mainHandler.post { completion(result) }
    }

    /** Test-only: clears all initialization and checkout state. */
    internal fun resetForTesting() {
        appContext = null
        publicKeyValue = null
        environmentValue = BushaEnvironment.LIVE
        checkoutInProgress = false
        pendingCompletion = null
        directLaunchResolver = null
        pendingCallbackHandler = null
        pendingConfig = null
        pendingAutoSelect = AutoSelect.NONE
    }
}
