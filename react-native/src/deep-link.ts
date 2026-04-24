import type { BushaPayResult } from './result';
import { cancelled, errorResult, successFromCallback } from './result';
import { parseUrl } from './url-utils';

type Resolver = (result: BushaPayResult) => void;
type CallbackHandler = (url: string) => void;

let directLaunchResolver: Resolver | null = null;
let pendingCallbackHandler: CallbackHandler | null = null;
let callbackScheme: string | null = null;

export const setCallbackScheme = (scheme: string): void => {
  callbackScheme = scheme;
};

export const parseCallback = (url: string): BushaPayResult => {
  const parsed = parseUrl(url);
  const query = parsed?.query ?? {};
  const status = query.status;
  const paymentRequestId = query.paymentRequestId ?? '';
  const checkoutId = query.checkoutId ?? '';

  switch (status) {
    case 'completed':
      return successFromCallback(paymentRequestId, checkoutId);
    case 'cancelled':
      return cancelled();
    default: {
      const code = query.error_code ?? status ?? 'unknown';
      const message = query.error_message ?? 'Payment failed';
      return errorResult(message, code);
    }
  }
};

const isBushaCallback = (url: string): boolean => {
  if (!callbackScheme) return false;
  const parsed = parseUrl(url);
  if (!parsed) return false;
  return parsed.scheme === callbackScheme && parsed.host === 'callback';
};

export const handleDeepLink = (url: string): boolean => {
  if (!isBushaCallback(url)) return false;
  if (directLaunchResolver) {
    const resolve = directLaunchResolver;
    directLaunchResolver = null;
    resolve(parseCallback(url));
    return true;
  }
  pendingCallbackHandler?.(url);
  return true;
};

export const setDirectLaunchResolver = (resolver: Resolver | null): void => {
  directLaunchResolver = resolver;
};

export const registerCallbackHandler = (
  handler: CallbackHandler | null
): void => {
  pendingCallbackHandler = handler;
};
