package co.busha.pay.example

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import co.busha.pay.BushaPay
import co.busha.pay.BushaPayConfig
import co.busha.pay.BushaPayResult

/**
 * A one-screen demo storefront: a product, a "Pay" button, and a line
 * that reports whatever the SDK hands back.
 */
class StoreActivity : Activity() {

    private lateinit var statusView: TextView
    private lateinit var payButton: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildUi())
        forwardBushaCallback(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        forwardBushaCallback(intent)
    }

    /** Hands any incoming deep link to the SDK. */
    private fun forwardBushaCallback(intent: Intent?) {
        intent?.data?.toString()?.let { BushaPay.handleDeepLink(it) }
    }

    private fun startCheckout() {
        payButton.isEnabled = false
        statusView.text = "Starting checkout…"

        BushaPay.checkout(
            activity = this,
            config = BushaPayConfig(
                quoteAmount = "10000",
                quoteCurrency = "NGN",
                targetCurrency = "NGN",
                sourceCurrency = "USDT",
                metaName = "Jane Doe",
                metaEmail = "jane@example.com",
            ),
        ) { result ->
            payButton.isEnabled = true
            statusView.text = when (result) {
                is BushaPayResult.Success ->
                    "✅ Paid — ${result.paymentId} (${result.status})"
                is BushaPayResult.Cancelled ->
                    "⚠️ Cancelled — ${result.reason}"
                is BushaPayResult.Error ->
                    "❌ Error — ${result.message} [${result.code ?: "no code"}]"
            }
        }
    }

    // --- UI ----------------------------------------------------------

    private fun buildUi(): View {
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(BACKGROUND)
            setPadding(dp(24), dp(48), dp(24), dp(24))

            addView(
                TextView(this@StoreActivity).apply {
                    text = "Busha Store"
                    textSize = 28f
                    setTextColor(TEXT_HIGH)
                    setTypeface(typeface, Typeface.BOLD)
                },
            )
            addView(spacer(dp(24)))
            addView(productCard())
            addView(spacer(dp(24)))
            addView(
                Button(this@StoreActivity).apply {
                    text = "Pay ₦10,000"
                    setOnClickListener { startCheckout() }
                }.also { payButton = it },
            )
            addView(spacer(dp(24)))
            addView(
                TextView(this@StoreActivity).apply {
                    text = "No payment yet."
                    textSize = 15f
                    setTextColor(TEXT_MID)
                }.also { statusView = it },
            )
        }

        return ScrollView(this).apply {
            setBackgroundColor(BACKGROUND)
            addView(
                content,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
        }
    }

    private fun productCard(): View = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(Color.WHITE)
            cornerRadius = dp(16).toFloat()
        }
        setPadding(dp(20), dp(20), dp(20), dp(20))

        addView(
            TextView(this@StoreActivity).apply {
                text = "Premium Plan"
                textSize = 18f
                setTextColor(TEXT_HIGH)
                setTypeface(typeface, Typeface.BOLD)
            },
        )
        addView(spacer(dp(4)))
        addView(
            TextView(this@StoreActivity).apply {
                text = "One year of everything, paid in crypto."
                textSize = 14f
                setTextColor(TEXT_MID)
            },
        )
        addView(spacer(dp(12)))
        addView(
            TextView(this@StoreActivity).apply {
                text = "₦10,000"
                textSize = 22f
                setTextColor(ACCENT)
                setTypeface(typeface, Typeface.BOLD)
            },
        )
    }

    private fun spacer(heightPx: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            heightPx,
        )
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private companion object {
        const val BACKGROUND = 0xFFF2F4F2.toInt()
        const val TEXT_HIGH = 0xFF111711.toInt()
        const val TEXT_MID = 0xFF586558.toInt()
        const val ACCENT = 0xFF1B5E20.toInt()
    }
}
