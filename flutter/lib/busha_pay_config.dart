/// Configuration for a Busha Pay checkout session.
class BushaPayConfig {
  /// Amount to charge (e.g., '10000').
  final String quoteAmount;

  /// Currency for the quoted amount (e.g., 'NGN', 'USD').
  final String quoteCurrency;

  /// Currency the payment settles into (e.g., 'NGN', 'USD').
  final String targetCurrency;

  /// Asset the customer pays with (e.g., 'USDT', 'BTC').
  final String sourceCurrency;

  /// Your custom transaction reference. Auto-generated if not provided.
  final String? reference;

  /// Customer or order name shown in the checkout.
  final String? metaName;

  /// Customer email for order context.
  final String? metaEmail;

  /// Customer phone number.
  final String? metaPhone;

  const BushaPayConfig({
    required this.quoteAmount,
    required this.quoteCurrency,
    required this.targetCurrency,
    required this.sourceCurrency,
    this.reference,
    this.metaName,
    this.metaEmail,
    this.metaPhone,
  });

  /// Creates a copy with the given fields replaced.
  BushaPayConfig copyWith({
    String? quoteAmount,
    String? quoteCurrency,
    String? targetCurrency,
    String? sourceCurrency,
    String? reference,
    String? metaName,
    String? metaEmail,
    String? metaPhone,
  }) => BushaPayConfig(
    quoteAmount: quoteAmount ?? this.quoteAmount,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    targetCurrency: targetCurrency ?? this.targetCurrency,
    sourceCurrency: sourceCurrency ?? this.sourceCurrency,
    reference: reference ?? this.reference,
    metaName: metaName ?? this.metaName,
    metaEmail: metaEmail ?? this.metaEmail,
    metaPhone: metaPhone ?? this.metaPhone,
  );

  /// Converts to the JSON shape expected by commerce-js.
  Map<String, dynamic> toCommerceJson({
    required String publicKey,
    required bool devMode,
    required String callbackUrl,
  }) => {
    'public_key': publicKey,
    'quote_amount': quoteAmount,
    'quote_currency': quoteCurrency,
    'target_currency': targetCurrency,
    'source_currency': sourceCurrency,
    'reference': ?reference,
    'devMode': devMode,
    'callback_url': callbackUrl,
    'meta': {'name': ?metaName, 'email': ?metaEmail, 'phone_number': ?metaPhone},
  };

  /// Converts to a map of form fields for direct POST to the checkout page.
  Map<String, String> toFormFields({
    required String publicKey,
    required String callbackUrl,
    required String checkoutUrl,
  }) => {
    'public_key': publicKey,
    'quote_amount': quoteAmount,
    'quote_currency': quoteCurrency,
    'target_currency': targetCurrency,
    'source_currency': sourceCurrency,
    'callback_url': callbackUrl,
    'displayMode': 'INLINE',
    'parentOrigin': Uri.parse(checkoutUrl).origin,
    'reference': ?reference,
    'meta[name]': ?metaName,
    'meta[email]': ?metaEmail,
    'meta[phone_number]': ?metaPhone,
  };
}
