import 'package:flutter/material.dart';

import '../busha_pay_config.dart';

enum PaymentChoice { bushaApp, stablecoins }

/// Bottom-sheet chooser shown when [BushaPay.checkout] is invoked.
/// Lets the user pick between paying via the installed Busha app (deep
/// link) or stable coins (web checkout).
class PaymentMethodChooser extends StatelessWidget {
  final BushaPayConfig config;

  const PaymentMethodChooser({super.key, required this.config});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Pay ${_formatAmount(config.quoteAmount)} ${config.quoteCurrency}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          _OptionTile(
            emoji: '🟢',
            title: 'Pay with Busha app',
            subtitle: 'Open the Busha app to complete payment',
            onTap: () => Navigator.pop(context, PaymentChoice.bushaApp),
          ),
          const Divider(height: 1, indent: 72),
          _OptionTile(
            emoji: '💳',
            title: 'Pay with Stablecoins',
            subtitle: 'Pay from an external crypto wallet',
            onTap: () => Navigator.pop(context, PaymentChoice.stablecoins),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );

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

class _OptionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({required this.emoji, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: SizedBox(
      width: 40,
      height: 40,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    trailing: const Icon(Icons.chevron_right),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    onTap: onTap,
  );
}
