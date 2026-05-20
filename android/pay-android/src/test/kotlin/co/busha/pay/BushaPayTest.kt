package co.busha.pay

import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Looper
import co.busha.pay.internal.bushaAppScheme
import co.busha.pay.internal.buildBushaAppDeepLink
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BushaPayTest {

    private lateinit var activity: Activity

    private val config = BushaPayConfig(
        quoteAmount = "10000",
        quoteCurrency = "NGN",
        targetCurrency = "NGN",
        sourceCurrency = "USDT",
    )

    @Before
    fun setUp() {
        BushaPay.resetForTesting()
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    }

    @After
    fun tearDown() {
        BushaPay.resetForTesting()
    }

    @Test
    fun initialize_marksTheSdkInitialized() {
        assertFalse(BushaPay.isInitialized)
        BushaPay.initialize(activity, "pub_x")
        assertTrue(BushaPay.isInitialized)
    }

    @Test
    fun environmentUrls_defaultToLive() {
        BushaPay.initialize(activity, "pub_x")
        assertEquals("https://pay.busha.io/pay", BushaPay.checkoutUrl)
        assertEquals("https://api.busha.io", BushaPay.platformUrl)
        assertFalse(BushaPay.isDevMode)
    }

    @Test
    fun environmentUrls_respectSandbox() {
        BushaPay.initialize(activity, "pub_x", BushaEnvironment.SANDBOX)
        assertEquals("https://staging.pay.busha.io/pay", BushaPay.checkoutUrl)
        assertEquals("https://api.sandbox.busha.so", BushaPay.platformUrl)
        assertTrue(BushaPay.isDevMode)
    }

    @Test
    fun callbackUrl_derivesFromPackageName() {
        BushaPay.initialize(activity, "pub_x")
        assertTrue(BushaPay.callbackScheme.endsWith(".busha-pay"))
        assertEquals("${BushaPay.callbackScheme}://callback", BushaPay.callbackUrl)
    }

    @Test
    fun handleDeepLink_returnsFalseForNonCallbackUrls() {
        BushaPay.initialize(activity, "pub_x")
        assertFalse(BushaPay.handleDeepLink("https://example.com/foo"))
        assertFalse(BushaPay.handleDeepLink("${BushaPay.callbackScheme}://other"))
    }

    @Test
    fun handleDeepLink_returnsTrueForCallbackUrls() {
        BushaPay.initialize(activity, "pub_x")
        assertTrue(
            BushaPay.handleDeepLink(
                "${BushaPay.callbackScheme}://callback?status=completed&paymentRequestId=PAYR_1",
            ),
        )
    }

    @Test
    fun checkout_secondCallWhileInProgressReturnsCheckoutInProgressError() {
        BushaPay.initialize(activity, "pub_x")
        BushaPay.checkout(activity, config) { /* first — opens the chooser */ }

        var second: BushaPayResult? = null
        BushaPay.checkout(activity, config) { second = it }

        assertTrue(second is BushaPayResult.Error)
        assertEquals("CHECKOUT_IN_PROGRESS", (second as BushaPayResult.Error).code)
    }

    @Test
    fun checkout_opensWhenNoCheckoutInProgress() {
        BushaPay.initialize(activity, "pub_x")
        BushaPay.checkout(activity, config) { }
        assertTrue(BushaPay.isCheckoutInProgress)
    }

    @Test
    fun resetForTesting_clearsState() {
        BushaPay.initialize(activity, "pub_x")
        BushaPay.resetForTesting()
        assertFalse(BushaPay.isInitialized)
        assertFalse(BushaPay.isCheckoutInProgress)
    }

    private val bushaConfig = config.copy(
        allowedPaymentMethods = listOf(PaymentMethod.BUSHA_APP),
    )

    /** Registers the Busha app as installed so `canOpen` resolves true. */
    private fun installBushaApp(): String {
        val deepLink = buildBushaAppDeepLink(
            scheme = bushaAppScheme(BushaEnvironment.LIVE),
            config = bushaConfig,
            publicKey = "pub_x",
            callbackUrl = BushaPay.callbackUrl,
        )
        val resolveInfo = ResolveInfo().apply {
            activityInfo = ActivityInfo().apply {
                packageName = "co.busha.android"
                name = "MainActivity"
            }
        }
        shadowOf(activity.packageManager).addResolveInfoForIntent(
            Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)),
            resolveInfo,
        )
        return deepLink
    }

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    @Test
    fun checkout_bushaApp_whenInstalled_launchesTheDeepLink() {
        BushaPay.initialize(activity, "pub_x")
        installBushaApp()

        BushaPay.checkout(activity, bushaConfig) { }

        val started = shadowOf(activity).nextStartedActivity
        assertEquals(Intent.ACTION_VIEW, started.action)
        assertEquals("co.busha.android", started.data?.scheme)
    }

    @Test
    fun bushaAppLaunch_returningWithoutCallback_deliversAbandoned() {
        BushaPay.initialize(activity, "pub_x")
        installBushaApp()

        var result: BushaPayResult? = null
        BushaPay.checkout(activity, bushaConfig) { result = it }

        // Simulate the user returning to the app with no callback: a
        // fresh Activity resuming triggers the launcher's grace timer.
        Robolectric.buildActivity(Activity::class.java).setup()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(2))

        val cancelled = result as BushaPayResult.Cancelled
        assertEquals(BushaPayCancelledReason.ABANDONED, cancelled.reason)
    }

    @Test
    fun bushaAppLaunch_callbackWithCancelledStatus_deliversRejected() {
        BushaPay.initialize(activity, "pub_x")
        installBushaApp()

        var result: BushaPayResult? = null
        BushaPay.checkout(activity, bushaConfig) { result = it }

        val consumed = BushaPay.handleDeepLink(
            "${BushaPay.callbackScheme}://callback?status=cancelled&paymentRequestId=PAYR_REJ",
        )
        idle()

        assertTrue(consumed)
        val cancelled = result as BushaPayResult.Cancelled
        assertEquals(BushaPayCancelledReason.REJECTED, cancelled.reason)
        assertEquals("PAYR_REJ", cancelled.paymentId)
    }

    @Test
    fun bushaAppLaunch_callbackWithCompletedStatus_deliversSuccess() {
        BushaPay.initialize(activity, "pub_x")
        installBushaApp()

        var result: BushaPayResult? = null
        BushaPay.checkout(activity, bushaConfig) { result = it }

        BushaPay.handleDeepLink(
            "${BushaPay.callbackScheme}://callback?status=completed&paymentRequestId=PAYR_OK",
        )
        idle()

        assertEquals("PAYR_OK", (result as BushaPayResult.Success).paymentId)
    }
}
