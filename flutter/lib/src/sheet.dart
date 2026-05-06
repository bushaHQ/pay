import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../busha_pay_config.dart';
import '../busha_pay_result.dart';
import 'bridge.dart';
import 'scripts.dart';
import 'sdk.dart';
import 'shimmer.dart';

enum PugPayAutoSelect {
  none,
  bushaApp,
  stablecoins;

  String? get queryParam => switch (this) {
    PugPayAutoSelect.bushaApp => 'busha',
    PugPayAutoSelect.stablecoins => 'stablecoins',
    PugPayAutoSelect.none => null,
  };

  String? get rowTextPrefix => switch (this) {
    PugPayAutoSelect.bushaApp => 'Busha',
    PugPayAutoSelect.stablecoins => 'Stablecoins',
    PugPayAutoSelect.none => null,
  };
}

class BushaPaySheet extends StatefulWidget {
  final BushaPayConfig config;

  final PugPayAutoSelect autoSelect;

  /// Skips HTML asset loading so the InAppWebView never builds. Used by
  /// widget tests that only care about lifecycle / deep-link plumbing,
  /// since `flutter_inappwebview` has no platform impl in unit tests.
  @visibleForTesting
  final bool skipHtmlLoad;

  const BushaPaySheet({
    super.key,
    required this.config,
    this.autoSelect = PugPayAutoSelect.none,
    this.skipHtmlLoad = false,
  });

  @override
  State<BushaPaySheet> createState() => _BushaPaySheetState();
}

class _BushaPaySheetState extends State<BushaPaySheet> with WidgetsBindingObserver {
  InAppWebViewController? _webViewController;
  bool _resultDelivered = false;
  String? _htmlContent;
  bool _checkoutInitialized = false;
  bool _formSubmitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BushaPay.registerCallbackHandler(_onDeepLinkReceived);
    if (!widget.skipHtmlLoad) _loadHtml();
  }

  Future<void> _loadHtml() async {
    final html = await rootBundle.loadString('packages/busha_pay/assets/busha_pay_checkout.html');
    if (mounted) {
      setState(() => _htmlContent = html);
    }
  }

  @override
  void dispose() {
    BushaPay.unregisterCallbackHandler();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onDeepLinkReceived(Uri uri) {
    if (_resultDelivered) return;

    if (uri.scheme == BushaPay.callbackScheme && uri.host == 'callback') {
      final status = uri.queryParameters['status'];
      final paymentRequestId = uri.queryParameters['paymentRequestId'] ?? '';

      if (status == 'completed') {
        _deliverResult(BushaPaySuccess.fromCallback(paymentId: paymentRequestId));
      } else {
        _deliverResult(BushaPayError(message: 'Payment failed', code: status ?? 'unknown'));
      }
    }
  }

  void _deliverResult(BushaPayResult result) {
    if (_resultDelivered) return;
    _resultDelivered = true;

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _onBridgeMessage(String message) {
    if (_resultDelivered) return;
    switch (parseBridgeMessage(message)) {
      case BridgeReady():
        if (mounted) setState(() => _checkoutInitialized = true);
      case BridgeResult(:final result):
        _deliverResult(result);
      case BridgeUnknown():
        break;
    }
  }

  void _injectAutoSelect(InAppWebViewController controller) {
    final rowPrefix = widget.autoSelect.rowTextPrefix;
    if (rowPrefix == null) return;
    controller.evaluateJavascript(source: autoSelectScript(rowPrefix));
  }

  void _submitCheckout() {
    final controller = _webViewController;
    if (controller == null) return;

    final formFields = widget.config.toFormFields(
      publicKey: BushaPay.publicKey,
      callbackUrl: BushaPay.callbackUrl,
      checkoutUrl: BushaPay.checkoutUrl,
    );

    final queryMethod = widget.autoSelect.queryParam;
    final formAction = queryMethod != null
        ? '${BushaPay.checkoutUrl}?paymentMethod=$queryMethod'
        : BushaPay.checkoutUrl;

    final config = <String, String>{'_checkoutUrl': formAction, ...formFields};

    final configJson = jsonEncode(config);
    controller.evaluateJavascript(source: 'initCheckout($configJson)');
  }

  Future<bool> _handleNavigation(Uri uri) async {
    if (isWebScheme(uri.scheme)) return false;

    final canOpen = await canLaunchUrl(uri);
    if (canOpen) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.92,
    padding: _checkoutInitialized ? null : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    decoration: const BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.all(Radius.circular(16))),
    child: Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Stack(
              children: [
                if (_htmlContent case final htmlContent?)
                  InAppWebView(
                    initialData: InAppWebViewInitialData(
                      data: htmlContent,
                      baseUrl: WebUri(BushaPay.checkoutUrl),
                      historyUrl: WebUri(BushaPay.checkoutUrl),
                    ),
                    initialUserScripts: UnmodifiableListView([
                      UserScript(source: bushaPayBridgeShim, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
                      UserScript(
                        source: messageListenerScript,
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                      UserScript(
                        source: deepLinkEnablerScript,
                        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    ]),
                    initialSettings: InAppWebViewSettings(
                      supportMultipleWindows: true,
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
                      transparentBackground: true,
                    ),
                    onCreateWindow: (_, req) async {
                      final uri = req.request.url;
                      return uri != null && await _handleNavigation(uri);
                    },
                    shouldOverrideUrlLoading: (_, action) async {
                      final uri = action.request.url;
                      if (uri != null && await _handleNavigation(uri)) {
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                    onWebViewCreated: (controller) {
                      _webViewController = controller;

                      controller.addJavaScriptHandler(
                        handlerName: 'BushaPayBridge',
                        callback: (args) {
                          if (args.isNotEmpty) {
                            _onBridgeMessage(args[0] as String);
                          }
                        },
                      );
                    },
                    onLoadStop: (controller, url) {
                      if (!_formSubmitted) {
                        _formSubmitted = true;
                        _submitCheckout();
                        return;
                      }
                      if (!_checkoutInitialized) {
                        setState(() => _checkoutInitialized = true);
                      }
                      _injectAutoSelect(controller);
                    },
                  ),
                if (!_checkoutInitialized) const ChooserShimmer(),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
