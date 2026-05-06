import { afterEach, describe, expect, jest, test } from '@jest/globals';

import {
  getBushaAppScheme,
  getCheckoutUrl,
  getPlatformUrl,
} from '../environment';

afterEach(() => {
  jest.resetModules();
});

describe('getCheckoutUrl', () => {
  test('returns the live checkout URL by default', () => {
    expect(getCheckoutUrl('live')).toBe('https://pay.busha.io/pay');
  });

  test('returns the staging checkout URL for sandbox', () => {
    expect(getCheckoutUrl('sandbox')).toBe('https://staging.pay.busha.io/pay');
  });
});

describe('getPlatformUrl', () => {
  test('returns the production API host for live', () => {
    expect(getPlatformUrl('live')).toBe('https://api.busha.io');
  });

  test('returns the sandbox API host for sandbox', () => {
    expect(getPlatformUrl('sandbox')).toBe('https://api.sandbox.busha.so');
  });
});

describe('getBushaAppScheme', () => {
  const loadWithPlatform = (
    os: 'ios' | 'android' | 'web' | 'macos' | 'windows'
  ): typeof import('../environment').getBushaAppScheme => {
    jest.resetModules();
    jest.doMock('react-native', () => ({ Platform: { OS: os } }));

    return require('../environment').getBushaAppScheme;
  };

  test('iOS live → co.busha.apple', () => {
    expect(loadWithPlatform('ios')('live')).toBe('co.busha.apple');
  });

  test('iOS sandbox → co.busha.boro.development', () => {
    expect(loadWithPlatform('ios')('sandbox')).toBe(
      'co.busha.boro.development'
    );
  });

  test('Android live → co.busha.android', () => {
    expect(loadWithPlatform('android')('live')).toBe('co.busha.android');
  });

  test('Android sandbox → co.busha.android.development', () => {
    expect(loadWithPlatform('android')('sandbox')).toBe(
      'co.busha.android.development'
    );
  });

  test('unsupported platforms → null', () => {
    expect(loadWithPlatform('web')('live')).toBeNull();
    expect(loadWithPlatform('macos')('live')).toBeNull();
    expect(loadWithPlatform('windows')('live')).toBeNull();
  });

  test('the default-export getBushaAppScheme is callable (smoke)', () => {
    expect(typeof getBushaAppScheme).toBe('function');
  });
});
