import Foundation

/// Payment methods Busha Pay can route through.
///
/// Used both as the chooser result and, on
/// ``BushaPayConfig/allowedPaymentMethods``, as the merchant-side knob for
/// restricting which tiles the chooser shows (or whether the chooser is
/// shown at all).
public enum PaymentMethod: String, Sendable, CaseIterable {
    /// Pay from a Busha account via the Busha mobile app
    /// (with web fallback when the app isn't installed).
    case bushaApp

    /// Pay from an external wallet via the stablecoin web checkout.
    case stablecoins
}
