import { afterEach, describe, expect, jest, test } from '@jest/globals';

import {
  handleDeepLink,
  parseCallback,
  registerCallbackHandler,
  setCallbackScheme,
  setDirectLaunchResolver,
} from '../deep-link';
import type { BushaPayResult } from '../result';

const SCHEME = 'co.example.testapp.busha-pay';

afterEach(() => {
  setCallbackScheme('');
  setDirectLaunchResolver(null);
  registerCallbackHandler(null);
});

describe('parseCallback', () => {
  test('returns success for status=completed with paymentRequestId', () => {
    const r = parseCallback(`${SCHEME}://callback?status=completed&paymentRequestId=PAYR_1`);
    expect(r.type).toBe('success');
    expect(r).toMatchObject({
      type: 'success',
      paymentId: 'PAYR_1',
      status: 'completed',
      hasFullData: false,
    });
  });

  test('returns success with empty paymentId when paymentRequestId missing', () => {
    const r = parseCallback(`${SCHEME}://callback?status=completed`);
    expect(r.type).toBe('success');
    if (r.type === 'success') expect(r.paymentId).toBe('');
  });

  test('returns cancelled for status=cancelled', () => {
    expect(parseCallback(`${SCHEME}://callback?status=cancelled`)).toEqual({
      type: 'cancelled',
    });
  });

  test('returns error with explicit error_code/message', () => {
    const r = parseCallback(
      `${SCHEME}://callback?status=failed&error_code=card_declined&error_message=Card%20declined`
    );
    expect(r).toEqual({
      type: 'error',
      message: 'Card declined',
      code: 'card_declined',
    });
  });

  test('falls back to status as the error code when error_code missing', () => {
    const r = parseCallback(`${SCHEME}://callback?status=failed`);
    expect(r).toMatchObject({
      type: 'error',
      message: 'Payment failed',
      code: 'failed',
    });
  });

  test('uses "unknown" code when status and error_code are both missing', () => {
    const r = parseCallback(`${SCHEME}://callback`);
    expect(r).toMatchObject({
      type: 'error',
      message: 'Payment failed',
      code: 'unknown',
    });
  });
});

describe('handleDeepLink', () => {
  test('returns false when no callback scheme is registered', () => {
    expect(handleDeepLink(`${SCHEME}://callback?status=completed`)).toBe(false);
  });

  test('returns false for non-callback URLs', () => {
    setCallbackScheme(SCHEME);
    expect(handleDeepLink('https://example.com/foo')).toBe(false);
    expect(handleDeepLink(`${SCHEME}://other`)).toBe(false);
  });

  test('returns true and dispatches to a registered handler', () => {
    setCallbackScheme(SCHEME);
    const handler = jest.fn();
    registerCallbackHandler(handler);
    const url = `${SCHEME}://callback?status=completed&paymentRequestId=PAYR_1`;
    expect(handleDeepLink(url)).toBe(true);
    expect(handler).toHaveBeenCalledWith(url);
  });

  test('returns true even when no handler is registered (URL is consumed)', () => {
    setCallbackScheme(SCHEME);
    expect(handleDeepLink(`${SCHEME}://callback?status=cancelled`)).toBe(true);
  });

  test('a directLaunchResolver takes priority over the pending handler', () => {
    setCallbackScheme(SCHEME);
    let captured: BushaPayResult | undefined;
    setDirectLaunchResolver((r) => {
      captured = r;
    });
    const handler = jest.fn();
    registerCallbackHandler(handler);

    expect(
      handleDeepLink(
        `${SCHEME}://callback?status=completed&paymentRequestId=PAYR_X`
      )
    ).toBe(true);
    expect(handler).not.toHaveBeenCalled();
    expect(captured?.type).toBe('success');
    if (captured?.type === 'success') expect(captured.paymentId).toBe('PAYR_X');
  });

  test('directLaunchResolver is consumed (one-shot) and a second link goes to the handler', () => {
    setCallbackScheme(SCHEME);
    const direct = jest.fn();
    const handler = jest.fn();
    setDirectLaunchResolver(direct);
    registerCallbackHandler(handler);

    handleDeepLink(`${SCHEME}://callback?status=completed`);
    handleDeepLink(`${SCHEME}://callback?status=cancelled`);

    expect(direct).toHaveBeenCalledTimes(1);
    expect(handler).toHaveBeenCalledTimes(1);
  });

  test('registering null clears the handler', () => {
    setCallbackScheme(SCHEME);
    const handler = jest.fn();
    registerCallbackHandler(handler);
    registerCallbackHandler(null);
    handleDeepLink(`${SCHEME}://callback?status=cancelled`);
    expect(handler).not.toHaveBeenCalled();
  });
});
