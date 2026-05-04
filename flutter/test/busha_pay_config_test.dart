import 'package:busha_pay/busha_pay_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseConfig = BushaPayConfig(
    quoteAmount: '10000',
    quoteCurrency: 'NGN',
    targetCurrency: 'NGN',
    sourceCurrency: 'USDT',
  );

  group('copyWith', () {
    test('returns identical fields when no overrides given', () {
      final copy = baseConfig.copyWith();
      expect(copy.quoteAmount, baseConfig.quoteAmount);
      expect(copy.quoteCurrency, baseConfig.quoteCurrency);
      expect(copy.targetCurrency, baseConfig.targetCurrency);
      expect(copy.sourceCurrency, baseConfig.sourceCurrency);
      expect(copy.reference, isNull);
      expect(copy.metaName, isNull);
    });

    test('overrides only the provided fields', () {
      final copy = baseConfig.copyWith(quoteAmount: '20000', metaEmail: 'a@b.co');
      expect(copy.quoteAmount, '20000');
      expect(copy.metaEmail, 'a@b.co');
      expect(copy.quoteCurrency, baseConfig.quoteCurrency);
      expect(copy.metaName, isNull);
    });

    test('preserves existing optional fields when not overridden', () {
      const seeded = BushaPayConfig(
        quoteAmount: '1',
        quoteCurrency: 'NGN',
        targetCurrency: 'NGN',
        sourceCurrency: 'USDT',
        reference: 'ref-1',
        metaName: 'Alice',
      );
      final copy = seeded.copyWith(quoteAmount: '2');
      expect(copy.reference, 'ref-1');
      expect(copy.metaName, 'Alice');
    });
  });

  group('toCommerceJson', () {
    test('emits required fields', () {
      final json = baseConfig.toCommerceJson(
        publicKey: 'pub_test',
        devMode: true,
        callbackUrl: 'co.example.busha-pay://callback',
      );
      expect(json['public_key'], 'pub_test');
      expect(json['quote_amount'], '10000');
      expect(json['quote_currency'], 'NGN');
      expect(json['target_currency'], 'NGN');
      expect(json['source_currency'], 'USDT');
      expect(json['callback_url'], 'co.example.busha-pay://callback');
      expect(json['devMode'], true);
    });

    test('omits null optional fields', () {
      final json = baseConfig.toCommerceJson(publicKey: 'pub_test', devMode: false, callbackUrl: 'cb://callback');
      expect(json.containsKey('reference'), isFalse);
      expect(json['meta'], isA<Map>());
      final meta = json['meta'] as Map;
      expect(meta.containsKey('name'), isFalse);
      expect(meta.containsKey('email'), isFalse);
      expect(meta.containsKey('phone_number'), isFalse);
    });

    test('includes all optional fields when set', () {
      const c = BushaPayConfig(
        quoteAmount: '500',
        quoteCurrency: 'NGN',
        targetCurrency: 'NGN',
        sourceCurrency: 'USDT',
        reference: 'ref-9',
        metaName: 'Alice',
        metaEmail: 'a@b.co',
        metaPhone: '+2348000000000',
      );
      final json = c.toCommerceJson(publicKey: 'pk', devMode: false, callbackUrl: 'cb://cb');
      expect(json['reference'], 'ref-9');
      final meta = json['meta'] as Map;
      expect(meta['name'], 'Alice');
      expect(meta['email'], 'a@b.co');
      expect(meta['phone_number'], '+2348000000000');
    });
  });

  group('toFormFields', () {
    test('derives parentOrigin from checkoutUrl origin', () {
      final fields = baseConfig.toFormFields(
        publicKey: 'pk',
        callbackUrl: 'cb://cb',
        checkoutUrl: 'https://pay.busha.co/pay',
      );
      expect(fields['parentOrigin'], 'https://pay.busha.co');
    });

    test('uses INLINE display mode', () {
      final fields = baseConfig.toFormFields(publicKey: 'pk', callbackUrl: 'cb', checkoutUrl: 'https://x.co/p');
      expect(fields['displayMode'], 'INLINE');
    });

    test('omits null optionals', () {
      final fields = baseConfig.toFormFields(
        publicKey: 'pk',
        callbackUrl: 'cb',
        checkoutUrl: 'https://pay.busha.co/pay',
      );
      expect(fields.containsKey('reference'), isFalse);
      expect(fields.containsKey('meta[name]'), isFalse);
    });

    test('includes meta fields with bracketed keys when set', () {
      const c = BushaPayConfig(
        quoteAmount: '500',
        quoteCurrency: 'NGN',
        targetCurrency: 'NGN',
        sourceCurrency: 'USDT',
        metaName: 'Alice',
        metaEmail: 'a@b.co',
        metaPhone: '+2348000',
      );
      final fields = c.toFormFields(publicKey: 'pk', callbackUrl: 'cb', checkoutUrl: 'https://x.co/p');
      expect(fields['meta[name]'], 'Alice');
      expect(fields['meta[email]'], 'a@b.co');
      expect(fields['meta[phone_number]'], '+2348000');
    });
  });
}
