import { describe, expect, test } from '@jest/globals';

import {
  DOCUMENT_START_SCRIPTS,
  autoSelectScript,
  initCheckoutScript,
} from '../user-scripts';

describe('DOCUMENT_START_SCRIPTS', () => {
  test('defines the BushaPayBridge using ReactNativeWebView.postMessage', () => {
    expect(DOCUMENT_START_SCRIPTS).toContain('window.BushaPayBridge');
    expect(DOCUMENT_START_SCRIPTS).toContain(
      'window.ReactNativeWebView.postMessage'
    );
  });

  test('routes web checkout statuses to bridge payload types', () => {
    expect(DOCUMENT_START_SCRIPTS).toContain("status === 'INITIALIZED'");
    expect(DOCUMENT_START_SCRIPTS).toContain("status === 'CANCELLED'");
    expect(DOCUMENT_START_SCRIPTS).toContain("status === 'COMPLETED'");
    expect(DOCUMENT_START_SCRIPTS).toContain("type: 'ready'");
    expect(DOCUMENT_START_SCRIPTS).toContain("type: 'close'");
    expect(DOCUMENT_START_SCRIPTS).toContain("type: 'success'");
  });

  test('guards the message listener against double-installation', () => {
    expect(DOCUMENT_START_SCRIPTS).toContain('__bushaPayListenerAdded');
  });

  test('removes navigator.getInstalledRelatedApps to enable deep-linking', () => {
    expect(DOCUMENT_START_SCRIPTS).toContain(
      'delete navigator.getInstalledRelatedApps'
    );
    expect(DOCUMENT_START_SCRIPTS).toContain('configurable: true');
  });

  test('defines the initCheckout helper and guards against re-definition', () => {
    expect(DOCUMENT_START_SCRIPTS).toContain('window.initCheckout');
    expect(DOCUMENT_START_SCRIPTS).toContain('__bushaPayInitCheckoutDefined');
  });
});

describe('initCheckoutScript', () => {
  test('wraps the JSON payload in a call to initCheckout', () => {
    const js = initCheckoutScript('{"a":1}');
    expect(js).toContain('initCheckout({"a":1})');
  });

  test('appends `true;` so the WebView injection returns a value', () => {
    expect(initCheckoutScript('{}').trim().endsWith('true;')).toBe(true);
  });
});

describe('autoSelectScript', () => {
  test('JSON-encodes the prefix as a JS string literal', () => {
    expect(autoSelectScript('Busha')).toContain('var target = "Busha"');
  });

  test('escapes embedded quotes safely', () => {
    expect(autoSelectScript('She said "hi"')).toContain(
      'var target = "She said \\"hi\\""'
    );
  });

  test('embeds the auto-select guard, observer, and role=button selector', () => {
    const js = autoSelectScript('X');
    expect(js).toContain('__bushaPayAutoSelectDone');
    expect(js).toContain('MutationObserver');
    expect(js).toContain('[role="button"]');
  });

  test('disconnects the observer after a 10 second timeout', () => {
    const js = autoSelectScript('X');
    expect(js).toContain('setTimeout');
    expect(js).toContain('10000');
  });

  test('returns true; at the end so injectJavaScript resolves', () => {
    expect(autoSelectScript('X').trim().endsWith('true;')).toBe(true);
  });
});
