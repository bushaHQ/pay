import 'dart:convert';

const String deepLinkEnablerScript = r'''
(function() {
  try {
    delete navigator.getInstalledRelatedApps;
    Object.defineProperty(navigator, 'getInstalledRelatedApps', {
      configurable: true,
      get: function() { return undefined; },
    });
  } catch (e) {}
})();
''';

const String bushaPayBridgeShim = r'''
(function() {
  window.BushaPayBridge = function(payload) {
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('BushaPayBridge', payload);
    }
  };
})();
''';

const String messageListenerScript = r'''
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
''';

String autoSelectScript(String rowTextPrefix) {
  final escaped = jsonEncode(rowTextPrefix);
  return '''
(function() {
  if (window.__bushaPayAutoSelectDone) return;
  var target = $escaped;
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
''';
}
