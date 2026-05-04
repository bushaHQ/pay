import 'dart:convert';

import 'package:busha_pay/busha_pay_config.dart';
import 'package:busha_pay/busha_pay_result.dart';
import 'package:busha_pay/src/sdk.dart';
import 'package:busha_pay/src/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _config = BushaPayConfig(
  quoteAmount: '10000',
  quoteCurrency: 'NGN',
  targetCurrency: 'NGN',
  sourceCurrency: 'USDT',
);

const _packageName = 'co.example.testapp';
const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

class _MockWebViewPlatform extends Mock with MockPlatformInterfaceMixin implements InAppWebViewPlatform {}

class _MockPlatformWidget extends Mock with MockPlatformInterfaceMixin implements PlatformInAppWebViewWidget {}

class _MockController extends Mock implements InAppWebViewController {}

class _MockNavigationAction extends Mock implements NavigationAction {}

class _MockCreateWindowRequest extends Mock implements CreateWindowAction {}

class _FakeParams extends Fake implements PlatformInAppWebViewWidgetCreationParams {}

class _FakeBuildContext extends Fake implements BuildContext {}

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
          launched.add((args['url'] as String?) ?? '');
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

void main() {
  late _MockWebViewPlatform platform;
  late _MockPlatformWidget platformWidget;
  late _UrlLauncherFake urlLauncher;
  PlatformInAppWebViewWidgetCreationParams? capturedParams;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'busha_pay_test',
      packageName: _packageName,
      version: '0.0.1',
      buildNumber: '1',
      buildSignature: '',
    );
    registerFallbackValue(URLRequest(url: WebUri('about:blank')));
    registerFallbackValue(_MockNavigationAction());
    registerFallbackValue(_MockCreateWindowRequest());
    registerFallbackValue(_FakeParams());
    registerFallbackValue(_FakeBuildContext());
  });

  setUp(() async {
    BushaPay.resetForTesting();
    await BushaPay.init(publicKey: 'pub_x');

    rootBundle.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      final bytes = const Utf8Encoder().convert('<html><body></body></html>');
      return ByteData.sublistView(bytes);
    });

    platform = _MockWebViewPlatform();
    platformWidget = _MockPlatformWidget();
    capturedParams = null;

    when(() => platform.createPlatformInAppWebViewWidget(any())).thenAnswer((invocation) {
      capturedParams = invocation.positionalArguments.first as PlatformInAppWebViewWidgetCreationParams;
      return platformWidget;
    });
    when(() => platformWidget.build(any())).thenReturn(const SizedBox.shrink());
    when(() => platformWidget.dispose()).thenAnswer((_) async {});

    InAppWebViewPlatform.instance = platform;

    urlLauncher = _UrlLauncherFake()..install();
  });

  tearDown(() {
    urlLauncher.uninstall();
    BushaPay.resetForTesting();
  });

  Future<void> pumpSheet(WidgetTester tester, {PugPayAutoSelect autoSelect = PugPayAutoSelect.none}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BushaPaySheet(config: _config, autoSelect: autoSelect),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the InAppWebView once HTML is loaded', (tester) async {
    await pumpSheet(tester);
    verify(() => platform.createPlatformInAppWebViewWidget(any())).called(1);
  });

  testWidgets('first onLoadStop submits the checkout form', (tester) async {
    await pumpSheet(tester);
    final params = capturedParams;
    final controller = _MockController();
    when(() => controller.evaluateJavascript(source: any(named: 'source'))).thenAnswer((_) async => null);

    params?.onWebViewCreated?.call(controller);
    params?.onLoadStop?.call(controller, WebUri('about:blank'));

    final captured = verify(() => controller.evaluateJavascript(source: captureAny(named: 'source'))).captured;
    expect(captured, hasLength(1));
    final js = captured.first as String;
    expect(js, startsWith('initCheckout('));
    expect(js, contains('public_key'));
    expect(js, contains('quote_amount'));
  });

  testWidgets('second onLoadStop injects the auto-select script for stablecoins', (tester) async {
    await pumpSheet(tester, autoSelect: PugPayAutoSelect.stablecoins);
    final params = capturedParams;
    final controller = _MockController();
    when(() => controller.evaluateJavascript(source: any(named: 'source'))).thenAnswer((_) async => null);

    params?.onWebViewCreated?.call(controller);
    params?.onLoadStop?.call(controller, WebUri('about:blank')); // submit
    params?.onLoadStop?.call(controller, WebUri('about:blank')); // auto-select

    final captured = verify(() => controller.evaluateJavascript(source: captureAny(named: 'source'))).captured;
    expect(captured, hasLength(2));
    expect(captured.last, contains("__bushaPayAutoSelectDone"));
    expect(captured.last, contains('"Stablecoins"'));
  });

  testWidgets('onLoadStop with autoSelect=none skips the auto-select injection', (tester) async {
    await pumpSheet(tester);
    final params = capturedParams;
    final controller = _MockController();
    when(() => controller.evaluateJavascript(source: any(named: 'source'))).thenAnswer((_) async => null);

    params?.onWebViewCreated?.call(controller);
    params?.onLoadStop?.call(controller, WebUri('about:blank')); // submit
    params?.onLoadStop?.call(controller, WebUri('about:blank')); // would auto-select but no-op

    verify(() => controller.evaluateJavascript(source: any(named: 'source'))).called(1);
  });

  testWidgets('shouldOverrideUrlLoading allows http schemes and blocks non-web schemes', (tester) async {
    await pumpSheet(tester);
    final params = capturedParams;
    final controller = _MockController();

    final webAction = _MockNavigationAction();
    when(() => webAction.request).thenReturn(URLRequest(url: WebUri('https://pay.busha.co/foo')));
    final webPolicy = await params?.shouldOverrideUrlLoading?.call(controller, webAction);
    expect(webPolicy, NavigationActionPolicy.ALLOW);

    urlLauncher.canLaunchAnswer = true;
    final extAction = _MockNavigationAction();
    when(() => extAction.request).thenReturn(URLRequest(url: WebUri('mailto:hi@example.com')));
    final extPolicy = await params?.shouldOverrideUrlLoading?.call(controller, extAction);
    expect(extPolicy, NavigationActionPolicy.CANCEL);
    expect(urlLauncher.launched, contains('mailto:hi@example.com'));
  });

  testWidgets('onCreateWindow returns true and launches non-web URIs externally', (tester) async {
    await pumpSheet(tester);
    final params = capturedParams;
    final controller = _MockController();
    urlLauncher.canLaunchAnswer = true;

    final req = _MockCreateWindowRequest();
    when(() => req.request).thenReturn(URLRequest(url: WebUri('intent://example.com')));
    final handled = await params?.onCreateWindow?.call(controller, req);
    expect(handled, isTrue);
    expect(urlLauncher.launched, contains('intent://example.com'));
  });

  testWidgets('the JavaScriptHandler pops the sheet with the bridged result', (tester) async {
    Future<BushaPayResult?>? routeFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  routeFuture = Navigator.of(ctx).push<BushaPayResult>(
                    MaterialPageRoute<BushaPayResult>(builder: (_) => const BushaPaySheet(config: _config)),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    final params = capturedParams;
    final controller = _MockController();
    final handlers = <String, JavaScriptHandlerCallback>{};
    when(
      () => controller.addJavaScriptHandler(
        handlerName: any(named: 'handlerName'),
        callback: any(named: 'callback'),
      ),
    ).thenAnswer((invocation) {
      handlers[invocation.namedArguments[#handlerName] as String] =
          invocation.namedArguments[#callback] as JavaScriptHandlerCallback;
    });

    params?.onWebViewCreated?.call(controller);
    expect(handlers.keys, contains('BushaPayBridge'));

    handlers['BushaPayBridge']?.call(['{"type":"success","data":{"id":"PAYR_42","status":"completed"}}']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final result = await routeFuture!;
    expect(result, isA<BushaPaySuccess>());
    expect((result! as BushaPaySuccess).paymentId, 'PAYR_42');
    expect(find.byType(BushaPaySheet), findsNothing);
  });
}
