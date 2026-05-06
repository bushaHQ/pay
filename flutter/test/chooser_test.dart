import 'dart:async';

import 'package:busha_pay/busha_pay_config.dart';
import 'package:busha_pay/src/chooser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = BushaPayConfig(
  quoteAmount: '10000',
  quoteCurrency: 'NGN',
  targetCurrency: 'NGN',
  sourceCurrency: 'USDT',
);

/// Builds the chooser harness, taps "open", and pumps just enough to render
/// the dialog. Returns the completer that resolves when the dialog dismisses
/// — callers `await` it *after* simulating the user's tap, never before.
Future<Completer<PaymentMethod?>> _showChooser(
  WidgetTester tester, {
  Future<String?> Function()? loader,
  BushaPayConfig config = _config,
  List<PaymentMethod>? allowedPaymentMethods,
}) async {
  final completer = Completer<PaymentMethod?>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final choice = await showDialog<PaymentMethod>(
                  context: ctx,
                  builder: (_) => PaymentMethodChooser(
                    config: config,
                    allowedPaymentMethods: allowedPaymentMethods,
                    merchantNameLoader: loader ?? () async => null,
                  ),
                );
                completer.complete(choice);
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
  return completer;
}

void main() {
  testWidgets('renders amount, heading, both tiles, and Secured by footer', (tester) async {
    await _showChooser(tester);
    expect(find.text('Pay 10,000 NGN'), findsOneWidget);
    expect(find.text('Choose a payment method'), findsOneWidget);
    expect(find.text('Busha'), findsOneWidget);
    expect(find.text('Stablecoins'), findsOneWidget);
    expect(find.text('Make payment directly from your busha account'), findsOneWidget);
    expect(find.text('Make payment from an external wallet'), findsOneWidget);
    expect(find.text('Secured by'), findsOneWidget);
  });

  testWidgets('formats decimal amounts with two decimals and grouping', (tester) async {
    await _showChooser(
      tester,
      config: const BushaPayConfig(
        quoteAmount: '12345.5',
        quoteCurrency: 'USD',
        targetCurrency: 'NGN',
        sourceCurrency: 'USDT',
      ),
    );
    expect(find.text('Pay 12,345.50 USD'), findsOneWidget);
  });

  testWidgets('falls back to the raw amount string when not parseable', (tester) async {
    await _showChooser(
      tester,
      config: const BushaPayConfig(
        quoteAmount: 'abc',
        quoteCurrency: 'XYZ',
        targetCurrency: 'NGN',
        sourceCurrency: 'USDT',
      ),
    );
    expect(find.text('Pay abc XYZ'), findsOneWidget);
  });

  testWidgets('omits the merchant line by default', (tester) async {
    await _showChooser(tester);
    expect(find.textContaining('To '), findsNothing);
  });

  testWidgets('renders the merchant line once the loader resolves with a name', (tester) async {
    await _showChooser(tester, loader: () async => 'Pushup Design Agency');
    expect(find.text('To Pushup Design Agency'), findsOneWidget);
  });

  testWidgets('tapping Busha pops with PaymentMethod.bushaApp', (tester) async {
    final completer = await _showChooser(tester);
    await tester.tap(find.text('Busha'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await completer.future, PaymentMethod.bushaApp);
  });

  testWidgets('tapping Stablecoins pops with PaymentMethod.stablecoins', (tester) async {
    final completer = await _showChooser(tester);
    await tester.tap(find.text('Stablecoins'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await completer.future, PaymentMethod.stablecoins);
  });

  testWidgets('tapping the close icon pops with null', (tester) async {
    final completer = await _showChooser(tester);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await completer.future, isNull);
  });

  testWidgets('shows all tiles when allowedPaymentMethods is null', (tester) async {
    await _showChooser(tester);
    expect(find.text('Busha'), findsOneWidget);
    expect(find.text('Stablecoins'), findsOneWidget);
  });

  testWidgets('shows all tiles when allowedPaymentMethods is empty', (tester) async {
    await _showChooser(tester, allowedPaymentMethods: const []);
    expect(find.text('Busha'), findsOneWidget);
    expect(find.text('Stablecoins'), findsOneWidget);
  });

  testWidgets('hides Stablecoins when only bushaApp is allowed', (tester) async {
    await _showChooser(tester, allowedPaymentMethods: const [PaymentMethod.bushaApp]);
    expect(find.text('Busha'), findsOneWidget);
    expect(find.text('Stablecoins'), findsNothing);
  });

  testWidgets('hides Busha when only stablecoins is allowed', (tester) async {
    await _showChooser(tester, allowedPaymentMethods: const [PaymentMethod.stablecoins]);
    expect(find.text('Busha'), findsNothing);
    expect(find.text('Stablecoins'), findsOneWidget);
  });
}
