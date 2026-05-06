import { useEffect, useMemo, useRef, useState } from 'react';
import { Linking, Modal, Pressable, StyleSheet, View } from 'react-native';
import WebView, {
  type WebViewMessageEvent,
  type WebViewProps,
} from 'react-native-webview';

import { CHECKOUT_HTML } from '../checkout-html';
import type { BushaPayConfig } from '../config';
import { toFormFields } from '../config';
import { registerCallbackHandler, parseCallback } from '../deep-link';
import { parseUrl } from '../url-utils';
import type { BushaPayResult } from '../result';
import { cancelled, errorResult, successFromCheckoutData } from '../result';
import { BushaPay } from '../sdk';
import {
  DOCUMENT_START_SCRIPTS,
  autoSelectScript,
  initCheckoutScript,
} from '../user-scripts';
import { ChooserShimmer } from './ChooserShimmer';

export type PugPayAutoSelect = 'none' | 'bushaApp' | 'stablecoins';

export const autoSelectParam = (a: PugPayAutoSelect): string | null => {
  if (a === 'bushaApp') return 'busha';
  if (a === 'stablecoins') return 'stablecoins';
  return null;
};

export const autoSelectRowPrefix = (a: PugPayAutoSelect): string | null => {
  if (a === 'bushaApp') return 'Busha';
  if (a === 'stablecoins') return 'Stablecoins';
  return null;
};

type Props = {
  visible: boolean;
  config: BushaPayConfig;
  autoSelect: PugPayAutoSelect;
  onResult: (result: BushaPayResult) => void;
};

const WEB_SCHEMES = new Set(['http', 'https', 'about', 'data', 'blob']);

const BOOTSTRAP_TIMEOUT_MS = 30_000;

export const BushaPaySheet = ({
  visible,
  config,
  autoSelect,
  onResult,
}: Props) => {
  const webViewRef = useRef<WebView | null>(null);
  const [initialized, setInitialized] = useState(false);
  const resultDeliveredRef = useRef(false);
  const formSubmittedRef = useRef(false);
  const bootstrapTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const deliverResult = (result: BushaPayResult): void => {
    if (resultDeliveredRef.current) return;
    resultDeliveredRef.current = true;
    if (bootstrapTimerRef.current) {
      clearTimeout(bootstrapTimerRef.current);
      bootstrapTimerRef.current = null;
    }
    onResult(result);
  };

  const checkoutUrl = useMemo(() => BushaPay.checkoutUrl, []);
  const callbackUrl = useMemo(() => BushaPay.callbackUrl, []);
  const publicKey = useMemo(() => BushaPay.publicKey, []);

  const webViewSource = useMemo(
    () => ({ html: CHECKOUT_HTML, baseUrl: checkoutUrl }),
    [checkoutUrl]
  );

  // Sub-resource failures (analytics, fonts, third-party iframes) come
  // through onError/onHttpError too. Filter to the main checkout host
  // so we don't tear down the whole flow on a benign 404.
  const checkoutHost = useMemo(
    () => parseUrl(checkoutUrl)?.host ?? '',
    [checkoutUrl]
  );

  const isMainFrameUrl = (url: string | undefined | null): boolean => {
    if (!url) return false;
    const parsed = parseUrl(url);
    return !!parsed && !!checkoutHost && parsed.host === checkoutHost;
  };

  useEffect(() => {
    if (!visible) return;
    registerCallbackHandler((url) => {
      const result = parseCallback(url);
      if (result.type === 'success') deliverResult(result);
      else if (result.type === 'cancelled') deliverResult(result);
      else deliverResult(result);
    });
    bootstrapTimerRef.current = setTimeout(() => {
      bootstrapTimerRef.current = null;
      if (resultDeliveredRef.current) return;
      deliverResult(
        errorResult('Checkout timed out before loading', 'WEBVIEW_TIMEOUT')
      );
    }, BOOTSTRAP_TIMEOUT_MS);
    return () => {
      registerCallbackHandler(null);
      if (bootstrapTimerRef.current) {
        clearTimeout(bootstrapTimerRef.current);
        bootstrapTimerRef.current = null;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  const submitCheckoutForm = (): void => {
    const fields = toFormFields(config, {
      publicKey,
      callbackUrl,
      checkoutUrl,
    });
    const queryMethod = autoSelectParam(autoSelect);
    const formAction = queryMethod
      ? `${checkoutUrl}?paymentMethod=${queryMethod}`
      : checkoutUrl;
    const payload = JSON.stringify({ _checkoutUrl: formAction, ...fields });
    webViewRef.current?.injectJavaScript(initCheckoutScript(payload));
  };

  const handleMessage = (event: WebViewMessageEvent): void => {
    if (resultDeliveredRef.current) return;
    try {
      const payload = JSON.parse(event.nativeEvent.data) as {
        type: string;
        data?: unknown;
      };
      switch (payload.type) {
        case 'ready':
          if (bootstrapTimerRef.current) {
            clearTimeout(bootstrapTimerRef.current);
            bootstrapTimerRef.current = null;
          }
          setInitialized(true);
          return;
        case 'success':
          deliverResult(
            successFromCheckoutData(
              (payload.data ?? {}) as Record<string, unknown>
            )
          );
          return;
        case 'close':
          deliverResult(cancelled());
          return;
        case 'error': {
          const d = (payload.data ?? {}) as Record<string, unknown>;
          deliverResult(
            errorResult(
              (d.message as string | undefined) ?? 'An error occurred',
              d.code as string | undefined
            )
          );
          return;
        }
      }
    } catch {
      // Swallow — unrelated postMessage traffic.
    }
  };

  const handleShouldStartLoad: NonNullable<
    WebViewProps['onShouldStartLoadWithRequest']
  > = (request) => {
    const url = request.url;
    const parsed = parseUrl(url);
    if (!parsed) return true;
    if (WEB_SCHEMES.has(parsed.scheme)) return true;
    Linking.openURL(url).catch(() => {});
    return false;
  };

  const handleLoadEnd: NonNullable<WebViewProps['onLoadEnd']> = () => {
    if (!formSubmittedRef.current) {
      formSubmittedRef.current = true;
      submitCheckoutForm();
      return;
    }
    if (!initialized) setInitialized(true);
    const prefix = autoSelectRowPrefix(autoSelect);
    if (prefix) {
      webViewRef.current?.injectJavaScript(autoSelectScript(prefix));
    }
  };

  const handleError: NonNullable<WebViewProps['onError']> = (event) => {
    const { url, description } = event.nativeEvent;
    if (!isMainFrameUrl(url)) return;
    deliverResult(
      errorResult(
        `Could not load checkout (${description ?? 'unknown error'})`,
        'WEBVIEW_LOAD_ERROR'
      )
    );
  };

  const handleHttpError: NonNullable<WebViewProps['onHttpError']> = (event) => {
    const { url, statusCode } = event.nativeEvent;
    if (!isMainFrameUrl(url)) return;
    if (!statusCode) {
      deliverResult(
        errorResult('Could not load checkout', 'WEBVIEW_LOAD_ERROR')
      );
      return;
    }
    deliverResult(
      errorResult(`Checkout failed (HTTP ${statusCode})`, 'WEBVIEW_HTTP_ERROR')
    );
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={() => deliverResult(cancelled())}
    >
      <Pressable
        style={styles.backdrop}
        onPress={() => deliverResult(cancelled())}
        accessibilityLabel="Close checkout"
      >
        <Pressable
          style={[styles.sheet, !initialized && styles.sheetLoading]}
          onPress={() => {}}
        >
          <View style={styles.card}>
            <WebView
              ref={webViewRef}
              source={webViewSource}
              originWhitelist={['*']}
              injectedJavaScriptBeforeContentLoaded={DOCUMENT_START_SCRIPTS}
              injectedJavaScriptBeforeContentLoadedForMainFrameOnly={false}
              javaScriptEnabled
              domStorageEnabled
              setSupportMultipleWindows
              mixedContentMode="compatibility"
              onMessage={handleMessage}
              onShouldStartLoadWithRequest={handleShouldStartLoad}
              onLoadEnd={handleLoadEnd}
              onError={handleError}
              onHttpError={handleHttpError}
              style={styles.webview}
            />
            {!initialized && (
              <View style={styles.loader} pointerEvents="none">
                <ChooserShimmer />
              </View>
            )}
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
};

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'flex-end',
  },
  sheet: {
    height: '92%',
    backgroundColor: 'transparent',
  },
  sheetLoading: {
    paddingHorizontal: 16,
    paddingVertical: 24,
  },
  card: {
    flex: 1,
    borderRadius: 16,
    overflow: 'hidden',
    backgroundColor: 'transparent',
  },
  webview: { flex: 1, backgroundColor: 'transparent' },
  loader: { ...StyleSheet.absoluteFillObject },
});
