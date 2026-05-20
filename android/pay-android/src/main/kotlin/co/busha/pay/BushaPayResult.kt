package co.busha.pay

/**
 * Result of a Busha Pay checkout.
 *
 * Match exhaustively with `when`:
 * ```kotlin
 * when (result) {
 *     is BushaPayResult.Success -> println("Paid: ${result.paymentId}")
 *     is BushaPayResult.Cancelled -> println("Cancelled: ${result.reason}")
 *     is BushaPayResult.Error -> println("Error: ${result.message}")
 * }
 * ```
 */
sealed interface BushaPayResult {

    /**
     * Payment completed successfully.
     *
     * Full payment data (amounts, rates, timeline) is available when the
     * payment was completed in the web checkout flow. When completed via
     * the Busha app, only [paymentId] and [status] are populated — check
     * [hasFullData].
     *
     * **Important:** always verify the payment server-side via webhooks.
     * The client result is a UX hint, not the source of truth.
     */
    data class Success(
        /** Payment request ID (e.g. `"PAYR_EhDmpnPwDSjO"`). Always present. */
        val paymentId: String,
        /** Payment status (e.g. `"completed"`). Always present. */
        val status: String,
        val sourceAmount: String? = null,
        val sourceCurrency: String? = null,
        val targetAmount: String? = null,
        val targetCurrency: String? = null,
        val requestedAmount: String? = null,
        val currency: String? = null,
        val rate: Map<String, Any?>? = null,
        val merchantInfo: Map<String, Any?>? = null,
        val timeline: Map<String, Any?>? = null,
        /** Full unmodified payload from the web checkout. */
        val rawData: Map<String, Any?>? = null,
    ) : BushaPayResult {
        /**
         * `true` when full web-checkout data is present; `false` for
         * Busha-app callbacks, which carry only [paymentId] and [status].
         */
        val hasFullData: Boolean get() = rawData != null
    }

    /**
     * The checkout ended without a completed payment.
     *
     * Inspect [reason] to tell *how* it ended. In particular,
     * [BushaPayCancelledReason.ABANDONED] does **not** mean the payment
     * failed — only that the SDK never received a result. Verify
     * server-side before showing the user a final state.
     */
    data class Cancelled(
        /** How the checkout ended. */
        val reason: BushaPayCancelledReason = BushaPayCancelledReason.DISMISSED,
        /**
         * The payment request ID. Present only when [reason] is
         * [BushaPayCancelledReason.REJECTED] — the Busha app hands it
         * back so the merchant can reconcile the rejected request.
         */
        val paymentId: String? = null,
    ) : BushaPayResult

    /** An error occurred during checkout. */
    data class Error(
        /** Human-readable diagnostic message. */
        val message: String,
        /** Machine-readable error code, when available. */
        val code: String? = null,
    ) : BushaPayResult
}

/** Why a checkout ended without a completed payment. */
enum class BushaPayCancelledReason {
    /**
     * The user dismissed the in-app chooser or web checkout sheet —
     * close button, backdrop tap, or back press.
     */
    DISMISSED,

    /**
     * The Busha app reported that the user explicitly rejected the
     * payment. [BushaPayResult.Cancelled.paymentId] carries the request
     * ID so the merchant can reconcile server-side.
     */
    REJECTED,

    /**
     * The user returned to your app from the Busha app without a
     * callback arriving. The payment outcome is **unverified** — it may
     * still have succeeded. Always reconcile server-side.
     */
    ABANDONED,
}
