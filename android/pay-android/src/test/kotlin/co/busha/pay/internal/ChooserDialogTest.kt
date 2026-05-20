package co.busha.pay.internal

import android.app.Activity
import android.app.Dialog
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import co.busha.pay.BushaPayConfig
import co.busha.pay.PaymentMethod
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
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowDialog

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ChooserDialogTest {

    private lateinit var activity: Activity

    private val config = BushaPayConfig(
        quoteAmount = "10000",
        quoteCurrency = "NGN",
        targetCurrency = "NGN",
        sourceCurrency = "USDT",
    )

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    }

    /** Captures the chooser outcome and how many times it was delivered. */
    private class Outcome {
        var method: PaymentMethod? = null
        var calls = 0
    }

    private fun show(allowed: List<PaymentMethod>? = null): Pair<Dialog, Outcome> {
        val outcome = Outcome()
        ChooserDialog.show(
            activity = activity,
            config = config,
            allowedPaymentMethods = allowed,
            merchantNameLoader = { null },
            onChoose = { outcome.method = it; outcome.calls++ },
        )
        return ShadowDialog.getLatestDialog() to outcome
    }

    private fun Dialog.find(contentDescription: String): View? =
        window?.decorView?.findByContentDescription(contentDescription)

    private fun View.findByContentDescription(desc: String): View? {
        if (contentDescription == desc) return this
        if (this is ViewGroup) {
            for (i in 0 until childCount) {
                getChildAt(i).findByContentDescription(desc)?.let { return it }
            }
        }
        return null
    }

    @Test
    fun show_displaysDialogWithBothTilesByDefault() {
        val (dialog, _) = show()
        assertTrue(dialog.isShowing)
        assertNotNull(dialog.find("Busha"))
        assertNotNull(dialog.find("Stablecoins"))
        assertNotNull(dialog.find("Close"))
    }

    @Test
    fun bushaTileClick_choosesBushaApp() {
        val (dialog, outcome) = show()
        dialog.find("Busha")!!.performClick()
        assertEquals(PaymentMethod.BUSHA_APP, outcome.method)
        assertEquals(1, outcome.calls)
        assertTrue(!dialog.isShowing)
    }

    @Test
    fun stablecoinsTileClick_choosesStablecoins() {
        val (dialog, outcome) = show()
        dialog.find("Stablecoins")!!.performClick()
        assertEquals(PaymentMethod.STABLECOINS, outcome.method)
        assertEquals(1, outcome.calls)
    }

    @Test
    fun closeButtonClick_choosesNull() {
        val (dialog, outcome) = show()
        dialog.find("Close")!!.performClick()
        assertNull(outcome.method)
        assertEquals(1, outcome.calls)
        assertTrue(!dialog.isShowing)
    }

    @Test
    fun dialogCancel_choosesNull() {
        val (dialog, outcome) = show()
        dialog.cancel()
        shadowOf(Looper.getMainLooper()).idle()
        assertNull(outcome.method)
        assertEquals(1, outcome.calls)
    }

    @Test
    fun onChoose_isCalledExactlyOnce_evenAfterAdditionalDismiss() {
        val (dialog, outcome) = show()
        dialog.find("Busha")!!.performClick()
        dialog.cancel()
        dialog.dismiss()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(1, outcome.calls)
    }

    @Test
    fun allowedPaymentMethods_bushaOnly_isRoutedDirectly() {
        // A single allowed method never reaches the chooser — BushaPay
        // routes it straight through. The chooser itself still honours
        // the filter when handed a single-element list.
        val (dialog, _) = show(allowed = listOf(PaymentMethod.BUSHA_APP))
        assertNotNull(dialog.find("Busha"))
        assertNull(dialog.find("Stablecoins"))
    }

    @Test
    fun allowedPaymentMethods_stablecoinsOnly_hidesBushaTile() {
        val (dialog, _) = show(allowed = listOf(PaymentMethod.STABLECOINS))
        assertNull(dialog.find("Busha"))
        assertNotNull(dialog.find("Stablecoins"))
    }

    @Test
    fun allowedPaymentMethods_emptyList_showsAllTiles() {
        val (dialog, _) = show(allowed = emptyList())
        assertNotNull(dialog.find("Busha"))
        assertNotNull(dialog.find("Stablecoins"))
    }

    @Test
    fun formatAmount_groupsThousandsForWholeNumbers() {
        assertEquals("10,000", ChooserDialog.formatAmount("10000"))
        assertEquals("1,234,567", ChooserDialog.formatAmount("1234567"))
    }

    @Test
    fun formatAmount_keepsTwoDecimalsOnlyWhenFractional() {
        assertEquals("1,250.50", ChooserDialog.formatAmount("1250.5"))
        assertEquals("100", ChooserDialog.formatAmount("100.0"))
    }

    @Test
    fun formatAmount_returnsInputUnchangedWhenNotNumeric() {
        assertEquals("abc", ChooserDialog.formatAmount("abc"))
        assertEquals("", ChooserDialog.formatAmount(""))
    }
}
