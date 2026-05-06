import {
  afterEach,
  beforeEach,
  describe,
  expect,
  jest,
  test,
} from '@jest/globals';

let mockApplicationId: string | null = 'co.example.testapp';
let mockPlatformOs: 'ios' | 'android' | 'web' = 'ios';
const mockOpenURL = jest.fn(async (_url: string) => {});
const mockCanOpenURL = jest.fn(async (_url: string) => true);
let mockAppStateListener: ((next: string) => void) | null = null;

jest.mock('expo-application', () => ({
  get applicationId() {
    return mockApplicationId;
  },
}));

jest.mock('react-native', () => ({
  Platform: {
    get OS() {
      return mockPlatformOs;
    },
  },
  Linking: {
    openURL: (url: string) => mockOpenURL(url),
    canOpenURL: (url: string) => mockCanOpenURL(url),
  },
  AppState: {
    addEventListener: (_evt: string, listener: (next: string) => void) => {
      mockAppStateListener = listener;
      return { remove: () => (mockAppStateListener = null) };
    },
  },
}));

const loadSdk = (): typeof import('../sdk') => {
  return require('../sdk');
};

beforeEach(() => {
  jest.resetModules();
  mockApplicationId = 'co.example.testapp';
  mockPlatformOs = 'ios';
  mockOpenURL.mockClear();
  mockCanOpenURL.mockClear();
  mockAppStateListener = null;
});

afterEach(() => {
  jest.useRealTimers();
});

describe('init', () => {
  test('marks the SDK as initialized and stores the public key', () => {
    const { BushaPay } = loadSdk();
    expect(BushaPay.isInitialized).toBe(false);
    BushaPay.init({ publicKey: 'pub_x' });
    expect(BushaPay.isInitialized).toBe(true);
    expect(BushaPay.publicKey).toBe('pub_x');
  });

  test('defaults to live environment with live URLs', () => {
    const { BushaPay } = loadSdk();
    BushaPay.init({ publicKey: 'pub_x' });
    expect(BushaPay.environment).toBe('live');
    expect(BushaPay.isDevMode).toBe(false);
    expect(BushaPay.checkoutUrl).toBe('https://pay.busha.io/pay');
    expect(BushaPay.platformUrl).toBe('https://api.busha.io');
  });

  test('respects sandbox environment with sandbox URLs', () => {
    const { BushaPay } = loadSdk();
    BushaPay.init({ publicKey: 'pub_sb', environment: 'sandbox' });
    expect(BushaPay.isDevMode).toBe(true);
    expect(BushaPay.checkoutUrl).toBe('https://staging.pay.busha.io/pay');
    expect(BushaPay.platformUrl).toBe('https://api.sandbox.busha.so');
  });

  test('derives callbackScheme + callbackUrl from the bundle id', () => {
    const { BushaPay } = loadSdk();
    BushaPay.init({ publicKey: 'pub_x' });
    expect(BushaPay.callbackScheme).toBe('co.example.testapp.busha-pay');
    expect(BushaPay.callbackUrl).toBe(
      'co.example.testapp.busha-pay://callback'
    );
  });

  test('throws when expo-application cannot resolve a bundle id', () => {
    mockApplicationId = null;
    const { BushaPay } = loadSdk();
    expect(() => BushaPay.init({ publicKey: 'pub_x' })).toThrow(
      /could not detect the app bundle ID/i
    );
  });

  test('getters throw before init', () => {
    const { BushaPay } = loadSdk();
    expect(() => BushaPay.publicKey).toThrow(/init\(\) must be called/);
    expect(() => BushaPay.environment).toThrow(/init\(\) must be called/);
  });

  test('resetForTesting wipes state', () => {
    const { BushaPay } = loadSdk();
    BushaPay.init({ publicKey: 'pub_x' });
    BushaPay.resetForTesting();
    expect(BushaPay.isInitialized).toBe(false);
  });
});

describe('handleDeepLink', () => {
  test('returns false for non-callback URIs', () => {
    const { BushaPay } = loadSdk();
    BushaPay.init({ publicKey: 'pub_x' });
    expect(BushaPay.handleDeepLink('https://example.com/foo')).toBe(false);
    expect(
      BushaPay.handleDeepLink('co.example.testapp.busha-pay://other')
    ).toBe(false);
  });

  test('returns true for a callback URI', () => {
    const { BushaPay } = loadSdk();
    BushaPay.init({ publicKey: 'pub_x' });
    expect(
      BushaPay.handleDeepLink(
        'co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_1'
      )
    ).toBe(true);
  });

  test('does not consume callbacks before init (no scheme registered)', () => {
    const { BushaPay } = loadSdk();
    expect(
      BushaPay.handleDeepLink(
        'co.example.testapp.busha-pay://callback?status=completed'
      )
    ).toBe(false);
  });
});

describe('buildBushaAppDeepLink', () => {
  const baseConfig = {
    quoteAmount: '10000',
    quoteCurrency: 'NGN',
    targetCurrency: 'NGN',
    sourceCurrency: 'USDT',
  };

  test('returns null before init', () => {
    const { buildBushaAppDeepLink } = loadSdk();
    expect(buildBushaAppDeepLink(baseConfig)).toBeNull();
  });

  test('returns null on unsupported platforms (no scheme)', () => {
    mockPlatformOs = 'web';
    const sdk = loadSdk();
    sdk.BushaPay.init({ publicKey: 'pub_x' });
    expect(sdk.buildBushaAppDeepLink(baseConfig)).toBeNull();
  });

  test('builds a deep link for iOS live', () => {
    mockPlatformOs = 'ios';
    const sdk = loadSdk();
    sdk.BushaPay.init({ publicKey: 'pub_x' });
    const url = sdk.buildBushaAppDeepLink(baseConfig);
    expect(url).not.toBeNull();
    expect(url!.startsWith('co.busha.apple://busha.co/pay?')).toBe(true);
    expect(url).toContain('public_key=pub_x');
    expect(url).toContain('quote_amount=10000');
    expect(url).toContain('quote_currency=NGN');
    expect(url).toContain(
      'callback_url=co.example.testapp.busha-pay%3A%2F%2Fcallback'
    );
  });

  test('builds a deep link for Android sandbox', () => {
    mockPlatformOs = 'android';
    const sdk = loadSdk();
    sdk.BushaPay.init({ publicKey: 'pub_sb', environment: 'sandbox' });
    const url = sdk.buildBushaAppDeepLink(baseConfig);
    expect(
      url!.startsWith('co.busha.android.development://busha.co/pay?')
    ).toBe(true);
  });

  test('omits reference when not provided', () => {
    const sdk = loadSdk();
    sdk.BushaPay.init({ publicKey: 'pub_x' });
    const url = sdk.buildBushaAppDeepLink(baseConfig);
    expect(url!.includes('reference=')).toBe(false);
  });

  test('includes reference when provided', () => {
    const sdk = loadSdk();
    sdk.BushaPay.init({ publicKey: 'pub_x' });
    const url = sdk.buildBushaAppDeepLink({
      ...baseConfig,
      reference: 'ref-1',
    });
    expect(url!.includes('reference=ref-1')).toBe(true);
  });
});

describe('canOpenBushaApp', () => {
  test('returns whatever Linking.canOpenURL resolves with', async () => {
    const { canOpenBushaApp } = loadSdk();
    mockCanOpenURL.mockImplementationOnce(async () => true);
    expect(await canOpenBushaApp('co.busha.apple://x')).toBe(true);
    mockCanOpenURL.mockImplementationOnce(async () => false);
    expect(await canOpenBushaApp('co.busha.apple://x')).toBe(false);
  });

  test('returns false if Linking throws', async () => {
    const { canOpenBushaApp } = loadSdk();
    mockCanOpenURL.mockImplementationOnce(async () => {
      throw new Error('boom');
    });
    expect(await canOpenBushaApp('co.busha.apple://x')).toBe(false);
  });
});

describe('launchBushaApp', () => {
  test('opens the deep link via Linking.openURL', async () => {
    const { launchBushaApp, BushaPay } = loadSdk();
    BushaPay.init({ publicKey: 'pub_x' });
    const promise = launchBushaApp('co.busha.apple://x');
    // Prevent the test from hanging — fire a callback to settle it.
    BushaPay.handleDeepLink(
      'co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=P'
    );
    const result = await promise;
    expect(mockOpenURL).toHaveBeenCalledWith('co.busha.apple://x');
    expect(result).toMatchObject({ type: 'success', paymentId: 'P' });
  });

  test('resolves with cancelled if the app comes back active without a callback', async () => {
    jest.useFakeTimers();
    const { launchBushaApp, BushaPay } = loadSdk();
    BushaPay.init({ publicKey: 'pub_x' });
    const promise = launchBushaApp('co.busha.apple://x');
    expect(mockAppStateListener).not.toBeNull();
    mockAppStateListener!('active');
    jest.advanceTimersByTime(1500);
    const result = await promise;
    expect(result).toEqual({ type: 'cancelled' });
  });

  test('resolves with an error result when openURL throws', async () => {
    const { launchBushaApp, BushaPay } = loadSdk();
    BushaPay.init({ publicKey: 'pub_x' });
    mockOpenURL.mockImplementationOnce(async () => {
      throw new Error('cannot open');
    });
    const result = await launchBushaApp('co.busha.apple://x');
    expect(result).toMatchObject({
      type: 'error',
      message: 'cannot open',
      code: 'launch_failed',
    });
  });
});
