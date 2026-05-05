import * as Application from 'expo-application';
import { AppState, Linking } from 'react-native';

import type { BushaPayConfig } from './config';
import type { BushaEnvironment } from './environment';
import {
  getBushaAppScheme,
  getCheckoutUrl,
  getPlatformUrl,
} from './environment';
import type { BushaPayResult } from './result';
import { cancelled, errorResult } from './result';
import {
  handleDeepLink as handleDeepLinkInternal,
  setCallbackScheme,
  setDirectLaunchResolver,
} from './deep-link';
import { encodeQuery } from './url-utils';

export type InitOptions = {
  /** Busha Pay public key (starts with `pub_`). */
  publicKey: string;
  /** Defaults to `'live'`. */
  environment?: BushaEnvironment;
};

const detectBundleId = (): string => {
  const id = Application.applicationId;
  if (!id) {
    throw new Error(
      'BushaPay could not detect the app bundle ID from expo-application. ' +
        'Make sure expo-application is installed and the app is running ' +
        'on iOS or Android.'
    );
  }
  return id;
};

type State = {
  publicKey: string;
  bundleId: string;
  environment: BushaEnvironment;
};

let state: State | null = null;

const ensureInit = (): State => {
  if (!state) {
    throw new Error('BushaPay.init() must be called before using the SDK');
  }
  return state;
};

export const BushaPay = {
  init(options: InitOptions): void {
    const bundleId = detectBundleId();
    state = {
      publicKey: options.publicKey,
      bundleId,
      environment: options.environment ?? 'live',
    };
    setCallbackScheme(`${bundleId}.busha-pay`);
  },

  get isInitialized(): boolean {
    return state !== null;
  },

  get publicKey(): string {
    return ensureInit().publicKey;
  },

  get environment(): BushaEnvironment {
    return ensureInit().environment;
  },

  get isDevMode(): boolean {
    return BushaPay.environment === 'sandbox';
  },

  get callbackScheme(): string {
    return `${ensureInit().bundleId}.busha-pay`;
  },

  get callbackUrl(): string {
    return `${BushaPay.callbackScheme}://callback`;
  },

  get checkoutUrl(): string {
    return getCheckoutUrl(BushaPay.environment);
  },

  get platformUrl(): string {
    return getPlatformUrl(BushaPay.environment);
  },

  /**
   * Forward an incoming deep-link URL to the SDK.
   *
   * Returns `true` if the URL was a Busha callback and was consumed.
   * Call this from your app's URL handler (e.g., `Linking` / `expo-linking`).
   */
  handleDeepLink: handleDeepLinkInternal,
};

export const buildBushaAppDeepLink = (
  config: BushaPayConfig
): string | null => {
  const s = state;
  if (!s) return null;
  const scheme = getBushaAppScheme(s.environment);
  if (!scheme) return null;

  const params: Record<string, string> = {
    public_key: s.publicKey,
    quote_amount: config.quoteAmount,
    quote_currency: config.quoteCurrency,
    callback_url: BushaPay.callbackUrl,
  };
  if (config.reference) params.reference = config.reference;
  return `${scheme}://busha.co/pay?${encodeQuery(params)}`;
};

/**
 * Launches the Busha app via a deep link and waits for the callback URL
 * to resolve. If the merchant app resumes and no callback arrives within
 * 1500ms, the flow completes as cancelled.
 */
export const launchBushaApp = (deepLink: string): Promise<BushaPayResult> =>
  new Promise<BushaPayResult>((resolve) => {
    let finished = false;
    const complete = (r: BushaPayResult): void => {
      if (finished) return;
      finished = true;
      setDirectLaunchResolver(null);
      sub.remove();
      resolve(r);
    };

    setDirectLaunchResolver(complete);

    const sub = AppState.addEventListener('change', (next) => {
      if (next !== 'active') return;
      setTimeout(() => {
        if (!finished) complete(cancelled());
      }, 1500);
    });

    Linking.openURL(deepLink).catch((e) => {
      complete(
        errorResult(
          e instanceof Error ? e.message : 'Failed to launch the Busha app',
          'launch_failed'
        )
      );
    });
  });

export const canOpenBushaApp = async (deepLink: string): Promise<boolean> => {
  try {
    return await Linking.canOpenURL(deepLink);
  } catch {
    return false;
  }
};
