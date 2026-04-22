import 'package:flutter/material.dart';

import 'busha_pay_config.dart';
import 'busha_pay_result.dart';
import 'src/busha_pay_sdk.dart';

/// A branded "Pay with Busha" button.
///
/// Handles launching the checkout when tapped.
///
/// ```dart
/// BushaPayButton(
///   config: BushaPayConfig(
///     quoteAmount: '10000',
///     quoteCurrency: 'NGN',
///     targetCurrency: 'NGN',
///     sourceCurrency: 'USDT',
///   ),
///   onComplete: (result) {
///     switch (result) {
///       case BushaPaySuccess():
///         // handle success
///       case BushaPayCancelled():
///         // handle cancel
///       case BushaPayError():
///         // handle error
///     }
///   },
/// )
/// ```
class BushaPayButton extends StatelessWidget {
  /// Checkout configuration.
  final BushaPayConfig config;

  /// Called when the checkout flow completes.
  final void Function(BushaPayResult result) onComplete;

  /// Optional button style override.
  final BushaPayButtonStyle style;

  /// Whether the button is enabled.
  final bool enabled;

  const BushaPayButton({
    super.key,
    required this.config,
    required this.onComplete,
    this.style = BushaPayButtonStyle.filled,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      BushaPayButtonStyle.filled => _FilledButton(
        enabled: enabled && !BushaPay.isCheckoutInProgress,
        onTap: () => _launchCheckout(context),
      ),
      BushaPayButtonStyle.outlined => _OutlinedButton(
        enabled: enabled && !BushaPay.isCheckoutInProgress,
        onTap: () => _launchCheckout(context),
      ),
    };
  }

  void _launchCheckout(BuildContext context) {
    BushaPay.checkout(context: context, config: config, onComplete: onComplete);
  }
}

/// Button style options for [BushaPayButton].
enum BushaPayButtonStyle {
  /// Solid green background with white text.
  filled,

  /// White background with green border and text.
  outlined,
}

// ---------------------------------------------------------------------------
// Internal button implementations
// ---------------------------------------------------------------------------

const _bushaGreen = Color(0xFF00C853);
const _bushaGreenDark = Color(0xFF00B348);

class _FilledButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _FilledButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? _bushaGreen : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BushaLogo(color: enabled ? Colors.white : Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Pay with Busha',
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _OutlinedButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled ? _bushaGreen : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BushaLogo(color: enabled ? _bushaGreen : Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Pay with Busha',
                style: TextStyle(
                  color: enabled ? _bushaGreenDark : Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BushaLogo extends StatelessWidget {
  final Color color;

  const _BushaLogo({required this.color});

  @override
  Widget build(BuildContext context) {
    // Simple "B" logo placeholder — replace with actual Busha SVG asset
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          'B',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
