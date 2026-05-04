import 'package:busha_pay/busha_pay_config.dart';
import 'package:busha_pay/src/deep_link.dart';
import 'package:busha_pay/src/sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = BushaPayConfig(
  quoteAmount: '10000',
  quoteCurrency: 'NGN',
  targetCurrency: 'NGN',
  sourceCurrency: 'USDT',
);

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('bushaAppScheme', () {
    test('iOS live → co.busha.apple', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(bushaAppScheme(BushaEnvironment.live), 'co.busha.apple');
    });

    test('iOS sandbox → co.busha.boro.development', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(bushaAppScheme(BushaEnvironment.sandbox), 'co.busha.boro.development');
    });

    test('Android live → co.busha.android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(bushaAppScheme(BushaEnvironment.live), 'co.busha.android');
    });

    test('Android sandbox → co.busha.android.development', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(bushaAppScheme(BushaEnvironment.sandbox), 'co.busha.android.development');
    });

    test('macOS / unsupported → null', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(bushaAppScheme(BushaEnvironment.live), isNull);
    });
  });

  group('buildBushaAppDeepLink', () {
    test('returns null when scheme is null', () {
      final uri = buildBushaAppDeepLink(scheme: null, config: _config, publicKey: 'pk', callbackUrl: 'cb://cb');
      expect(uri, isNull);
    });

    test('builds the Uri host + path', () {
      final uri = buildBushaAppDeepLink(
        scheme: 'co.busha.apple',
        config: _config,
        publicKey: 'pub_test',
        callbackUrl: 'co.example.busha-pay://callback',
      )!;
      expect(uri.scheme, 'co.busha.apple');
      expect(uri.host, 'busha.co');
      expect(uri.path, '/pay');
    });

    test('embeds the required query parameters', () {
      final uri = buildBushaAppDeepLink(
        scheme: 'co.busha.android',
        config: _config,
        publicKey: 'pub_test',
        callbackUrl: 'co.example.busha-pay://callback',
      )!;
      expect(uri.queryParameters['public_key'], 'pub_test');
      expect(uri.queryParameters['quote_amount'], '10000');
      expect(uri.queryParameters['quote_currency'], 'NGN');
      expect(uri.queryParameters['target_currency'], 'NGN');
      expect(uri.queryParameters['callback_url'], 'co.example.busha-pay://callback');
    });

    test('omits reference when not provided', () {
      final uri = buildBushaAppDeepLink(
        scheme: 'co.busha.apple',
        config: _config,
        publicKey: 'pk',
        callbackUrl: 'cb://cb',
      )!;
      expect(uri.queryParameters.containsKey('reference'), isFalse);
    });

    test('includes reference when provided', () {
      const c = BushaPayConfig(
        quoteAmount: '10000',
        quoteCurrency: 'NGN',
        targetCurrency: 'NGN',
        sourceCurrency: 'USDT',
        reference: 'ref-1',
      );
      final uri = buildBushaAppDeepLink(scheme: 'co.busha.apple', config: c, publicKey: 'pk', callbackUrl: 'cb://cb')!;
      expect(uri.queryParameters['reference'], 'ref-1');
    });
  });
}
