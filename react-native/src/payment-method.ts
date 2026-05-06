/**
 * Payment methods Busha Pay can route through.
 *
 * - `'bushaApp'`: pay from a Busha account via the Busha mobile app (with
 *   web fallback when the app isn't installed).
 * - `'stablecoins'`: pay from an external wallet via the stablecoin web
 *   checkout.
 */
export type PaymentMethod = 'bushaApp' | 'stablecoins';
