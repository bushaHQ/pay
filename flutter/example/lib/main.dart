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
      title: 'Busha Store',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C853)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final String price;
  final String currency;
  final String emoji;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.emoji,
  });
}

const _products = <Product>[
  Product(
    id: 'p1',
    name: 'Macbook Pro 13"',
    description: 'Apple M3 chip, 16GB unified memory, 512GB SSD storage.',
    price: '20000',
    currency: 'NGN',
    emoji: '💻',
  ),
  Product(
    id: 'p2',
    name: 'iPhone 15 Pro',
    description: '256GB, Titanium. The best iPhone yet.',
    price: '0.001',
    currency: 'ETH',
    emoji: '📱',
  ),
  Product(
    id: 'p3',
    name: 'AirPods Pro',
    description:
        'Active Noise Cancellation, Transparency mode, Adaptive Audio.',
    price: '10',
    currency: 'USDT',
    emoji: '🎧',
  ),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Busha Store')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = _products[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(product: product),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(product.emoji, style: const TextStyle(fontSize: 40)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${product.price} ${product.currency}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool _isProcessing = false;

  void _handleBuy() {
    setState(() => _isProcessing = true);
    BushaPay.checkout(
      context: context,
      config: BushaPayConfig(
        quoteAmount: widget.product.price,
        quoteCurrency: widget.product.currency,
        targetCurrency: 'USDT',
        sourceCurrency: 'USDT',
        reference:
            'ORDER_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}',
        metaName: 'Test Customer',
        metaEmail: 'test@example.com',
      ),
      onComplete: (result) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ReceiptPage(product: widget.product, result: result),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(product.emoji, style: const TextStyle(fontSize: 120)),
            ),
            const SizedBox(height: 24),
            Text(
              product.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${product.price} ${product.currency}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              product.description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _isProcessing ? null : _handleBuy,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF00C853),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Buy for ${product.price} ${product.currency}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class ReceiptPage extends StatelessWidget {
  final Product product;
  final BushaPayResult result;

  const ReceiptPage({super.key, required this.product, required this.result});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, details) = switch (result) {
      BushaPaySuccess(:final paymentId, :final status) => (
        Icons.check_circle,
        Colors.green,
        'Payment successful',
        'Payment ID: $paymentId\nStatus: $status',
      ),
      BushaPayCancelled() => (
        Icons.cancel_outlined,
        Colors.orange,
        'Payment cancelled',
        'You cancelled the payment.',
      ),
      BushaPayError(:final message, :final code) => (
        Icons.error_outline,
        Colors.red,
        'Payment failed',
        'Error: $message${code != null ? '\nCode: $code' : ''}',
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          product.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${product.price} ${product.currency}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text(
                      details,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Back to store'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
