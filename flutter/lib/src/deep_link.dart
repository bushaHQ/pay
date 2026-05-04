import 'package:flutter/foundation.dart';

import '../busha_pay_config.dart';
import 'sdk.dart';

/// Returns the Busha app's URL scheme for [env] on the current target
/// platform. Reads `defaultTargetPlatform` so tests can override via
/// `debugDefaultTargetPlatformOverride`.
String? bushaAppScheme(BushaEnvironment env) {
  final dev = env == BushaEnvironment.sandbox;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return dev ? 'co.busha.boro.development' : 'co.busha.apple';
    case TargetPlatform.android:
      return dev ? 'co.busha.android.development' : 'co.busha.android';
    default:
      return null;
  }
}

/// Builds the Busha app deep link, returning null if [scheme] is null
/// (unsupported platform). `config.reference` is included only when set.
Uri? buildBushaAppDeepLink({
  required String? scheme,
  required BushaPayConfig config,
  required String publicKey,
  required String callbackUrl,
}) {
  if (scheme == null) return null;
  return Uri(
    scheme: scheme,
    host: 'busha.co',
    path: '/pay',
    queryParameters: {
      'public_key': publicKey,
      'quote_amount': config.quoteAmount,
      'quote_currency': config.quoteCurrency,
      'target_currency': config.targetCurrency,
      'reference': ?config.reference,
      'callback_url': callbackUrl,
    },
  );
}
