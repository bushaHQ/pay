import { forwardRef, useImperativeHandle } from 'react';
import { View, type ViewProps } from 'react-native';

export type WebViewMessageEvent = {
  nativeEvent: { data: string };
};

export type WebViewProps = ViewProps & {
  source?: unknown;
  onMessage?: (event: WebViewMessageEvent) => void;
  onLoadEnd?: () => void;
  onShouldStartLoadWithRequest?: (request: { url: string }) => boolean;
  injectedJavaScriptBeforeContentLoaded?: string;
  injectedJavaScriptBeforeContentLoadedForMainFrameOnly?: boolean;
  javaScriptEnabled?: boolean;
  domStorageEnabled?: boolean;
  setSupportMultipleWindows?: boolean;
  mixedContentMode?: string;
  originWhitelist?: string[];
};

export type MockWebViewHandle = {
  injectJavaScript: (script: string) => void;
  emitMessage: (data: string) => void;
  fireLoadEnd: () => void;
  shouldStartLoad: (url: string) => boolean;
  injected: string[];
  props: WebViewProps;
};

export const __injectedScripts: string[] = [];

const WebView = forwardRef<unknown, WebViewProps>((props, ref) => {
  const handle: MockWebViewHandle = {
    injectJavaScript: (script: string) => {
      __injectedScripts.push(script);
    },
    emitMessage: (data: string) => props.onMessage?.({ nativeEvent: { data } }),
    fireLoadEnd: () => props.onLoadEnd?.(),
    shouldStartLoad: (url: string) =>
      props.onShouldStartLoadWithRequest
        ? props.onShouldStartLoadWithRequest({ url })
        : true,
    injected: __injectedScripts,
    props,
  };
  useImperativeHandle(ref, () => handle);
  // Stash on the most recently mounted handle for easy access in tests.
  __lastWebView = handle;
  return <View testID="mock-webview" />;
});
WebView.displayName = 'MockWebView';

export let __lastWebView: MockWebViewHandle | null = null;

export const __resetWebViewMock = (): void => {
  __injectedScripts.length = 0;
  __lastWebView = null;
};

export default WebView;
