import Foundation

enum Scripts {
    /// Removes `navigator.getInstalledRelatedApps` so pug-pay falls back to
    /// its deep-link path. Without this, iOS WKWebView returns an empty
    /// array, which silently no-ops the "Pay with Busha app" tile.
    static let deepLinkEnabler = """
    (function() {
      try {
        delete navigator.getInstalledRelatedApps;
        Object.defineProperty(navigator, 'getInstalledRelatedApps', {
          configurable: true,
          get: function() { return undefined; },
        });
      } catch (e) {}
    })();
    """

    /// Defines `window.BushaPayBridge(payload)` for iOS — postMessages to
    /// the WKWebView's `BushaPayBridge` script-message handler.
    static let bushaPayBridgeShim = """
    (function() {
      window.BushaPayBridge = function(payload) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.BushaPayBridge) {
          window.webkit.messageHandlers.BushaPayBridge.postMessage(payload);
        }
      };
    })();
    """

    /// Translates pug-pay's `INITIALIZED`, `CANCELLED`, `COMPLETED`
    /// messages into bridge calls. Document-start so it survives the form
    /// POST navigation.
    static let messageListener = """
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
        if (payload && window.BushaPayBridge) {
          window.BushaPayBridge(payload);
        }
      });
    })();
    """

    /// Fallback auto-select script — clicks the chooser tile whose text
    /// starts with `rowTextPrefix`. Covers older pug-pay builds that
    /// don't honour the `paymentMethod` URL param.
    static func autoSelect(rowTextPrefix: String) -> String {
        let escaped = jsonEncode(rowTextPrefix)
        return """
        (function() {
          if (window.__bushaPayAutoSelectDone) return;
          var target = \(escaped);
          function tryClick() {
            var items = document.querySelectorAll('[role="button"]');
            for (var i = 0; i < items.length; i++) {
              var text = (items[i].textContent || '').trim();
              if (text.indexOf(target) === 0) {
                window.__bushaPayAutoSelectDone = true;
                items[i].click();
                return true;
              }
            }
            return false;
          }
          if (tryClick()) return;
          var obs = new MutationObserver(function() {
            if (tryClick()) obs.disconnect();
          });
          obs.observe(document.body, { childList: true, subtree: true });
          setTimeout(function() { obs.disconnect(); }, 10000);
        })();
        """
    }

    /// Calls the page's `initCheckout(config)` with the JSON-encoded
    /// payload. Triggers the hidden form POST to pug-pay.
    static func initCheckout(payloadJson: String) -> String {
        "initCheckout(\(payloadJson));"
    }
}

/// JSON-encodes a string into a quoted JSON string literal (with all the
/// escaping `JSON.stringify` does). Used to inject user-controlled text
/// into JavaScript safely.
func jsonEncode(_ s: String) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: [s], options: [.fragmentsAllowed])) ?? Data("[\"\"]".utf8)
    let raw = String(data: data, encoding: .utf8) ?? "[\"\"]"
    // Strip surrounding `[` `]` so we get just the encoded literal.
    if raw.hasPrefix("[") && raw.hasSuffix("]") {
        return String(raw.dropFirst().dropLast())
    }
    return raw
}
