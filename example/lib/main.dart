import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:busha_pay/busha_pay.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BushaPay.init(
    publicKey: const String.fromEnvironment('BUSHA_PUBLIC_KEY'),
    environment: BushaEnvironment.sandbox,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen(BushaPay.handleDeepLink);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Busha Pay Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C853)),
        useMaterial3: true,
      ),
      home: const CheckoutPage(),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product info
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Macbook Pro 2025 13"',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '₦10,000',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Status
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _status.contains('Success')
                        ? Colors.green
                        : _status.contains('Error')
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
              ),

            // Option 1: Branded button
            BushaPayButton(
              config: const BushaPayConfig(
                quoteAmount: '10000',
                quoteCurrency: 'NGN',
                targetCurrency: 'NGN',
                sourceCurrency: 'USDT',
                metaName: 'Test Customer',
                metaEmail: 'test@example.com',
              ),
              onComplete: _handleResult,
            ),

            const SizedBox(height: 12),

            // Option 2: Outlined style
            BushaPayButton(
              config: const BushaPayConfig(
                quoteAmount: '10000',
                quoteCurrency: 'NGN',
                targetCurrency: 'NGN',
                sourceCurrency: 'USDT',
                metaName: 'Test Customer',
                metaEmail: 'test@example.com',
              ),
              style: BushaPayButtonStyle.outlined,
              onComplete: _handleResult,
            ),

            const SizedBox(height: 12),

            // Option 3: Headless (custom button)
            ElevatedButton(
              onPressed: () => BushaPay.checkout(
                context: context,
                config: const BushaPayConfig(
                  quoteAmount: '200000',
                  quoteCurrency: 'NGN',
                  targetCurrency: 'USDT',
                  sourceCurrency: 'BTC',
                  metaName: 'Test Customer',
                  metaEmail: 'test@example.com',
                ),
                onComplete: _handleResult,
              ),
              child: const Text('Custom Pay Button'),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _handleResult(BushaPayResult result) {
    setState(() {
      _status = switch (result) {
        BushaPaySuccess(:final paymentId, :final hasFullData) =>
          '✅ Success! Payment ID: $paymentId (full data: $hasFullData)',
        BushaPayCancelled() => '⚠️ Cancelled by user',
        BushaPayError(:final message) => '❌ Error: $message',
      };
    });
  }
}
