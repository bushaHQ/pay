package co.busha.pay.internal

import org.json.JSONObject

/**
 * JavaScript injected into the checkout WebView.
 *
 * The native side exposes a `@JavascriptInterface` object named
 * `BushaPayAndroid` with a `postMessage(String)` method; the bridge shim
 * routes `window.BushaPayBridge(payload)` through it.
 */

/** Name of the `@JavascriptInterface` object added to the WebView. */
internal const val JS_INTERFACE_NAME = "BushaPayAndroid"

private const val BRIDGE_SHIM = """
(function() {
  window.BushaPayBridge = function(payload) {
    if (window.BushaPayAndroid && window.BushaPayAndroid.postMessage) {
      window.BushaPayAndroid.postMessage(payload);
    }
  };
})();
"""

private const val MESSAGE_LISTENER = """
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

private const val DEEP_LINK_ENABLER = """
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

private const val INIT_CHECKOUT_FN = """
(function() {
  if (window.__bushaPayInitCheckoutDefined) return;
  window.__bushaPayInitCheckoutDefined = true;
  window.initCheckout = function(config) {
    var existing = document.getElementById('checkoutForm');
    if (existing && existing.parentNode) {
      existing.parentNode.removeChild(existing);
    }
    var form = document.createElement('form');
    form.id = 'checkoutForm';
    form.method = 'POST';
    form.style.display = 'none';
    form.action = config._checkoutUrl;
    delete config._checkoutUrl;
    for (var key in config) {
      if (Object.prototype.hasOwnProperty.call(config, key)) {
        var input = document.createElement('input');
        input.type = 'hidden';
        input.name = key;
        input.value = config[key];
        form.appendChild(input);
      }
    }
    (document.body || document.documentElement).appendChild(form);
    form.submit();
  };
})();
"""

/** Scripts injected as early as possible into every checkout document. */
internal val DOCUMENT_START_SCRIPTS: String = listOf(
    BRIDGE_SHIM,
    MESSAGE_LISTENER,
    DEEP_LINK_ENABLER,
    INIT_CHECKOUT_FN,
).joinToString("\n")

/** Builds the JS call that submits the checkout form with [configJson]. */
internal fun initCheckoutScript(configJson: String): String =
    "initCheckout($configJson); true;"

/**
 * Builds the auto-select JS that taps the chooser row whose text starts
 * with [rowTextPrefix]. The prefix is JSON-encoded so embedded quotes
 * are escaped safely.
 */
internal fun autoSelectScript(rowTextPrefix: String): String {
    val target = JSONObject.quote(rowTextPrefix)
    return """
(function() {
  if (window.__bushaPayAutoSelectDone) return;
  var target = $target;
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
true;
"""
}
