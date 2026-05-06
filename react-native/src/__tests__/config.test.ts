import { describe, expect, test } from '@jest/globals';

import type { BushaPayConfig } from '../config';
import { toFormFields } from '../config';

const baseConfig: BushaPayConfig = {
  quoteAmount: '10000',
  quoteCurrency: 'NGN',
  targetCurrency: 'NGN',
  sourceCurrency: 'USDT',
};

const baseOpts = {
  publicKey: 'pk',
  callbackUrl: 'co.example.busha-pay://callback',
  checkoutUrl: 'https://pay.busha.io/pay',
};

describe('toFormFields', () => {
  test('emits the required fields', () => {
    const fields = toFormFields(baseConfig, baseOpts);
    expect(fields.public_key).toBe('pk');
    expect(fields.quote_amount).toBe('10000');
    expect(fields.quote_currency).toBe('NGN');
    expect(fields.target_currency).toBe('NGN');
    expect(fields.source_currency).toBe('USDT');
    expect(fields.callback_url).toBe('co.example.busha-pay://callback');
  });

  test('uses INLINE display mode', () => {
    expect(toFormFields(baseConfig, baseOpts).displayMode).toBe('INLINE');
  });

  test('derives parentOrigin from the checkout URL origin', () => {
    expect(toFormFields(baseConfig, baseOpts).parentOrigin).toBe(
      'https://pay.busha.io'
    );
  });

  test('parentOrigin includes the port for non-default ports', () => {
    const fields = toFormFields(baseConfig, {
      ...baseOpts,
      checkoutUrl: 'http://localhost:3000/pay',
    });
    expect(fields.parentOrigin).toBe('http://localhost:3000');
  });

  test('omits null/undefined optionals', () => {
    const fields = toFormFields(baseConfig, baseOpts);
    expect(fields).not.toHaveProperty('reference');
    expect(fields).not.toHaveProperty('meta[name]');
    expect(fields).not.toHaveProperty('meta[email]');
    expect(fields).not.toHaveProperty('meta[phone_number]');
  });

  test('omits empty-string optionals', () => {
    const fields = toFormFields(
      { ...baseConfig, reference: '', metaName: '' },
      baseOpts
    );
    expect(fields).not.toHaveProperty('reference');
    expect(fields).not.toHaveProperty('meta[name]');
  });

  test('includes reference when set', () => {
    const fields = toFormFields(
      { ...baseConfig, reference: 'ref-1' },
      baseOpts
    );
    expect(fields.reference).toBe('ref-1');
  });

  test('includes meta fields with bracketed keys', () => {
    const fields = toFormFields(
      {
        ...baseConfig,
        metaName: 'Alice',
        metaEmail: 'a@b.co',
        metaPhone: '+2348000',
      },
      baseOpts
    );
    expect(fields['meta[name]']).toBe('Alice');
    expect(fields['meta[email]']).toBe('a@b.co');
    expect(fields['meta[phone_number]']).toBe('+2348000');
  });
});
