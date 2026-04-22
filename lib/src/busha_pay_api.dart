import 'dart:convert';

import 'package:http/http.dart' as http;

import '../busha_pay_config.dart';
import 'payment_request.dart';

/// Internal HTTP client for the Busha API.
class BushaPayApi {
  BushaPayApi._();

  static String _baseUrl({required bool isDev}) =>
      isDev ? 'https://api.sandbox.busha.so' : 'https://api.busha.io';

  /// Creates a payment request via `POST /v1/payments/requests`.
  ///
  /// Authenticates with the merchant's public key via `X-BU-PUBLIC-KEY`.
  /// Returns the created [PaymentRequest]. Throws [BushaPayApiException]
  /// on non-2xx responses or malformed JSON.
  static Future<PaymentRequest> createPaymentRequest({
    required BushaPayConfig config,
    required String publicKey,
    required bool isDev,
  }) async {
    final url = Uri.parse('${_baseUrl(isDev: isDev)}/v1/payments/requests');

    final body = <String, dynamic>{
      'quote_currency': config.quoteCurrency,
      'quote_amount': config.quoteAmount,
      'source_currency': config.sourceCurrency,
      'target_currency': config.targetCurrency,
      'pay_in': {'type': 'balance'},
      if (config.reference != null) 'reference': config.reference,
      'additional_info': {
        if (config.metaName != null) 'name': config.metaName,
        if (config.metaEmail != null) 'email': config.metaEmail,
        if (config.metaPhone != null) 'phone_number': config.metaPhone,
      },
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-BU-PUBLIC-KEY': publicKey,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BushaPayApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw BushaPayApiException(
        statusCode: response.statusCode,
        body: response.body,
        message: 'Invalid JSON in response',
      );
    }

    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw BushaPayApiException(
        statusCode: response.statusCode,
        body: response.body,
        message: 'Response is missing "data" field',
      );
    }

    return PaymentRequest.fromJson(data);
  }
}

class BushaPayApiException implements Exception {
  final int statusCode;
  final String body;
  final String? message;

  BushaPayApiException({
    required this.statusCode,
    required this.body,
    this.message,
  });

  /// Tries to extract a human-readable message from the response body.
  String get displayMessage {
    if (message != null) return message!;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final msg = json['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    } catch (_) {}
    return 'Busha API error $statusCode';
  }

  @override
  String toString() => 'BushaPayApiException($statusCode): $displayMessage';
}
