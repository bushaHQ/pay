import { describe, expect, test } from '@jest/globals';

import type { BushaPayResult } from '../result';
import {
  cancelled,
  errorResult,
  successFromCallback,
  successFromCheckoutData,
} from '../result';

describe('successFromCallback', () => {
  test('builds a minimal success with status=completed and hasFullData=false', () => {
    const r = successFromCallback('PAYR_1');
    expect(r.type).toBe('success');
    expect(r.paymentId).toBe('PAYR_1');
    expect(r.status).toBe('completed');
    expect(r.hasFullData).toBe(false);
    expect(r.rawData).toBeUndefined();
    expect(r.sourceAmount).toBeUndefined();
  });
});

describe('successFromCheckoutData', () => {
  test('reads id/status from a `data` envelope and copies all known fields', () => {
    const r = successFromCheckoutData({
      data: {
        id: 'PAYR_2',
        status: 'completed',
        source_amount: '0.0001',
        source_currency: 'BTC',
        target_amount: '13.42',
        target_currency: 'USDT',
        requested_amount: '10',
        currency: 'NGN',
        rate: { value: 1.0 },
        merchant_info: { name: 'Acme' },
        timeline: { steps: [] },
      },
    });
    expect(r.paymentId).toBe('PAYR_2');
    expect(r.status).toBe('completed');
    expect(r.sourceAmount).toBe('0.0001');
    expect(r.sourceCurrency).toBe('BTC');
    expect(r.targetAmount).toBe('13.42');
    expect(r.targetCurrency).toBe('USDT');
    expect(r.requestedAmount).toBe('10');
    expect(r.currency).toBe('NGN');
    expect(r.rate).toEqual({ value: 1.0 });
    expect(r.merchantInfo).toEqual({ name: 'Acme' });
    expect(r.timeline).toEqual({ steps: [] });
    expect(r.hasFullData).toBe(true);
    expect(r.rawData).not.toBeUndefined();
  });

  test('falls back to top-level fields when no `data` envelope', () => {
    const r = successFromCheckoutData({
      id: 'PAYR_3',
      status: 'completed',
    });
    expect(r.paymentId).toBe('PAYR_3');
    expect(r.status).toBe('completed');
  });

  test('falls back to reference when id missing', () => {
    const r = successFromCheckoutData({
      data: { reference: 'ref-x', status: 'completed' },
    });
    expect(r.paymentId).toBe('ref-x');
  });

  test('defaults paymentId to empty string and status to "completed" when both missing', () => {
    const r = successFromCheckoutData({ data: {} });
    expect(r.paymentId).toBe('');
    expect(r.status).toBe('completed');
  });

  test('preserves the original payload as rawData', () => {
    const payload = { data: { id: 'X' }, extra: 'meta' };
    const r = successFromCheckoutData(payload);
    expect(r.rawData).toBe(payload);
  });
});

describe('cancelled', () => {
  test('builds a cancelled variant', () => {
    expect(cancelled()).toEqual({ type: 'cancelled' });
  });
});

describe('errorResult', () => {
  test('captures message and code', () => {
    expect(errorResult('boom', 'E1')).toEqual({
      type: 'error',
      message: 'boom',
      code: 'E1',
    });
  });

  test('omits code when not provided', () => {
    const r = errorResult('boom');
    expect(r.message).toBe('boom');
    expect(r.code).toBeUndefined();
  });
});

describe('discriminated union', () => {
  test('every variant is exhaustively narrowable by the `type` tag', () => {
    const cases: BushaPayResult[] = [
      successFromCallback('p'),
      cancelled(),
      errorResult('oops', 'E1'),
    ];
    const labelOf = (r: BushaPayResult): string => {
      switch (r.type) {
        case 'success':
          return 'success';
        case 'cancelled':
          return 'cancelled';
        case 'error':
          return 'error';
      }
    };
    expect(cases.map(labelOf)).toEqual(['success', 'cancelled', 'error']);
  });
});
