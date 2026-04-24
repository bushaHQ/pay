import { useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Linking,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
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

export type PugPayAutoSelect = 'none' | 'bushaApp' | 'stablecoins';

const autoSelectParam = (a: PugPayAutoSelect): string | null => {
  if (a === 'bushaApp') return 'busha';
  if (a === 'stablecoins') return 'stablecoins';
  return null;
};

const autoSelectRowPrefix = (a: PugPayAutoSelect): string | null => {
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

  const deliverResult = (result: BushaPayResult): void => {
    if (resultDeliveredRef.current) return;
    resultDeliveredRef.current = true;
    onResult(result);
  };

  const checkoutUrl = useMemo(() => BushaPay.checkoutUrl, []);
  const callbackUrl = useMemo(() => BushaPay.callbackUrl, []);
  const publicKey = useMemo(() => BushaPay.publicKey, []);

  useEffect(() => {
    if (!visible) return;
    registerCallbackHandler((url) => {
      const result = parseCallback(url);
      if (result.type === 'success') deliverResult(result);
      else if (result.type === 'cancelled') deliverResult(result);
      else deliverResult(result);
    });
    return () => {
      registerCallbackHandler(null);
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
      ? `${checkoutUrl}?method=${queryMethod}`
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

  const handleLoadEnd = (): void => {
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

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={() => deliverResult(cancelled())}
    >
      <View style={styles.container}>
        <View style={styles.topBar}>
          <Text style={styles.title}>Busha Pay</Text>
          <Pressable
            onPress={() => deliverResult(cancelled())}
            hitSlop={12}
            accessibilityRole="button"
            accessibilityLabel="Close checkout"
          >
            <Text style={styles.close}>✕</Text>
          </Pressable>
        </View>
        <View style={styles.webviewContainer}>
          <WebView
            ref={webViewRef}
            source={{ html: CHECKOUT_HTML, baseUrl: checkoutUrl }}
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
          />
          {!initialized && (
            <View style={styles.loader} pointerEvents="none">
              <ActivityIndicator size="large" color="#00C853" />
            </View>
          )}
        </View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#eee',
  },
  title: { fontSize: 16, fontWeight: '600' },
  close: { fontSize: 18, color: '#333' },
  webviewContainer: { flex: 1 },
  loader: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#fff',
  },
});
