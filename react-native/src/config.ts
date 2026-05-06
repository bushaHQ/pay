import type { PaymentMethod } from './payment-method';
import { getOrigin } from './url-utils';

export type BushaPayConfig = {
  quoteAmount: string;
  quoteCurrency: string;
  targetCurrency: string;
  sourceCurrency: string;
  reference?: string;
  metaName?: string;
  metaEmail?: string;
  metaPhone?: string;
  /**
   * Restricts which payment methods the chooser offers.
   */
  allowedPaymentMethods?: PaymentMethod[];
};

export const toFormFields = (
  config: BushaPayConfig,
  opts: { publicKey: string; callbackUrl: string; checkoutUrl: string }
): Record<string, string> => {
  const fields: Record<string, string> = {
    public_key: opts.publicKey,
    quote_amount: config.quoteAmount,
    quote_currency: config.quoteCurrency,
    target_currency: config.targetCurrency,
    source_currency: config.sourceCurrency,
    callback_url: opts.callbackUrl,
    displayMode: 'INLINE',
  };
  const parentOrigin = getOrigin(opts.checkoutUrl);
  if (parentOrigin) fields.parentOrigin = parentOrigin;
  if (config.reference) fields.reference = config.reference;
  if (config.metaName) fields['meta[name]'] = config.metaName;
  if (config.metaEmail) fields['meta[email]'] = config.metaEmail;
  if (config.metaPhone) fields['meta[phone_number]'] = config.metaPhone;
  return fields;
};
