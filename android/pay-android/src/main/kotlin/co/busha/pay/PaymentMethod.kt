package co.busha.pay

/** Payment methods Busha Pay can route through. */
enum class PaymentMethod {
    /**
     * Pay from a Busha account via the Busha mobile app (with web
     * fallback when the app isn't installed).
     */
    BUSHA_APP,

    /** Pay from an external wallet via the stablecoin web checkout. */
    STABLECOINS,
}
