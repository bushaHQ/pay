export type BushaPaySuccess = {
  type: 'success';
  paymentId: string;
  status: string;

  // Full data — populated only when payment completed via the web checkout
  // (not when the Busha app fires the callback). Use `hasFullData` to check.
  sourceAmount?: string;
  sourceCurrency?: string;
  targetAmount?: string;
  targetCurrency?: string;
  requestedAmount?: string;
  currency?: string;
  rate?: Record<string, unknown>;
  merchantInfo?: Record<string, unknown>;
  timeline?: Record<string, unknown>;
  rawData?: Record<string, unknown>;

  /** `true` when the full web-checkout data is present; `false` for Busha-app callbacks. */
  hasFullData: boolean;
};

export type BushaPayCancelled = { type: 'cancelled' };

export type BushaPayError = {
  type: 'error';
  message: string;
  code?: string;
};

export type BushaPayResult =
  | BushaPaySuccess
  | BushaPayCancelled
  | BushaPayError;

/** Success result from a callback deep link (Busha-app path — limited data). */
export const successFromCallback = (paymentId: string): BushaPaySuccess => ({
  type: 'success',
  paymentId,
  status: 'completed',
  hasFullData: false,
});

/** Success result from the web checkout's COMPLETED postMessage (full data). */
export const successFromCheckoutData = (
  payload: Record<string, unknown>
): BushaPaySuccess => {
  const data = (payload.data as Record<string, unknown> | undefined) ?? payload;

  return {
    type: 'success',
    paymentId:
      (data.id as string | undefined) ??
      (data.reference as string | undefined) ??
      '',
    status: (data.status as string | undefined) ?? 'completed',
    sourceAmount: data.source_amount as string | undefined,
    sourceCurrency: data.source_currency as string | undefined,
    targetAmount: data.target_amount as string | undefined,
    targetCurrency: data.target_currency as string | undefined,
    requestedAmount: data.requested_amount as string | undefined,
    currency: data.currency as string | undefined,
    rate: data.rate as Record<string, unknown> | undefined,
    merchantInfo: data.merchant_info as Record<string, unknown> | undefined,
    timeline: data.timeline as Record<string, unknown> | undefined,
    rawData: payload,
    hasFullData: true,
  };
};

export const cancelled = (): BushaPayCancelled => ({ type: 'cancelled' });

export const errorResult = (message: string, code?: string): BushaPayError => ({
  type: 'error',
  message,
  code,
});
