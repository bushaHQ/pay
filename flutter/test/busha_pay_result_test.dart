import 'package:busha_pay/busha_pay_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BushaPaySuccess.fromCallback', () {
    test('builds a minimal success with status=completed', () {
      final result = BushaPaySuccess.fromCallback(paymentId: 'PAYR_1');
      expect(result.paymentId, 'PAYR_1');
      expect(result.status, 'completed');
      expect(result.hasFullData, isFalse);
      expect(result.rawData, isNull);
      expect(result.sourceAmount, isNull);
    });
  });

  group('BushaPaySuccess.fromCommerceJs', () {
    test('reads id/status from a `data` envelope', () {
      final r = BushaPaySuccess.fromCommerceJs({
        'data': {
          'id': 'PAYR_2',
          'status': 'completed',
          'source_amount': '0.0001',
          'source_currency': 'BTC',
          'target_amount': '13.42',
          'target_currency': 'USDT',
          'requested_amount': '10',
          'currency': 'NGN',
          'rate': {'value': 1.0},
          'merchant_info': {'name': 'Acme'},
          'timeline': {'steps': []},
        },
      });
      expect(r.paymentId, 'PAYR_2');
      expect(r.status, 'completed');
      expect(r.sourceAmount, '0.0001');
      expect(r.sourceCurrency, 'BTC');
      expect(r.targetAmount, '13.42');
      expect(r.targetCurrency, 'USDT');
      expect(r.requestedAmount, '10');
      expect(r.currency, 'NGN');
      expect(r.rate, isA<Map<String, dynamic>>());
      expect(r.merchantInfo, isA<Map<String, dynamic>>());
      expect(r.timeline, isA<Map<String, dynamic>>());
      expect(r.hasFullData, isTrue);
      expect(r.rawData, isNotNull);
    });

    test('falls back to top-level fields when no `data` envelope', () {
      final r = BushaPaySuccess.fromCommerceJs({'id': 'PAYR_3', 'status': 'completed'});
      expect(r.paymentId, 'PAYR_3');
      expect(r.status, 'completed');
    });

    test('falls back to reference when id missing', () {
      final r = BushaPaySuccess.fromCommerceJs({
        'data': {'reference': 'ref-x', 'status': 'completed'},
      });
      expect(r.paymentId, 'ref-x');
    });

    test('defaults paymentId to empty and status to completed when both missing', () {
      final r = BushaPaySuccess.fromCommerceJs({'data': <String, dynamic>{}});
      expect(r.paymentId, '');
      expect(r.status, 'completed');
    });
  });

  test('sealed-class switch covers all variants', () {
    final cases = <BushaPayResult>[
      BushaPaySuccess.fromCallback(paymentId: 'p'),
      const BushaPayCancelled(),
      const BushaPayError(message: 'oops', code: 'E1'),
    ];
    for (final r in cases) {
      final tag = switch (r) {
        BushaPaySuccess() => 'success',
        BushaPayCancelled() => 'cancelled',
        BushaPayError() => 'error',
      };
      expect(tag, isNotEmpty);
    }
  });

  test('toString includes key fields', () {
    expect(BushaPaySuccess.fromCallback(paymentId: 'PAYR_X').toString(), contains('PAYR_X'));
    expect(const BushaPayCancelled().toString(), contains('dismissed'));
    expect(const BushaPayError(message: 'm', code: 'c').toString(), contains('m'));
  });

  group('BushaPayCancelled', () {
    test('defaults to the dismissed reason with no paymentId', () {
      const cancelled = BushaPayCancelled();
      expect(cancelled.reason, BushaPayCancelledReason.dismissed);
      expect(cancelled.paymentId, isNull);
    });

    test('carries the rejected reason and paymentId', () {
      const cancelled = BushaPayCancelled(reason: BushaPayCancelledReason.rejected, paymentId: 'PAYR_42');
      expect(cancelled.reason, BushaPayCancelledReason.rejected);
      expect(cancelled.paymentId, 'PAYR_42');
    });

    test('carries the abandoned reason with no paymentId', () {
      const cancelled = BushaPayCancelled(reason: BushaPayCancelledReason.abandoned);
      expect(cancelled.reason, BushaPayCancelledReason.abandoned);
      expect(cancelled.paymentId, isNull);
    });

    test('toString surfaces the reason and paymentId', () {
      expect(
        const BushaPayCancelled(reason: BushaPayCancelledReason.rejected, paymentId: 'PAYR_9').toString(),
        'BushaPayCancelled(reason: rejected, paymentId: PAYR_9)',
      );
    });
  });
}
