import { Platform } from 'react-native';

export type BushaEnvironment = 'sandbox' | 'live';

export const getCheckoutUrl = (env: BushaEnvironment): string =>
  env === 'sandbox'
    ? 'https://staging.pay.busha.co/pay'
    : 'https://pay.busha.co/pay';

export const getBushaAppScheme = (env: BushaEnvironment): string | null => {
  if (Platform.OS === 'ios') {
    return env === 'sandbox' ? 'co.busha.boro.development' : 'co.busha.apple';
  }
  if (Platform.OS === 'android') {
    return env === 'sandbox'
      ? 'co.busha.android.development'
      : 'co.busha.android';
  }
  return null;
};
