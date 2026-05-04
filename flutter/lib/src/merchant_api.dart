import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sdk.dart';

/// Resolves the merchant's display name for a given public key.
///
/// Hits `GET <platform>/v1/merchants` with `X-BU-PUBLIC-KEY` and reads
/// `data.username` from the response.
///
/// Returns `null` on any failure (network error, non-2xx, missing
/// field) so callers can omit the merchant line silently.
Future<String?> fetchMerchantName(String publicKey, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final response = await c
        .get(Uri.parse('${BushaPay.platformUrl}/v1/merchants'), headers: {'X-BU-PUBLIC-KEY': publicKey})
        .timeout(const Duration(seconds: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return switch (jsonDecode(response.body)) {
      {'data': {'username': final String name}} when name.isNotEmpty => name,
      _ => null,
    };
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}
