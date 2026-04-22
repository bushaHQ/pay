import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../busha_pay_config.dart';
import '../busha_pay_result.dart';
import 'busha_pay_api.dart';
import 'busha_pay_app.dart';
import 'payment_method_chooser.dart';
import 'payment_request.dart';

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
  /// Flow:
  /// 1. Creates a payment request via the Busha API.
  /// 2. Shows a chooser — "Pay with Busha app" or "Pay with Stablecoins".
  /// 3. Busha app → deep-links into the installed app (or falls back to the
  ///    web checkout if the app isn't installed).
  /// 4. Stablecoins → opens the web checkout.
  ///
  /// [onComplete] is called exactly once with the payment result.
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
    _runCheckout(context: context, config: config).then((result) {
      _isCheckoutInProgress = false;
      onComplete(result);
    });
  }

  static Future<BushaPayResult> _runCheckout({
    required BuildContext context,
    required BushaPayConfig config,
  }) async {
    // 1. Create the payment request server-side.
    final PaymentRequest paymentRequest;
    try {
      paymentRequest = await BushaPayApi.createPaymentRequest(
        config: config,
        publicKey: publicKey,
        isDev: isDevMode,
      );
    } on BushaPayApiException catch (e) {
      return BushaPayError(
        message: e.displayMessage,
        code: 'CREATE_PAYMENT_REQUEST_FAILED',
      );
    } catch (e) {
      return BushaPayError(
        message: 'Failed to create payment request: $e',
        code: 'CREATE_PAYMENT_REQUEST_FAILED',
      );
    }

    if (!context.mounted) return const BushaPayCancelled();

    // 2. Show the payment-method chooser.
    final choice = await showModalBottomSheet<PaymentChoice>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => PaymentMethodChooser(paymentRequest: paymentRequest),
    );

    if (choice == null) return const BushaPayCancelled();
    if (!context.mounted) return const BushaPayCancelled();

    // 3. Route to the chosen path.
    if (choice == PaymentChoice.bushaApp) {
      final deepLink = _buildBushaAppDeepLink(paymentRequest.id);
      if (deepLink case final deepLink? when await canLaunchUrl(deepLink)) {
        return _launchBushaApp(deepLink);
      }
      // Busha app not installed → fall through to the web checkout.
    }

    // 4. WebView path (chosen directly, or fallback).
    if (!context.mounted) return const BushaPayCancelled();
    final result = await showModalBottomSheet<BushaPayResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) =>
          BushaPaySheet(config: config.copyWith(sourceId: paymentRequest.id)),
    );
    return result ?? const BushaPayCancelled();
  }

  /// Platform-specific Busha app URL scheme for the current environment.
  static String? get _bushaAppScheme {
    if (Platform.isIOS) {
      return isDevMode ? 'co.busha.boro.development' : 'co.busha.apple';
    }
    if (Platform.isAndroid) {
      return isDevMode ? 'co.busha.android.development' : 'co.busha.android';
    }
    return null;
  }

  /// Builds `<scheme>://busha.co/pay?id=<paymentRequestId>`.
  static Uri? _buildBushaAppDeepLink(String paymentRequestId) {
    final scheme = _bushaAppScheme;
    if (scheme == null) return null;
    return Uri(
      scheme: scheme,
      host: 'busha.co',
      path: '/pay',
      queryParameters: {'id': paymentRequestId},
    );
  }

  /// Launches the Busha app and waits for the callback URL to resolve.
  ///
  /// If the user backgrounds our app and comes back without a callback
  /// arriving (e.g. they cancelled in the Busha app), we complete with
  /// [BushaPayCancelled].
  static Future<BushaPayResult> _launchBushaApp(Uri deepLink) async {
    final completer = Completer<BushaPayResult>();
    _directLaunchCompleter = completer;

    final resumeObserver = _AppResumeObserver(() {
      // Give the callback a moment to land first. If nothing arrives,
      // treat the resume as "user came back without paying".
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!completer.isCompleted) {
          completer.complete(const BushaPayCancelled());
        }
      });
    });
    WidgetsBinding.instance.addObserver(resumeObserver);

    try {
      await launchUrl(deepLink, mode: LaunchMode.externalApplication);
      return await completer.future;
    } finally {
      WidgetsBinding.instance.removeObserver(resumeObserver);
      _directLaunchCompleter = null;
    }
  }

  /// Check if a deep link URL is a Busha Pay callback.
  ///
  /// Call this from your app's deep link handler to forward Busha Pay
  /// callbacks to the SDK.
  ///
  /// Returns `true` if the URL was handled by the SDK.
  static bool handleDeepLink(Uri uri) {
    if (uri.scheme == callbackScheme && uri.host == 'callback') {
      // If we launched the Busha app directly, resolve that flow.
      final completer = _directLaunchCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(_parseCallback(uri));
        return true;
      }
      // Otherwise forward to the active web-checkout sheet.
      _pendingCallbackHandler?.call(uri);
      return true;
    }
    return false;
  }

  static BushaPayResult _parseCallback(Uri uri) {
    final status = uri.queryParameters['status'];
    final paymentRequestId = uri.queryParameters['paymentRequestId'] ?? '';
    final checkoutId = uri.queryParameters['checkoutId'] ?? '';

    if (status == 'completed') {
      return BushaPaySuccess.fromCallback(
        paymentId: paymentRequestId,
        checkoutId: checkoutId,
      );
    }
    return BushaPayError(message: 'Payment failed', code: status ?? 'unknown');
  }

  // Internal: direct-launch flow waiting for a callback URL.
  static Completer<BushaPayResult>? _directLaunchCompleter;

  // Internal: registered by the active WebView sheet.
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

/// Fires its [onResume] callback whenever the app returns to the foreground.
class _AppResumeObserver with WidgetsBindingObserver {
  final VoidCallback onResume;
  _AppResumeObserver(this.onResume);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
