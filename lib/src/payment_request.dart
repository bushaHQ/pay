/// A payment request created server-side via the Busha API.
///
/// Returned by `POST /v1/payments/requests` with the checkout config.
/// The [id] is used as the identifier for the Busha app deep link and as
/// `source_id` when falling back to the web checkout.
class PaymentRequest {
  /// Payment request ID (e.g. `PAYR_lQfpS20oulVs`).
  final String id;

  /// Payment request status (e.g. `pending`).
  final String status;

  /// Amount shown to the user in their local currency.
  final String quoteAmount;

  /// Currency of [quoteAmount] (e.g. `NGN`).
  final String quoteCurrency;

  /// Amount in the settlement currency.
  final String? targetAmount;

  /// Settlement currency (e.g. `USDT`).
  final String? targetCurrency;

  /// Amount in the crypto asset the user pays with.
  final String? sourceAmount;

  /// Crypto asset used for payment (e.g. `BTC`).
  final String? sourceCurrency;

  /// Merchant's display name (e.g. `Adesorph Techologies`).
  final String? merchantName;

  /// Merchant's email.
  final String? merchantEmail;

  /// Full raw JSON payload — useful for anything we don't explicitly parse.
  final Map<String, dynamic> raw;

  const PaymentRequest({
    required this.id,
    required this.status,
    required this.quoteAmount,
    required this.quoteCurrency,
    this.targetAmount,
    this.targetCurrency,
    this.sourceAmount,
    this.sourceCurrency,
    this.merchantName,
    this.merchantEmail,
    required this.raw,
  });

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    final merchantInfo = json['merchant_info'] as Map<String, dynamic>?;
    return PaymentRequest(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'unknown',
      quoteAmount: json['quote_amount']?.toString() ?? '',
      quoteCurrency: json['quote_currency'] as String? ?? '',
      targetAmount: json['target_amount']?.toString(),
      targetCurrency: json['target_currency'] as String?,
      sourceAmount: json['source_amount']?.toString(),
      sourceCurrency: json['source_currency'] as String?,
      merchantName: merchantInfo?['name'] as String?,
      merchantEmail: merchantInfo?['email'] as String?,
      raw: json,
    );
  }
}
