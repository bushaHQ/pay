import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../busha_pay_config.dart';
import '../busha_pay_result.dart';
import 'busha_pay_app.dart';

/// Busha Pay environment.
enum BushaEnvironment {
  /// Sandbox environment for testing.
  sandbox,

  /// Live production environment.
  live,
}

/// Busha Pay SDK for Flutter.
///
/// Initialize once, then call [checkout] to launch the payment flow.
///
/// ```dart
/// await BushaPay.init(publicKey: 'pub_xxx');
///
/// BushaPay.checkout(
///   context: context,
///   config: BushaPayConfig(
///     quoteAmount: '10000',
///     quoteCurrency: 'NGN',
///     targetCurrency: 'NGN',
///     sourceCurrency: 'USDT',
///   ),
///   onComplete: (result) { ... },
/// );
/// ```
class BushaPay {
  BushaPay._();

  static String? _publicKey;
  static BushaEnvironment _environment = BushaEnvironment.live;
  static bool _isCheckoutInProgress = false;
  static String? _packageName;

  /// Whether the SDK has been initialized.
  static bool get isInitialized => _publicKey != null;

  /// Whether a checkout is currently in progress.
  static bool get isCheckoutInProgress => _isCheckoutInProgress;

  /// The callback URL scheme for this app.
  static String get callbackScheme {
    assert(_packageName != null, 'BushaPay.init() must be called first');
    return '$_packageName.busha-pay';
  }

  /// The full callback URL for this app.
  static String get callbackUrl => '$callbackScheme://callback';

  /// Whether the SDK is in dev/sandbox mode.
  static bool get isDevMode => _environment == BushaEnvironment.sandbox;

  /// The checkout page URL for the current environment.
  static String get checkoutUrl => isDevMode
      ? 'https://staging.pay.busha.co/pay'
      : 'https://pay.busha.co/pay';

  /// The configured public key.
  static String get publicKey {
    assert(_publicKey != null, 'BushaPay.init() must be called first');
    return _publicKey!;
  }

  /// Initialize the Busha Pay SDK.
  ///
  /// Must be called once before using [checkout] or [BushaPayButton].
  /// Typically called in your `main()` function.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await BushaPay.init(
  ///     publicKey: 'pub_xxx',
  ///     environment: BushaEnvironment.sandbox,
  ///   );
  ///   runApp(const MyApp());
  /// }
  /// ```
  static Future<void> init({
    required String publicKey,
    BushaEnvironment environment = BushaEnvironment.live,
  }) async {
    _publicKey = publicKey;
    _environment = environment;

    final packageInfo = await PackageInfo.fromPlatform();
    _packageName = packageInfo.packageName;
  }

  /// Launch the Busha Pay checkout.
  ///
  /// Opens a bottom sheet with the Busha checkout UI. The user can pay
  /// via the Busha app (if installed) or through the web checkout.
  ///
  /// [onComplete] is called exactly once with the payment result.
  ///
  /// ```dart
  /// BushaPay.checkout(
  ///   context: context,
  ///   config: BushaPayConfig(
  ///     quoteAmount: '10000',
  ///     quoteCurrency: 'NGN',
  ///     targetCurrency: 'NGN',
  ///     sourceCurrency: 'USDT',
  ///     metaName: 'John Doe',
  ///     metaEmail: 'john@example.com',
  ///   ),
  ///   onComplete: (result) {
  ///     switch (result) {
  ///       case BushaPaySuccess(:final paymentId):
  ///         // Verify via webhook, show confirmation
  ///       case BushaPayCancelled():
  ///         // User dismissed
  ///       case BushaPayError(:final message):
  ///         // Show error
  ///     }
  ///   },
  /// );
  /// ```
  static void checkout({
    required BuildContext context,
    required BushaPayConfig config,
    required void Function(BushaPayResult result) onComplete,
  }) {
    assert(isInitialized, 'BushaPay.init() must be called before checkout()');

    if (_isCheckoutInProgress) {
      onComplete(
        const BushaPayError(
          message: 'Another payment is already in progress',
          code: 'CHECKOUT_IN_PROGRESS',
        ),
      );
      return;
    }

    _isCheckoutInProgress = true;

    showModalBottomSheet<BushaPayResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => BushaPaySheet(config: config),
    ).then((result) {
      _isCheckoutInProgress = false;
      onComplete(result ?? const BushaPayCancelled());
    });
  }

  /// Check if a deep link URL is a Busha Pay callback.
  ///
  /// Call this from your app's deep link handler to forward Busha Pay
  /// callbacks to the SDK.
  ///
  /// Returns `true` if the URL was handled by the SDK.
  static bool handleDeepLink(Uri uri) {
    if (uri.scheme == callbackScheme && uri.host == 'callback') {
      _pendingCallbackHandler?.call(uri);
      return true;
    }
    return false;
  }

  // Internal: registered by the active WebView sheet
  static void Function(Uri)? _pendingCallbackHandler;

  /// Register a callback handler for the active checkout session.
  static void registerCallbackHandler(void Function(Uri) handler) {
    _pendingCallbackHandler = handler;
  }

  /// Unregister the callback handler.
  static void unregisterCallbackHandler() {
    _pendingCallbackHandler = null;
  }
}
