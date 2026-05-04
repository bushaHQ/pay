import 'package:busha_pay/busha_pay_result.dart';
import 'package:busha_pay/src/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBridgeMessage', () {
    test("'ready' returns BridgeReady", () {
      final r = parseBridgeMessage('{"type":"ready","data":{}}');
      expect(r, isA<BridgeReady>());
    });

    test("'success' wraps the data in a BushaPaySuccess", () {
      final r = parseBridgeMessage(
        '{"type":"success","data":{"id":"PAYR_1","status":"completed","source_amount":"0.001"}}',
      );
      expect(r, isA<BridgeResult>());
      final result = (r as BridgeResult).result;
      expect(result, isA<BushaPaySuccess>());
      expect((result as BushaPaySuccess).paymentId, 'PAYR_1');
      expect(result.sourceAmount, '0.001');
    });

    test("'success' with non-map data is unknown", () {
      final r = parseBridgeMessage('{"type":"success","data":"oops"}');
      expect(r, isA<BridgeUnknown>());
    });

    test("'close' returns a BushaPayCancelled regardless of data", () {
      final r = parseBridgeMessage('{"type":"close","data":{"reason":"user"}}');
      expect(r, isA<BridgeResult>());
      expect((r as BridgeResult).result, isA<BushaPayCancelled>());
    });

    test("'error' uses message and code from data", () {
      final r = parseBridgeMessage(
        '{"type":"error","data":{"message":"network down","code":"NET_ERR"}}',
      );
      expect(r, isA<BridgeResult>());
      final result = (r as BridgeResult).result;
      expect(result, isA<BushaPayError>());
      expect((result as BushaPayError).message, 'network down');
      expect(result.code, 'NET_ERR');
    });

    test("'error' with missing data falls back to a default message", () {
      final r = parseBridgeMessage('{"type":"error"}');
      expect(r, isA<BridgeResult>());
      final result = ((r as BridgeResult).result) as BushaPayError;
      expect(result.message, 'An error occurred');
      expect(result.code, isNull);
    });

    test("'error' with non-map data still yields a default error", () {
      final r = parseBridgeMessage('{"type":"error","data":42}');
      expect(r, isA<BridgeResult>());
      final result = ((r as BridgeResult).result) as BushaPayError;
      expect(result.message, 'An error occurred');
    });

    test('unknown type returns BridgeUnknown', () {
      expect(parseBridgeMessage('{"type":"weird","data":{}}'), isA<BridgeUnknown>());
    });

    test('non-JSON input returns BridgeUnknown', () {
      expect(parseBridgeMessage('<html>oops</html>'), isA<BridgeUnknown>());
    });

    test('top-level array returns BridgeUnknown', () {
      expect(parseBridgeMessage('[1,2,3]'), isA<BridgeUnknown>());
    });

    test('missing type field returns BridgeUnknown', () {
      expect(parseBridgeMessage('{"data":{}}'), isA<BridgeUnknown>());
    });
  });

  group('isWebScheme', () {
    test('returns true for in-WebView schemes', () {
      for (final s in ['http', 'https', 'about', 'data', 'blob']) {
        expect(isWebScheme(s), isTrue, reason: s);
      }
    });

    test('returns false for OS-handled schemes', () {
      for (final s in ['mailto', 'tel', 'sms', 'co.example.busha-pay']) {
        expect(isWebScheme(s), isFalse, reason: s);
      }
    });
  });
}
