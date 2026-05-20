package co.busha.pay.internal

import android.app.Activity
import android.app.Dialog
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import co.busha.pay.BushaPayConfig
import co.busha.pay.PaymentMethod
import co.busha.pay.R
import java.text.DecimalFormat

/**
 * The payment-method chooser — a plain [Dialog] (no Material / Compose
 * dependency) with a rounded card: amount, optional merchant line, and
 * one tile per allowed payment method.
 */
internal object ChooserDialog {

    private const val TEXT_HIGH = 0xFF000000.toInt()
    private const val TEXT_MID = 0xFF586558.toInt()
    private const val CONTAINMENT_PRIMARY = 0xFFEDF2ED.toInt()
    private const val CONTAINMENT_SECONDARY = 0xFFD1D9D1.toInt()
    private const val CONTAINMENT_TERTIARY = 0xFFFFFFFF.toInt()

    /**
     * Shows the chooser. [onChoose] receives the picked method, or
     * `null` when the dialog is dismissed without a choice. Called
     * exactly once. [merchantNameLoader] is run off the main thread.
     */
    fun show(
        activity: Activity,
        config: BushaPayConfig,
        allowedPaymentMethods: List<PaymentMethod>?,
        merchantNameLoader: () -> String?,
        onChoose: (PaymentMethod?) -> Unit,
    ) {
        val showsBusha = methodAllowed(PaymentMethod.BUSHA_APP, allowedPaymentMethods)
        val showsStablecoins = methodAllowed(PaymentMethod.STABLECOINS, allowedPaymentMethods)

        val dialog = Dialog(activity)
        dialog.window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))

        var settled = false
        fun resolve(method: PaymentMethod?) {
            if (settled) return
            settled = true
            if (dialog.isShowing) dialog.dismiss()
            onChoose(method)
        }

        val merchantLine = TextView(activity).apply {
            textSize = 16f
            setTextColor(TEXT_MID)
            visibility = View.GONE
        }

        val card = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            background = roundedRect(CONTAINMENT_PRIMARY, dp(activity, 20))
            setPadding(dp(activity, 20), dp(activity, 20), dp(activity, 20), dp(activity, 20))

            addView(headerRow(activity, config, ::resolve))
            addView(merchantLine)
            addView(spacer(activity, 32))
            addView(
                TextView(activity).apply {
                    text = "Choose a payment method"
                    textSize = 18f
                    setTextColor(TEXT_HIGH)
                },
            )
            addView(spacer(activity, 12))
            if (showsBusha) {
                addView(
                    tile(
                        activity,
                        name = "Busha",
                        description = "Make payment directly from your busha account",
                        iconRes = R.drawable.busha,
                    ) { resolve(PaymentMethod.BUSHA_APP) },
                )
            }
            if (showsBusha && showsStablecoins) addView(spacer(activity, 16))
            if (showsStablecoins) {
                addView(
                    tile(
                        activity,
                        name = "Stablecoins",
                        description = "Make payment from an external wallet",
                        iconRes = R.drawable.wallet_outline,
                    ) { resolve(PaymentMethod.STABLECOINS) },
                )
            }
            addView(spacer(activity, 32))
            addView(securedByFooter(activity))
        }

        val root = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(activity, 16), dp(activity, 24), dp(activity, 16), dp(activity, 24))
            addView(
                card,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
        }

        dialog.setContentView(root)
        dialog.setOnCancelListener { resolve(null) }
        dialog.show()

        // Resolve the merchant name off the main thread; drop the result
        // if the dialog has already been dismissed.
        Thread {
            val name = merchantNameLoader()
            if (name != null) {
                Handler(Looper.getMainLooper()).post {
                    if (dialog.isShowing && !settled) {
                        merchantLine.text = "To $name"
                        merchantLine.visibility = View.VISIBLE
                    }
                }
            }
        }.start()
    }

    private fun methodAllowed(method: PaymentMethod, allowed: List<PaymentMethod>?): Boolean =
        allowed.isNullOrEmpty() || allowed.contains(method)

    private fun headerRow(
        activity: Activity,
        config: BushaPayConfig,
        resolve: (PaymentMethod?) -> Unit,
    ): View = LinearLayout(activity).apply {
        orientation = LinearLayout.HORIZONTAL
        addView(
            TextView(activity).apply {
                text = "Pay ${formatAmount(config.quoteAmount)} ${config.quoteCurrency}"
                textSize = 24f
                setTextColor(TEXT_HIGH)
            },
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        addView(
            TextView(activity).apply {
                text = "✕"
                textSize = 20f
                setTextColor(TEXT_HIGH)
                contentDescription = "Close"
                setPadding(dp(activity, 4), 0, dp(activity, 4), 0)
                setOnClickListener { resolve(null) }
            },
        )
    }

    private fun tile(
        activity: Activity,
        name: String,
        description: String,
        iconRes: Int,
        onTap: () -> Unit,
    ): View = LinearLayout(activity).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        background = roundedRect(CONTAINMENT_TERTIARY, dp(activity, 16))
        setPadding(dp(activity, 16), dp(activity, 16), dp(activity, 16), dp(activity, 16))
        isClickable = true
        contentDescription = name
        setOnClickListener { onTap() }

        // A 20dp template-tinted glyph centered in a 40dp circle.
        addView(
            FrameLayout(activity).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(CONTAINMENT_SECONDARY)
                }
                addView(
                    ImageView(activity).apply {
                        setImageResource(iconRes)
                        setColorFilter(TEXT_HIGH)
                    },
                    FrameLayout.LayoutParams(
                        dp(activity, 20),
                        dp(activity, 20),
                        Gravity.CENTER,
                    ),
                )
            },
            LinearLayout.LayoutParams(dp(activity, 40), dp(activity, 40)),
        )
        addView(
            LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(activity, 16), 0, dp(activity, 16), 0)
                addView(
                    TextView(activity).apply {
                        text = name
                        textSize = 16f
                        setTextColor(TEXT_HIGH)
                    },
                )
                addView(
                    TextView(activity).apply {
                        text = description
                        textSize = 12f
                        setTextColor(TEXT_MID)
                    },
                )
            },
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        addView(
            TextView(activity).apply {
                text = "›"
                textSize = 24f
                setTextColor(TEXT_MID)
            },
        )
    }

    private fun securedByFooter(activity: Activity): View = LinearLayout(activity).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER
        addView(
            TextView(activity).apply {
                text = "Secured by"
                textSize = 12f
                setTextColor(TEXT_MID)
            },
        )
        addView(
            ImageView(activity).apply {
                setImageResource(R.drawable.busha_logo)
            },
            LinearLayout.LayoutParams(dp(activity, 63), dp(activity, 14)).apply {
                marginStart = dp(activity, 8)
            },
        )
    }

    private fun spacer(activity: Activity, heightDp: Int): View = View(activity).apply {
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(activity, heightDp),
        )
    }

    private fun roundedRect(color: Int, radiusPx: Int): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = radiusPx.toFloat()
        }

    private fun dp(activity: Activity, value: Int): Int =
        (value * activity.resources.displayMetrics.density).toInt()

    /** Groups thousands and shows 2 decimals only when fractional. */
    internal fun formatAmount(amount: String): String {
        val n = amount.trim().toDoubleOrNull() ?: return amount
        val hasDecimals = n % 1.0 != 0.0
        val pattern = if (hasDecimals) "#,##0.00" else "#,##0"
        return DecimalFormat(pattern).format(n)
    }
}
