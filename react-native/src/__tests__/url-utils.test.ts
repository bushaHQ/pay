import { describe, expect, test } from '@jest/globals';

import { encodeQuery, getOrigin, parseUrl } from '../url-utils';

describe('encodeQuery', () => {
  test('encodes a single param', () => {
    expect(encodeQuery({ a: '1' })).toBe('a=1');
  });

  test('joins multiple params with &', () => {
    expect(encodeQuery({ a: '1', b: '2' })).toBe('a=1&b=2');
  });

  test('percent-encodes keys and values', () => {
    expect(encodeQuery({ 'k k': 'v v', 'a&b': 'c=d' })).toBe(
      'k%20k=v%20v&a%26b=c%3Dd'
    );
  });

  test('returns empty string for empty input', () => {
    expect(encodeQuery({})).toBe('');
  });
});

describe('getOrigin', () => {
  test('extracts scheme + host from an absolute URL', () => {
    expect(getOrigin('https://pay.busha.io/pay')).toBe('https://pay.busha.io');
  });

  test('preserves port when present', () => {
    expect(getOrigin('http://localhost:3000/foo')).toBe(
      'http://localhost:3000'
    );
  });

  test('returns the input unchanged when no scheme is present', () => {
    expect(getOrigin('not-a-url')).toBe('not-a-url');
  });

  test('handles custom schemes', () => {
    expect(getOrigin('co.example.busha-pay://callback?x=1')).toBe(
      'co.example.busha-pay://callback'
    );
  });
});

describe('parseUrl', () => {
  test('returns null for an unparseable string', () => {
    expect(parseUrl('not a url')).toBeNull();
  });

  test('parses scheme, host, path', () => {
    const p = parseUrl('https://pay.busha.io/pay/checkout');
    expect(p).not.toBeNull();
    expect(p!.scheme).toBe('https');
    expect(p!.host).toBe('pay.busha.io');
    expect(p!.path).toBe('/pay/checkout');
    expect(p!.query).toEqual({});
  });

  test('lowercases the scheme', () => {
    expect(parseUrl('HTTPS://x.co/')!.scheme).toBe('https');
  });

  test('decodes query parameters', () => {
    const p = parseUrl(
      'co.example.busha-pay://callback?status=completed&paymentRequestId=PAYR_1'
    );
    expect(p!.query).toEqual({
      status: 'completed',
      paymentRequestId: 'PAYR_1',
    });
  });

  test('decodes percent-encoded values', () => {
    const p = parseUrl('https://x.co/?msg=hello%20world&k%26v=a%3Db');
    expect(p!.query.msg).toBe('hello world');
    expect(p!.query['k&v']).toBe('a=b');
  });

  test('treats keys without = as empty values', () => {
    const p = parseUrl('https://x.co/?flag&k=v');
    expect(p!.query.flag).toBe('');
    expect(p!.query.k).toBe('v');
  });

  test('skips empty pairs from trailing ampersands', () => {
    const p = parseUrl('https://x.co/?a=1&&b=2');
    expect(p!.query).toEqual({ a: '1', b: '2' });
  });

  test('falls back to raw key/value when decoding throws', () => {
    const p = parseUrl('https://x.co/?bad=%E0%A4%A');
    expect(p!.query.bad).toBe('%E0%A4%A');
  });

  test('strips fragments from the query', () => {
    const p = parseUrl('https://x.co/p?a=1#frag');
    expect(p!.query).toEqual({ a: '1' });
  });

  test('parses custom-scheme callback URLs', () => {
    const p = parseUrl(
      'co.example.testapp.busha-pay://callback?status=cancelled'
    );
    expect(p!.scheme).toBe('co.example.testapp.busha-pay');
    expect(p!.host).toBe('callback');
    expect(p!.query.status).toBe('cancelled');
  });
});
