import 'package:busha_pay/busha_pay_config.dart';
import 'package:busha_pay/busha_pay_result.dart';
import 'package:busha_pay/src/sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _config = BushaPayConfig(
  quoteAmount: '10000',
  quoteCurrency: 'NGN',
  targetCurrency: 'NGN',
  sourceCurrency: 'USDT',
);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'busha_pay_test',
      packageName: 'co.example.testapp',
      version: '0.0.1',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(BushaPay.resetForTesting);
  tearDown(BushaPay.resetForTesting);

  group('init', () {
    test('marks the SDK as initialized', () async {
      expect(BushaPay.isInitialized, isFalse);
      await BushaPay.init(publicKey: 'pub_x');
      expect(BushaPay.isInitialized, isTrue);
      expect(BushaPay.publicKey, 'pub_x');
    });

    test('defaults to live environment', () async {
      await BushaPay.init(publicKey: 'pub_x');
      expect(BushaPay.isDevMode, isFalse);
      expect(BushaPay.checkoutUrl, 'https://pay.busha.io/pay');
      expect(BushaPay.platformUrl, 'https://api.busha.io');
    });

    test('respects sandbox environment', () async {
      await BushaPay.init(publicKey: 'pub_sb', environment: BushaEnvironment.sandbox);
      expect(BushaPay.isDevMode, isTrue);
      expect(BushaPay.checkoutUrl, 'https://staging.pay.busha.io/pay');
      expect(BushaPay.platformUrl, 'https://api.sandbox.busha.so');
    });

    test('derives callbackScheme + callbackUrl from package name', () async {
      await BushaPay.init(publicKey: 'pub_x');
      expect(BushaPay.callbackScheme, 'co.example.testapp.busha-pay');
      expect(BushaPay.callbackUrl, 'co.example.testapp.busha-pay://callback');
    });
  });

  group('handleDeepLink', () {
    test('returns false for URLs that are not callbacks', () async {
      await BushaPay.init(publicKey: 'pub_x');
      expect(BushaPay.handleDeepLink(Uri.parse('https://example.com/foo')), isFalse);
      expect(BushaPay.handleDeepLink(Uri.parse('co.example.testapp.busha-pay://other')), isFalse);
    });

    test('returns true and dispatches to the registered handler', () async {
      await BushaPay.init(publicKey: 'pub_x');
      Uri? captured;
      BushaPay.registerCallbackHandler((uri) => captured = uri);
      final url = Uri.parse('co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_1');
      expect(BushaPay.handleDeepLink(url), isTrue);
      expect(captured, isNotNull);
      expect(captured!.queryParameters['paymentRequestId'], 'PAYR_1');
    });

    test('returns true even when no handler is registered', () async {
      await BushaPay.init(publicKey: 'pub_x');
      final url = Uri.parse('co.example.testapp.busha-pay://callback?status=cancelled');
      expect(BushaPay.handleDeepLink(url), isTrue);
    });

    test('unregister removes the handler', () async {
      await BushaPay.init(publicKey: 'pub_x');
      var calls = 0;
      BushaPay.registerCallbackHandler((_) => calls++);
      BushaPay.unregisterCallbackHandler();
      BushaPay.handleDeepLink(Uri.parse('co.example.testapp.busha-pay://callback?status=completed'));
      expect(calls, 0);
    });
  });

  group('checkout', () {
    testWidgets('returns CHECKOUT_IN_PROGRESS when invoked again before the first resolves', (tester) async {
      await BushaPay.init(publicKey: 'pub_x');

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      BushaPayResult? second;
      BushaPay.checkout(context: capturedContext, config: _config, onComplete: (_) {});
      await tester.pump();
      BushaPay.checkout(context: capturedContext, config: _config, onComplete: (r) => second = r);
      await tester.pump();

      expect(second, isA<BushaPayError>());
      expect((second! as BushaPayError).code, 'CHECKOUT_IN_PROGRESS');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });
  });
}
