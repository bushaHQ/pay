package co.busha.pay.internal

/** Hint passed to the web checkout to pre-select a payment method. */
internal enum class AutoSelect {
    NONE,
    BUSHA_APP,
    STABLECOINS;

    /** Query param appended to the checkout URL (`?paymentMethod=`). */
    val queryParam: String?
        get() = when (this) {
            BUSHA_APP -> "busha"
            STABLECOINS -> "stablecoins"
            NONE -> null
        }

    /** Chooser-row text prefix the auto-select script clicks. */
    val rowTextPrefix: String?
        get() = when (this) {
            BUSHA_APP -> "Busha"
            STABLECOINS -> "Stablecoins"
            NONE -> null
        }
}
