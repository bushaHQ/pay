const BRIDGE_SHIM = `
(function() {
  window.BushaPayBridge = function(payload) {
    if (window.ReactNativeWebView) {
      window.ReactNativeWebView.postMessage(payload);
    }
  };
})();
`;

const MESSAGE_LISTENER = `
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
`;

// iOS WKWebView implements navigator.getInstalledRelatedApps but returns an
// empty array, which makes pug-pay's "Pay with Busha app" tile silently
// no-op. Deleting it forces pug-pay to fall through to the deep-link path.
const DEEP_LINK_ENABLER = `
(function() {
  try {
    delete navigator.getInstalledRelatedApps;
    Object.defineProperty(navigator, 'getInstalledRelatedApps', {
      configurable: true,
      get: function() { return undefined; },
    });
  } catch (e) {}
})();
`;

export const DOCUMENT_START_SCRIPTS = [
  BRIDGE_SHIM,
  MESSAGE_LISTENER,
  DEEP_LINK_ENABLER,
].join('\n');

export const initCheckoutScript = (configJson: string): string =>
  `initCheckout(${configJson}); true;`;

export const autoSelectScript = (rowTextPrefix: string): string => `
(function() {
  if (window.__bushaPayAutoSelectDone) return;
  var target = ${JSON.stringify(rowTextPrefix)};
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
`;
