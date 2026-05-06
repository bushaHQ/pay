import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';

import {
  PaymentMethodChooser,
  type PaymentMethod,
} from './components/PaymentMethodChooser';
import {
  BushaPaySheet,
  type PugPayAutoSelect,
} from './components/BushaPaySheet';
import type { BushaPayConfig } from './config';
import type { BushaEnvironment } from './environment';
import type { BushaPayResult } from './result';
import { cancelled } from './result';
import {
  BushaPay,
  buildBushaAppDeepLink,
  canOpenBushaApp,
  launchBushaApp,
} from './sdk';

type ProviderProps = {
  publicKey: string;
  environment?: BushaEnvironment;
  children: ReactNode;
};

type CheckoutFn = (config: BushaPayConfig) => Promise<BushaPayResult>;

type ContextValue = {
  checkout: CheckoutFn;
  isCheckoutInProgress: boolean;
};

const BushaPayContext = createContext<ContextValue | null>(null);

export const BushaPayProvider = ({
  publicKey,
  environment,
  children,
}: ProviderProps) => {
  if (!BushaPay.isInitialized) {
    BushaPay.init({ publicKey, environment });
  }

  const [chooserConfig, setChooserConfig] = useState<BushaPayConfig | null>(
    null
  );
  const [sheetState, setSheetState] = useState<{
    config: BushaPayConfig;
    autoSelect: PugPayAutoSelect;
  } | null>(null);
  const resolverRef = useRef<((r: BushaPayResult) => void) | null>(null);
  const inProgressRef = useRef(false);

  const resolve = useCallback((result: BushaPayResult) => {
    const r = resolverRef.current;
    if (!r) return;
    resolverRef.current = null;
    inProgressRef.current = false;
    r(result);
  }, []);

  const openWebSheet = useCallback(
    (config: BushaPayConfig, autoSelect: PugPayAutoSelect) => {
      setChooserConfig(null);
      setSheetState({ config, autoSelect });
    },
    []
  );

  const routeChoice = useCallback(
    async (config: BushaPayConfig, choice: PaymentMethod) => {
      if (choice === 'bushaApp') {
        const deepLink = buildBushaAppDeepLink(config);
        if (deepLink && (await canOpenBushaApp(deepLink))) {
          setChooserConfig(null);
          const result = await launchBushaApp(deepLink);
          resolve(result);
          return;
        }
        // Fall through to the WebView with the Busha tile pre-selected.
        openWebSheet(config, 'bushaApp');
        return;
      }

      openWebSheet(config, 'stablecoins');
    },
    [openWebSheet, resolve]
  );

  const handleChoice = useCallback(
    async (choice: PaymentMethod) => {
      const config = chooserConfig;
      if (!config) return;
      await routeChoice(config, choice);
    },
    [chooserConfig, routeChoice]
  );

  const checkout = useCallback<CheckoutFn>(
    (config) => {
      if (inProgressRef.current) {
        return Promise.resolve({
          type: 'error',
          message: 'Another payment is already in progress',
          code: 'CHECKOUT_IN_PROGRESS',
        } as const);
      }
      inProgressRef.current = true;
      return new Promise<BushaPayResult>((res) => {
        resolverRef.current = res;

        const allowed = config.allowedPaymentMethods;
        if (allowed && allowed.length === 1) {
          const only = allowed[0];
          if (only) {
            routeChoice(config, only).catch(() => {});
            return;
          }
        }

        setChooserConfig(config);
      });
    },
    [routeChoice]
  );

  const value = useMemo<ContextValue>(
    () => ({
      checkout,
      get isCheckoutInProgress() {
        return inProgressRef.current;
      },
    }),
    [checkout]
  );

  return (
    <BushaPayContext.Provider value={value}>
      {children}
      {chooserConfig && (
        <PaymentMethodChooser
          visible
          config={chooserConfig}
          allowedPaymentMethods={chooserConfig.allowedPaymentMethods}
          onChoose={handleChoice}
          onDismiss={() => {
            setChooserConfig(null);
            resolve(cancelled());
          }}
        />
      )}
      {sheetState && (
        <BushaPaySheet
          visible
          config={sheetState.config}
          autoSelect={sheetState.autoSelect}
          onResult={(result) => {
            setSheetState(null);
            resolve(result);
          }}
        />
      )}
    </BushaPayContext.Provider>
  );
};

export const useBushaPay = (): ContextValue => {
  const ctx = useContext(BushaPayContext);
  if (!ctx) {
    throw new Error('useBushaPay must be used inside <BushaPayProvider>');
  }
  return ctx;
};
