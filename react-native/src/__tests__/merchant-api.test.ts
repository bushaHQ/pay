import { describe, expect, jest, test } from '@jest/globals';

import { fetchMerchantName } from '../merchant-api';

type FetchInit = Parameters<typeof fetch>[1];

const mockResponse = (
  status: number,
  body: string | object | null,
  bodyIsJson = true
): Response => {
  const text =
    typeof body === 'string' || body === null
      ? (body ?? '')
      : JSON.stringify(body);
  return {
    status,
    ok: status >= 200 && status < 300,
    json: async () => {
      if (!bodyIsJson) throw new SyntaxError('not json');
      return JSON.parse(text);
    },
    text: async () => text,
  } as unknown as Response;
};

const PLATFORM = 'https://api.busha.io';

describe('fetchMerchantName', () => {
  test('returns username on 200 with data.username present', async () => {
    let capturedUrl = '';
    let capturedHeaders: Record<string, string> = {};
    const fetchImpl: typeof fetch = async (url, init?: FetchInit) => {
      capturedUrl = String(url);
      capturedHeaders = (init?.headers ?? {}) as Record<string, string>;
      return mockResponse(200, { data: { username: 'Pushup Design Agency' } });
    };

    const name = await fetchMerchantName('pub_test', PLATFORM, fetchImpl);

    expect(name).toBe('Pushup Design Agency');
    expect(capturedUrl).toBe(`${PLATFORM}/v1/merchants`);
    expect(capturedHeaders['X-BU-PUBLIC-KEY']).toBe('pub_test');
  });

  test('returns null on non-2xx', async () => {
    const fetchImpl: typeof fetch = async () =>
      mockResponse(404, { error: 'nope' });
    expect(await fetchMerchantName('pub_test', PLATFORM, fetchImpl)).toBeNull();
  });

  test('returns null when body is not JSON', async () => {
    const fetchImpl: typeof fetch = async () =>
      mockResponse(200, '<html>oops</html>', false);
    expect(await fetchMerchantName('pub_test', PLATFORM, fetchImpl)).toBeNull();
  });

  test('returns null when data.username is missing', async () => {
    const fetchImpl: typeof fetch = async () =>
      mockResponse(200, { data: { logo: 'x.png' } });
    expect(await fetchMerchantName('pub_test', PLATFORM, fetchImpl)).toBeNull();
  });

  test('returns null when data.username is empty string', async () => {
    const fetchImpl: typeof fetch = async () =>
      mockResponse(200, { data: { username: '' } });
    expect(await fetchMerchantName('pub_test', PLATFORM, fetchImpl)).toBeNull();
  });

  test('returns null when data.username is not a string', async () => {
    const fetchImpl: typeof fetch = async () =>
      mockResponse(200, { data: { username: 123 } });
    expect(await fetchMerchantName('pub_test', PLATFORM, fetchImpl)).toBeNull();
  });

  test('returns null when data is missing entirely', async () => {
    const fetchImpl: typeof fetch = async () =>
      mockResponse(200, { username: 'x' });
    expect(await fetchMerchantName('pub_test', PLATFORM, fetchImpl)).toBeNull();
  });

  test('returns null when fetch throws', async () => {
    const fetchImpl: typeof fetch = async () => {
      throw new Error('socket exception');
    };
    expect(await fetchMerchantName('pub_test', PLATFORM, fetchImpl)).toBeNull();
  });

  test('returns null when the request times out', async () => {
    jest.useFakeTimers();
    let aborted = false;
    const fetchImpl: typeof fetch = (_url, init?: FetchInit) =>
      new Promise<Response>((resolve, reject) => {
        init?.signal?.addEventListener('abort', () => {
          aborted = true;
          const err = new Error('aborted');
          err.name = 'AbortError';
          reject(err);
        });
        setTimeout(
          () => resolve(mockResponse(200, { data: { username: 'slow' } })),
          10000
        );
      });

    const promise = fetchMerchantName('pub_test', PLATFORM, fetchImpl);
    jest.advanceTimersByTime(5001);
    const name = await promise;
    expect(name).toBeNull();
    expect(aborted).toBe(true);
    jest.useRealTimers();
  });

  test('uses the sandbox host when sandbox platformUrl passed', async () => {
    let capturedUrl = '';
    const fetchImpl: typeof fetch = async (url) => {
      capturedUrl = String(url);
      return mockResponse(200, { data: { username: 'Sandbox Co' } });
    };
    const name = await fetchMerchantName(
      'pub_sb',
      'https://api.sandbox.busha.so',
      fetchImpl
    );
    expect(name).toBe('Sandbox Co');
    expect(capturedUrl).toBe('https://api.sandbox.busha.so/v1/merchants');
  });
});
