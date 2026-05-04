import 'package:busha_pay/src/scripts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('document-start scripts', () {
    test('bridge shim defines window.BushaPayBridge', () {
      expect(bushaPayBridgeShim, contains('window.BushaPayBridge'));
      expect(bushaPayBridgeShim, contains('flutter_inappwebview'));
    });

    test('message listener routes statuses to bridge payload types', () {
      expect(messageListenerScript, contains("status === 'INITIALIZED'"));
      expect(messageListenerScript, contains("status === 'CANCELLED'"));
      expect(messageListenerScript, contains("status === 'COMPLETED'"));
      expect(messageListenerScript, contains("type: 'ready'"));
      expect(messageListenerScript, contains("type: 'close'"));
      expect(messageListenerScript, contains("type: 'success'"));
    });

    test('deep-link enabler removes navigator.getInstalledRelatedApps', () {
      expect(deepLinkEnablerScript, contains('delete navigator.getInstalledRelatedApps'));
      expect(deepLinkEnablerScript, contains('configurable: true'));
    });
  });

  group('autoSelectScript', () {
    test('JSON-encodes the prefix as a JS string literal', () {
      final js = autoSelectScript('Busha');
      expect(js, contains('var target = "Busha"'));
    });

    test('escapes embedded quotes safely', () {
      final js = autoSelectScript('She said "hi"');
      expect(js, contains(r'var target = "She said \"hi\""'));
    });

    test('embeds the auto-select guard and observer', () {
      final js = autoSelectScript('X');
      expect(js, contains('__bushaPayAutoSelectDone'));
      expect(js, contains('MutationObserver'));
      expect(js, contains("[role=\"button\"]"));
    });

    test('clears the observer after a 10 second timeout', () {
      final js = autoSelectScript('X');
      expect(js, contains('setTimeout'));
      expect(js, contains('10000'));
    });
  });
}
