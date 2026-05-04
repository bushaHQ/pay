import 'dart:convert';

import '../busha_pay_result.dart';

/// A parsed message from the WebView bridge.
sealed class BridgeMessage {
  const BridgeMessage();
}

/// Finished bootstrapping the iframe — hide the shimmer.
class BridgeReady extends BridgeMessage {
  const BridgeReady();
}

/// Reported a terminal outcome (success, cancellation, error).
class BridgeResult extends BridgeMessage {
  final BushaPayResult result;
  const BridgeResult(this.result);
}

/// Unparseable JSON, missing `type`, or an unknown `type` value.
class BridgeUnknown extends BridgeMessage {
  const BridgeUnknown();
}

/// URI schemes that should stay inside the WebView. Anything else is
/// handed to the OS via [url_launcher] (deep links, mailto:, tel:, …).
const Set<String> kWebSchemes = {'http', 'https', 'about', 'data', 'blob'};

bool isWebScheme(String scheme) => kWebSchemes.contains(scheme);

BridgeMessage parseBridgeMessage(String message) {
  try {
    final decoded = jsonDecode(message);
    if (decoded is! Map<String, dynamic>) return const BridgeUnknown();
    final type = decoded['type'] as String?;
    final data = decoded['data'];
    switch (type) {
      case 'ready':
        return const BridgeReady();
      case 'success':
        if (data is! Map<String, dynamic>) return const BridgeUnknown();
        return BridgeResult(BushaPaySuccess.fromCommerceJs(data));
      case 'close':
        return const BridgeResult(BushaPayCancelled());
      case 'error':
        final errorData = data is Map<String, dynamic> ? data : const <String, dynamic>{};
        return BridgeResult(
          BushaPayError(
            message: errorData['message'] as String? ?? 'An error occurred',
            code: errorData['code'] as String?,
          ),
        );
      default:
        return const BridgeUnknown();
    }
  } catch (_) {
    return const BridgeUnknown();
  }
}
