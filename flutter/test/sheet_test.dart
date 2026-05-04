import 'package:busha_pay/busha_pay_config.dart';
import 'package:busha_pay/busha_pay_result.dart';
import 'package:busha_pay/src/sdk.dart';
import 'package:busha_pay/src/sheet.dart';
import 'package:flutter/material.dart';
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

class _SheetHandle {
  final Future<BushaPayResult?> result;
  _SheetHandle(this.result);
}

Future<_SheetHandle> _showSheet(WidgetTester tester, {PugPayAutoSelect autoSelect = PugPayAutoSelect.none}) async {
  late Future<BushaPayResult?> routeResult;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                routeResult = Navigator.of(ctx).push<BushaPayResult>(
                  MaterialPageRoute<BushaPayResult>(
                    builder: (_) => BushaPaySheet(config: _config, autoSelect: autoSelect, skipHtmlLoad: true),
                  ),
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
  await tester.pump(const Duration(milliseconds: 300));
  return _SheetHandle(routeResult);
}

void main() {
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
  });

  testWidgets('shows the chooser shimmer while HTML is loading', (tester) async {
    await _showSheet(tester);
    expect(find.bySemanticsLabel('Loading payment options'), findsOneWidget);
  });

  testWidgets('completed deep-link callback pops with BushaPaySuccess', (tester) async {
    final handle = await _showSheet(tester);
    final uri = Uri.parse('$_callbackScheme://callback?status=completed&paymentRequestId=PAYR_42');
    expect(BushaPay.handleDeepLink(uri), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final result = await handle.result;
    expect(result, isA<BushaPaySuccess>());
    expect((result! as BushaPaySuccess).paymentId, 'PAYR_42');
  });

  testWidgets('non-completed deep-link callback pops with BushaPayError', (tester) async {
    final handle = await _showSheet(tester);
    final uri = Uri.parse('$_callbackScheme://callback?status=failed');
    expect(BushaPay.handleDeepLink(uri), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final result = await handle.result;
    expect(result, isA<BushaPayError>());
    expect((result! as BushaPayError).code, 'failed');
  });

  testWidgets('unknown-scheme URIs are ignored by the sheet', (tester) async {
    await _showSheet(tester);
    expect(BushaPay.handleDeepLink(Uri.parse('https://example.com')), isFalse);
    expect(find.bySemanticsLabel('Loading payment options'), findsOneWidget);
  });

  group('PugPayAutoSelect', () {
    test('queryParam maps to pug-pay query keys', () {
      expect(PugPayAutoSelect.bushaApp.queryParam, 'busha');
      expect(PugPayAutoSelect.stablecoins.queryParam, 'stablecoins');
      expect(PugPayAutoSelect.none.queryParam, isNull);
    });

    test('rowTextPrefix maps to pug-pay chooser labels', () {
      expect(PugPayAutoSelect.bushaApp.rowTextPrefix, 'Busha');
      expect(PugPayAutoSelect.stablecoins.rowTextPrefix, 'Stablecoins');
      expect(PugPayAutoSelect.none.rowTextPrefix, isNull);
    });
  });
}
