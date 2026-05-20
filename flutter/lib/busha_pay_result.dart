/// Result of a Busha Pay checkout.
///
/// Use pattern matching to handle each case:
/// ```dart
/// switch (result) {
///   case BushaPaySuccess(:final paymentId):
///     print('Payment $paymentId completed');
///   case BushaPayCancelled():
///     print('User cancelled');
///   case BushaPayError(:final message):
///     print('Error: $message');
/// }
/// ```
sealed class BushaPayResult {
  const BushaPayResult();
}

/// Payment completed successfully.
///
/// Full payment data (amounts, rates, timeline) is available when payment
/// was completed in the web checkout flow. When completed via the Busha app,
/// only [paymentId] and [status] are available.
///
/// Use [hasFullData] to check which fields are populated.
///
/// **Important:** Always verify the payment server-side via webhooks.
/// The client result is a UX hint, not the source of truth.
class BushaPaySuccess extends BushaPayResult {
  /// Payment request ID (e.g., 'PAYR_EhDmpnPwDSjO'). Always present.
  final String paymentId;

  /// Payment status (e.g., 'completed'). Always present.
  final String status;

  // Full data (web checkout flow only)

  /// Amount paid in source currency (e.g., '0.00017798').
  final String? sourceAmount;

  /// Source currency the user paid with (e.g., 'BTC').
  final String? sourceCurrency;

  /// Amount received in target currency (e.g., '13.42').
  final String? targetAmount;

  /// Target settlement currency (e.g., 'USDT').
  final String? targetCurrency;

  /// Originally requested amount.
  final String? requestedAmount;

  /// Currency of the requested amount.
  final String? currency;

  /// Exchange rate details.
  final Map<String, dynamic>? rate;

  /// Merchant information.
  final Map<String, dynamic>? merchantInfo;

  /// Payment timeline with step-by-step events.
  final Map<String, dynamic>? timeline;

  /// Full unmodified response from commerce-js.
  final Map<String, dynamic>? rawData;

  const BushaPaySuccess({
    required this.paymentId,
    required this.status,
    this.sourceAmount,
    this.sourceCurrency,
    this.targetAmount,
    this.targetCurrency,
    this.requestedAmount,
    this.currency,
    this.rate,
    this.merchantInfo,
    this.timeline,
    this.rawData,
  });

  /// Whether full payment data is available.
  ///
  /// `true` when payment completed in the web checkout (Path A).
  /// `false` when payment completed via the Busha app (Path B).
  bool get hasFullData => rawData != null;

  /// Creates a success result from a callback deep link (Path B — limited data).
  factory BushaPaySuccess.fromCallback({required String paymentId}) =>
      BushaPaySuccess(paymentId: paymentId, status: 'completed');

  /// Creates a success result from commerce-js onSuccess data (Path A — full data).
  factory BushaPaySuccess.fromCommerceJs(Map<String, dynamic> payload) {
    final data = payload['data'] as Map<String, dynamic>? ?? payload;

    return BushaPaySuccess(
      paymentId: data['id'] as String? ?? data['reference'] as String? ?? '',
      status: data['status'] as String? ?? 'completed',
      sourceAmount: data['source_amount'] as String?,
      sourceCurrency: data['source_currency'] as String?,
      targetAmount: data['target_amount'] as String?,
      targetCurrency: data['target_currency'] as String?,
      requestedAmount: data['requested_amount'] as String?,
      currency: data['currency'] as String?,
      rate: data['rate'] as Map<String, dynamic>?,
      merchantInfo: data['merchant_info'] as Map<String, dynamic>?,
      timeline: data['timeline'] as Map<String, dynamic>?,
      rawData: payload,
    );
  }

  @override
  String toString() => 'BushaPaySuccess(paymentId: $paymentId, status: $status, hasFullData: $hasFullData)';
}

/// Why a checkout ended without a completed payment.
enum BushaPayCancelledReason {
  /// The user dismissed the in-app chooser or web checkout sheet — close
  /// button, backdrop tap, or drag-to-dismiss.
  dismissed,

  /// The Busha app reported that the user explicitly rejected the payment.
  /// [BushaPayCancelled.paymentId] carries the payment request ID so you
  /// can reconcile server-side.
  rejected,

  /// The user returned to your app from the Busha app without a callback
  /// arriving. The payment outcome is **unverified** — it may still have
  /// succeeded. Always reconcile server-side (webhook / status API)
  /// before showing the user a final state.
  abandoned,
}

/// The checkout ended without a completed payment.
///
/// Inspect [reason] to tell *how* it ended. In particular,
/// [BushaPayCancelledReason.abandoned] does **not** mean the payment
/// failed — only that the SDK never received a result. Verify server-side.
class BushaPayCancelled extends BushaPayResult {
  /// How the checkout ended. Defaults to [BushaPayCancelledReason.dismissed].
  final BushaPayCancelledReason reason;

  /// The payment request ID. Present only when [reason] is
  /// [BushaPayCancelledReason.rejected] — the Busha app hands it back so
  /// the merchant can reconcile the rejected request.
  final String? paymentId;

  const BushaPayCancelled({this.reason = BushaPayCancelledReason.dismissed, this.paymentId});

  @override
  String toString() => 'BushaPayCancelled(reason: ${reason.name}, paymentId: $paymentId)';
}

/// An error occurred during checkout.
class BushaPayError extends BushaPayResult {
  /// Human-readable error message.
  final String message;

  /// Error code, if available.
  final String? code;

  const BushaPayError({required this.message, this.code});

  @override
  String toString() => 'BushaPayError(message: $message, code: $code)';
}
