package co.busha.pay

import co.busha.pay.internal.getOrigin

/**
 * Configuration for a Busha Pay checkout session.
 */
data class BushaPayConfig(
    /** Amount to charge (e.g. `"10000"`). */
    val quoteAmount: String,
    /** Currency for the quoted amount (e.g. `"NGN"`). */
    val quoteCurrency: String,
    /** Settlement currency the merchant receives. */
    val targetCurrency: String,
    /** Currency the customer pays in. */
    val sourceCurrency: String,
    /** Optional merchant reference for reconciliation. */
    val reference: String? = null,
    /** Optional customer name. */
    val metaName: String? = null,
    /** Optional customer email. */
    val metaEmail: String? = null,
    /** Optional customer phone number. */
    val metaPhone: String? = null,
    /**
     * Restricts which payment methods the chooser offers.
     *
     * - `null` or empty → show the full chooser (default).
     * - One method → skip the chooser and route straight to it.
     * - Multiple methods → show the chooser with only those tiles.
     */
    val allowedPaymentMethods: List<PaymentMethod>? = null,
) {
    /** Builds the hidden-form fields posted to the web checkout. */
    internal fun toFormFields(
        publicKey: String,
        callbackUrl: String,
        checkoutUrl: String,
    ): Map<String, String> {
        val fields = linkedMapOf(
            "public_key" to publicKey,
            "quote_amount" to quoteAmount,
            "quote_currency" to quoteCurrency,
            "target_currency" to targetCurrency,
            "source_currency" to sourceCurrency,
            "callback_url" to callbackUrl,
            "displayMode" to "INLINE",
        )
        getOrigin(checkoutUrl)?.let { fields["parentOrigin"] = it }
        reference?.takeIf { it.isNotEmpty() }?.let { fields["reference"] = it }
        metaName?.takeIf { it.isNotEmpty() }?.let { fields["meta[name]"] = it }
        metaEmail?.takeIf { it.isNotEmpty() }?.let { fields["meta[email]"] = it }
        metaPhone?.takeIf { it.isNotEmpty() }?.let { fields["meta[phone_number]"] = it }
        return fields
    }
}
