/// Payment methods Busha Pay can route through.
enum PaymentMethod {
  /// Pay from a Busha account via the Busha mobile app (with web fallback
  /// when the app isn't installed).
  bushaApp,

  /// Pay from an external wallet via the stablecoin web checkout.
  stablecoins,
}
