import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../busha_pay_config.dart';
import '../busha_pay_result.dart';
import 'busha_pay_sdk.dart';

class BushaPaySheet extends StatefulWidget {
  final BushaPayConfig config;

  const BushaPaySheet({super.key, required this.config});

  @override
  State<BushaPaySheet> createState() => _BushaPaySheetState();
}

/// JS that runs at document start, before the checkout's own scripts load.
///
/// The checkout's "Pay with Busha app" click handler only fires the deep
/// link when `navigator.getInstalledRelatedApps` is undefined (fallback
/// branch in PaymentMethods.tsx). On iOS WKWebView the API exists but
/// returns an empty list, so the deep link is silently skipped. Deleting
/// the API forces the fallback path that calls `getCheckoutDeepLink()`.
const String _deepLinkEnablerScript = r'''
(function() {
  try {
    delete navigator.getInstalledRelatedApps;
    // If `delete` doesn't stick (some engines), shadow with undefined.
    Object.defineProperty(navigator, 'getInstalledRelatedApps', {
      configurable: true,
      get: function() { return undefined; },
    });
  } catch (e) {}
})();
''';

class _BushaPaySheetState extends State<BushaPaySheet>
    with WidgetsBindingObserver {
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
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final html = await rootBundle.loadString(
      'packages/busha_pay/assets/busha_pay_form_dart.html',
    );
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

    print('BushaPay: Received deep link: $uri');

    if (uri.scheme == BushaPay.callbackScheme && uri.host == 'callback') {
      final status = uri.queryParameters['status'];
      final paymentRequestId = uri.queryParameters['paymentRequestId'] ?? '';
      final checkoutId = uri.queryParameters['checkoutId'] ?? '';

      if (status == 'completed') {
        _deliverResult(
          BushaPaySuccess.fromCallback(
            paymentId: paymentRequestId,
            checkoutId: checkoutId,
          ),
        );
      } else {
        _deliverResult(
          BushaPayError(message: 'Payment failed', code: status ?? 'unknown'),
        );
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

    try {
      final payload = jsonDecode(message) as Map<String, dynamic>;
      final type = payload['type'] as String?;
      final data = payload['data'];

      switch (type) {
        case 'ready':
          if (mounted) {
            setState(() => _checkoutInitialized = true);
          }
        case 'success':
          _deliverResult(
            BushaPaySuccess.fromCommerceJs(data as Map<String, dynamic>),
          );
        case 'close':
          _deliverResult(const BushaPayCancelled());
        case 'error':
          final errorData = data as Map<String, dynamic>? ?? {};
          _deliverResult(
            BushaPayError(
              message: errorData['message'] as String? ?? 'An error occurred',
              code: errorData['code'] as String?,
            ),
          );
      }
    } catch (e) {
      debugPrint('BushaPay: Failed to parse bridge message: $e');
    }
  }

  /// Re-install the postMessage listener on the checkout page.
  ///
  /// The bridge HTML's own listener is destroyed when the form submits
  /// and the WebView navigates to the checkout page. We inject an
  /// equivalent listener into the checkout page's JS context so we can
  /// still receive INITIALIZED / CANCELLED / COMPLETED statuses.
  void _injectMessageListener(InAppWebViewController controller) {
    controller.evaluateJavascript(
      source: r'''
      (function() {
        if (window.__bushaPayListenerAdded) return;
        window.__bushaPayListenerAdded = true;
        window.addEventListener('message', function(event) {
          var data = event.data;
          if (!data || typeof data !== 'object') return;
          var status = data.status;
          var payload = null;
          if (status === 'INITIALIZED') {
            payload = JSON.stringify({ type: 'ready', data: {} });
          } else if (status === 'CANCELLED') {
            payload = JSON.stringify({ type: 'close', data: data.data || {} });
          } else if (status === 'COMPLETED') {
            payload = JSON.stringify({ type: 'success', data: data });
          }
          if (payload && window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('BushaPayBridge', payload);
          }
        });
      })();
    ''',
    );
  }

  /// Submit the checkout form via JS after the bridge HTML loads.
  void _submitCheckoutForm() {
    final controller = _webViewController;
    if (controller == null) return;

    final formFields = widget.config.toFormFields(
      publicKey: BushaPay.publicKey,
      callbackUrl: BushaPay.callbackUrl,
      checkoutUrl: BushaPay.checkoutUrl,
    );

    // Add the checkout URL as an internal field for the JS to use.
    final config = <String, String>{
      '_checkoutUrl': BushaPay.checkoutUrl,
      ...formFields,
    };

    final configJson = jsonEncode(config);
    controller.evaluateJavascript(source: 'initCheckout($configJson)');
  }

  Future<bool> _handleNavigation(Uri uri) async {
    const web = {'http', 'https', 'about', 'data', 'blob'};
    if (web.contains(uri.scheme)) return false;

    final canOpen = await canLaunchUrl(uri);
    if (canOpen) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // WebView
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  if (_htmlContent != null)
                    InAppWebView(
                      initialData: InAppWebViewInitialData(
                        data: _htmlContent!,
                        baseUrl: WebUri(BushaPay.checkoutUrl),
                        historyUrl: WebUri(BushaPay.checkoutUrl),
                      ),
                      initialUserScripts: UnmodifiableListView([
                        UserScript(
                          source: _deepLinkEnablerScript,
                          injectionTime:
                              UserScriptInjectionTime.AT_DOCUMENT_START,
                        ),
                      ]),
                      initialSettings: InAppWebViewSettings(
                        supportMultipleWindows: true,
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        javaScriptCanOpenWindowsAutomatically: true,
                        mixedContentMode:
                            MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
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
                          _submitCheckoutForm();
                        } else if (!_checkoutInitialized) {
                          setState(() => _checkoutInitialized = true);
                          _injectMessageListener(controller);
                        }
                      },
                      onConsoleMessage: (controller, consoleMessage) {
                        debugPrint(
                          'BushaPay JS [${consoleMessage.messageLevel}]: ${consoleMessage.message}',
                        );
                      },
                      onReceivedError: (controller, request, error) {
                        debugPrint(
                          'BushaPay: WebView error: ${error.description} (url=${request.url})',
                        );
                      },
                    ),
                  if (!_checkoutInitialized)
                    Container(
                      color: Colors.white,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF00C853),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
