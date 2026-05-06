import 'package:busha_pay/busha_pay_config.dart';
import 'package:busha_pay/busha_pay_result.dart';
import 'package:busha_pay/src/chooser.dart' show PaymentMethod;
import 'package:busha_pay/src/sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _config = BushaPayConfig(
  quoteAmount: '10000',
  quoteCurrency: 'NGN',
  targetCurrency: 'NGN',
  sourceCurrency: 'USDT',
);

const _packageName = 'co.example.testapp';
const _callbackScheme = '$_packageName.busha-pay';
const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

class _UrlLauncherFake {
  bool canLaunchAnswer = false;
  final List<String> launched = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_urlLauncherChannel, (
      call,
    ) async {
      switch (call.method) {
        case 'canLaunch':
          return canLaunchAnswer;
        case 'launch':
        case 'launchUrl':
          final args = call.arguments as Map<Object?, Object?>? ?? const {};
          final url = (args['url'] as String?) ?? '';
          launched.add(url);
          return true;
      }
      return null;
    });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _urlLauncherChannel,
      null,
    );
  }
}

Future<void> _openCheckout(
  WidgetTester tester,
  void Function(BushaPayResult) onResult, {
  BushaPayConfig config = _config,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => BushaPay.checkout(context: ctx, config: config, onComplete: onResult),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late _UrlLauncherFake urlLauncher;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'busha_pay_test',
      packageName: _packageName,
      version: '0.0.1',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() async {
    BushaPay.resetForTesting();
    await BushaPay.init(publicKey: 'pub_x');
    BushaPay.skipSheetHtmlLoadForTesting = true;
    BushaPay.merchantNameLoaderForTesting = (_) async => null;
    urlLauncher = _UrlLauncherFake()..install();
  });

  tearDown(() {
    urlLauncher.uninstall();
    BushaPay.resetForTesting();
  });

  testWidgets('dismissing the chooser delivers BushaPayCancelled', (tester) async {
    BushaPayResult? result;
    await _openCheckout(tester, (r) => result = r);

    expect(find.text('Choose a payment method'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, isA<BushaPayCancelled>());
  });

  testWidgets('Stablecoins → sheet opens → deep-link callback resolves to BushaPaySuccess', (tester) async {
    BushaPayResult? result;
    await _openCheckout(tester, (r) => result = r);

    await tester.tap(find.text('Stablecoins'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsLabel('Loading payment options'), findsOneWidget);

    final uri = Uri.parse('$_callbackScheme://callback?status=completed&paymentRequestId=PAYR_99');
    expect(BushaPay.handleDeepLink(uri), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, isA<BushaPaySuccess>());
    expect((result! as BushaPaySuccess).paymentId, 'PAYR_99');
  });

  testWidgets('Busha + canLaunchUrl=false → falls through to web sheet', (tester) async {
    urlLauncher.canLaunchAnswer = false;
    BushaPayResult? result;
    await _openCheckout(tester, (r) => result = r);

    await tester.tap(find.text('Busha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(urlLauncher.launched, isEmpty);
    expect(find.bySemanticsLabel('Loading payment options'), findsOneWidget);

    final uri = Uri.parse('$_callbackScheme://callback?status=cancelled');
    BushaPay.handleDeepLink(uri);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(result, isA<BushaPayError>());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'Busha + canLaunchUrl=true → launchUrl called → deep-link callback resolves to BushaPaySuccess',
    (tester) async {
      urlLauncher.canLaunchAnswer = true;
      BushaPayResult? result;
      await _openCheckout(tester, (r) => result = r);

      await tester.tap(find.text('Busha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(urlLauncher.launched, hasLength(1));
      final launched = Uri.parse(urlLauncher.launched.first);
      expect(launched.host, 'busha.co');
      expect(launched.path, '/pay');
      expect(launched.queryParameters['public_key'], 'pub_x');
      expect(launched.queryParameters['quote_amount'], '10000');

      final uri = Uri.parse('$_callbackScheme://callback?status=completed&paymentRequestId=PAYR_BA1');
      expect(BushaPay.handleDeepLink(uri), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isA<BushaPaySuccess>());
      expect((result! as BushaPaySuccess).paymentId, 'PAYR_BA1');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Busha launch + cancelled callback resolves to BushaPayCancelled',
    (tester) async {
      urlLauncher.canLaunchAnswer = true;
      BushaPayResult? result;
      await _openCheckout(tester, (r) => result = r);

      await tester.tap(find.text('Busha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final uri = Uri.parse('$_callbackScheme://callback?status=cancelled');
      expect(BushaPay.handleDeepLink(uri), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isA<BushaPayCancelled>());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Busha launch + error callback uses error_message and error_code from query',
    (tester) async {
      urlLauncher.canLaunchAnswer = true;
      BushaPayResult? result;
      await _openCheckout(tester, (r) => result = r);

      await tester.tap(find.text('Busha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final uri = Uri.parse('$_callbackScheme://callback?status=failed&error_code=NET_DOWN&error_message=No%20signal');
      expect(BushaPay.handleDeepLink(uri), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isA<BushaPayError>());
      final err = result! as BushaPayError;
      expect(err.code, 'NET_DOWN');
      expect(err.message, 'No signal');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Busha launch + resume without callback within 1.5s resolves to BushaPayCancelled',
    (tester) async {
      urlLauncher.canLaunchAnswer = true;
      BushaPayResult? result;
      await _openCheckout(tester, (r) => result = r);

      await tester.tap(find.text('Busha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1600));

      expect(result, isA<BushaPayCancelled>());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('allowedPaymentMethods=[stablecoins] skips the chooser and opens the web sheet', (tester) async {
    const config = BushaPayConfig(
      quoteAmount: '10000',
      quoteCurrency: 'NGN',
      targetCurrency: 'NGN',
      sourceCurrency: 'USDT',
      allowedPaymentMethods: [PaymentMethod.stablecoins],
    );
    BushaPayResult? result;
    await _openCheckout(tester, (r) => result = r, config: config);

    expect(find.text('Choose a payment method'), findsNothing);
    expect(find.bySemanticsLabel('Loading payment options'), findsOneWidget);

    final uri = Uri.parse('$_callbackScheme://callback?status=completed&paymentRequestId=PAYR_SC');
    expect(BushaPay.handleDeepLink(uri), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, isA<BushaPaySuccess>());
  });

  testWidgets(
    'allowedPaymentMethods=[bushaApp] skips the chooser and deep-links into the Busha app',
    (tester) async {
      urlLauncher.canLaunchAnswer = true;
      const config = BushaPayConfig(
        quoteAmount: '10000',
        quoteCurrency: 'NGN',
        targetCurrency: 'NGN',
        sourceCurrency: 'USDT',
        allowedPaymentMethods: [PaymentMethod.bushaApp],
      );
      BushaPayResult? result;
      await _openCheckout(tester, (r) => result = r, config: config);

      expect(find.text('Choose a payment method'), findsNothing);
      expect(urlLauncher.launched, hasLength(1));

      final uri = Uri.parse('$_callbackScheme://callback?status=completed&paymentRequestId=PAYR_APP');
      expect(BushaPay.handleDeepLink(uri), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isA<BushaPaySuccess>());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'allowedPaymentMethods=[bushaApp] with app not installed falls through to the web sheet',
    (tester) async {
      urlLauncher.canLaunchAnswer = false;
      const config = BushaPayConfig(
        quoteAmount: '10000',
        quoteCurrency: 'NGN',
        targetCurrency: 'NGN',
        sourceCurrency: 'USDT',
        allowedPaymentMethods: [PaymentMethod.bushaApp],
      );
      BushaPayResult? result;
      await _openCheckout(tester, (r) => result = r, config: config);

      expect(find.text('Choose a payment method'), findsNothing);
      expect(urlLauncher.launched, isEmpty);
      expect(find.bySemanticsLabel('Loading payment options'), findsOneWidget);

      final uri = Uri.parse('$_callbackScheme://callback?status=completed&paymentRequestId=PAYR_FB');
      expect(BushaPay.handleDeepLink(uri), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isA<BushaPaySuccess>());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('allowedPaymentMethods with both methods still shows the chooser', (tester) async {
    const config = BushaPayConfig(
      quoteAmount: '10000',
      quoteCurrency: 'NGN',
      targetCurrency: 'NGN',
      sourceCurrency: 'USDT',
      allowedPaymentMethods: [PaymentMethod.bushaApp, PaymentMethod.stablecoins],
    );
    BushaPayResult? result;
    await _openCheckout(tester, (r) => result = r, config: config);

    expect(find.text('Choose a payment method'), findsOneWidget);
    expect(find.text('Busha'), findsOneWidget);
    expect(find.text('Stablecoins'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(result, isA<BushaPayCancelled>());
  });

  testWidgets('a second checkout while the first is in flight returns CHECKOUT_IN_PROGRESS', (tester) async {
    BushaPayResult? second;
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

    BushaPay.checkout(context: capturedContext, config: _config, onComplete: (_) {});
    await tester.pump();
    BushaPay.checkout(context: capturedContext, config: _config, onComplete: (r) => second = r);
    await tester.pump();

    expect(second, isA<BushaPayError>());
    expect((second! as BushaPayError).code, 'CHECKOUT_IN_PROGRESS');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
