export type BushaPayConfig = {
  quoteAmount: string;
  quoteCurrency: string;
  targetCurrency: string;
  sourceCurrency: string;
  reference?: string;
  metaName?: string;
  metaEmail?: string;
  metaPhone?: string;
  source?: string;
  sourceId?: string;
};

import { getOrigin } from './url-utils';

export const toFormFields = (
  config: BushaPayConfig,
  opts: { publicKey: string; callbackUrl: string; checkoutUrl: string }
): Record<string, string> => {
  const parentOrigin = getOrigin(opts.checkoutUrl);
  const fields: Record<string, string> = {
    public_key: opts.publicKey,
    quote_amount: config.quoteAmount,
    quote_currency: config.quoteCurrency,
    target_currency: config.targetCurrency,
    source_currency: config.sourceCurrency,
    callback_url: opts.callbackUrl,
    displayMode: 'INLINE',
    parentOrigin,
  };
  if (config.reference) fields.reference = config.reference;
  if (config.metaName) fields['meta[name]'] = config.metaName;
  if (config.metaEmail) fields['meta[email]'] = config.metaEmail;
  if (config.metaPhone) fields['meta[phone_number]'] = config.metaPhone;
  if (config.source) fields.source = config.source;
  if (config.sourceId) fields.source_id = config.sourceId;
  return fields;
};
