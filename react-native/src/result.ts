export type BushaPaySuccess = {
  type: 'success';
  paymentId: string;
  checkoutId: string;
  status: string;
  rawData?: Record<string, unknown>;
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

export const successFromCallback = (
  paymentId: string,
  checkoutId: string = ''
): BushaPaySuccess => ({
  type: 'success',
  paymentId,
  checkoutId,
  status: 'completed',
});

export const successFromCheckoutData = (
  data: Record<string, unknown>
): BushaPaySuccess => ({
  type: 'success',
  paymentId:
    (data.id as string | undefined) ??
    (data.reference as string | undefined) ??
    '',
  checkoutId: '',
  status: (data.status as string | undefined) ?? 'completed',
  rawData: data,
});

export const cancelled = (): BushaPayCancelled => ({ type: 'cancelled' });

export const errorResult = (message: string, code?: string): BushaPayError => ({
  type: 'error',
  message,
  code,
});
