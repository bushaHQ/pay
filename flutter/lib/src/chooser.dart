import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../busha_pay_config.dart';
import 'sdk.dart';
import 'merchant_api.dart';
import 'payment_method.dart';

export 'payment_method.dart';

class PaymentMethodChooser extends StatefulWidget {
  final BushaPayConfig config;

  /// Methods to render as tiles. `null` or an empty list shows everything.
  final List<PaymentMethod>? allowedPaymentMethods;

  @visibleForTesting
  final Future<String?> Function()? merchantNameLoader;

  const PaymentMethodChooser({super.key, required this.config, this.allowedPaymentMethods, this.merchantNameLoader});

  @override
  State<PaymentMethodChooser> createState() => _PaymentMethodChooserState();
}

class _PaymentMethodChooserState extends State<PaymentMethodChooser> {
  String? _merchantName;

  @override
  void initState() {
    super.initState();
    final loader = widget.merchantNameLoader ?? () => fetchMerchantName(BushaPay.publicKey);
    loader().then((name) {
      if (!mounted || name == null) return;
      setState(() => _merchantName = name);
    });
  }

  bool _shows(PaymentMethod method) {
    final allowed = widget.allowedPaymentMethods;
    return allowed == null || allowed.isEmpty || allowed.contains(method);
  }

  @override
  Widget build(BuildContext context) {
    final showsBusha = _shows(PaymentMethod.bushaApp);
    final showsStablecoins = _shows(PaymentMethod.stablecoins);

    return Dialog(
      backgroundColor: _kContainmentPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pay ${_formatAmount(widget.config.quoteAmount)} ${widget.config.quoteCurrency}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2, color: _kTextHigh),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, color: _kTextHigh),
                    ),
                  ],
                ),
                if (_merchantName case final merchant?) ...[
                  const SizedBox(height: 8),
                  Text(
                    'To $merchant',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: _kTextMid),
                  ),
                ],
                const SizedBox(height: 32),
                const Text(
                  'Choose a payment method',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _kTextHigh),
                ),
                const SizedBox(height: 12),
                if (showsBusha)
                  _PaymentMethodTile(
                    name: 'Busha',
                    description: 'Make payment directly from your busha account',
                    iconAssetPath: 'assets/icons/busha.svg',
                    onTap: () => Navigator.of(context).pop(PaymentMethod.bushaApp),
                  ),
                if (showsBusha && showsStablecoins) const SizedBox(height: 16),
                if (showsStablecoins)
                  _PaymentMethodTile(
                    name: 'Stablecoins',
                    description: 'Make payment from an external wallet',
                    iconAssetPath: 'assets/icons/wallet-outline.svg',
                    onTap: () => Navigator.of(context).pop(PaymentMethod.stablecoins),
                  ),
                const SizedBox(height: 32),
                const _SecuredByFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatAmount(String amount) {
    final n = num.tryParse(amount);
    if (n == null) return amount;
    final hasDecimals = n % 1 != 0;
    final s = n.toStringAsFixed(hasDecimals ? 2 : 0);
    final parts = s.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return parts.length > 1 ? '$whole.${parts[1]}' : whole;
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String name;
  final String description;
  final String iconAssetPath;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.name,
    required this.description,
    required this.iconAssetPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _kContainmentTertiary, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: _kContainmentSecondary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                iconAssetPath,
                package: 'busha_pay',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(_kTextHigh, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _kTextHigh),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: _kTextMid),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 24, color: _kTextMid),
          ],
        ),
      ),
    ),
  );
}

class _SecuredByFooter extends StatelessWidget {
  const _SecuredByFooter();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text(
        'Secured by',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: _kTextMid),
      ),
      const SizedBox(width: 8),
      SvgPicture.asset('assets/icons/busha-logo.svg', package: 'busha_pay', height: 14),
    ],
  );
}

const Color _kTextHigh = Color(0xFF000000);
const Color _kTextMid = Color(0xFF586558);
const Color _kContainmentPrimary = Color(0xFFEDF2ED);
const Color _kContainmentTertiary = Color(0xFFFFFFFF);
const Color _kContainmentSecondary = Color(0xFFD1D9D1);
