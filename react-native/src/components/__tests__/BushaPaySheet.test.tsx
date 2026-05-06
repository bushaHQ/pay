import {
  afterEach,
  beforeEach,
  describe,
  expect,
  jest,
  test,
} from '@jest/globals';
import { act, render, screen } from '@testing-library/react-native';
import { Linking } from 'react-native';

jest.mock('expo-application');
jest.mock('react-native-svg');
jest.mock('react-native-webview');

const {
  BushaPaySheet,
  autoSelectParam,
  autoSelectRowPrefix,
} = require('../BushaPaySheet');

const { BushaPay } = require('../../sdk');

const webViewMock = require('react-native-webview');

const mockOpenURL = jest
  .spyOn(Linking, 'openURL')
  .mockImplementation(async () => {});

const config = {
  quoteAmount: '10000',
  quoteCurrency: 'NGN',
  targetCurrency: 'NGN',
  sourceCurrency: 'USDT',
};

beforeEach(() => {
  webViewMock.__resetWebViewMock();
  mockOpenURL.mockClear();
  BushaPay.resetForTesting();
  BushaPay.init({ publicKey: 'pub_x' });
});

afterEach(() => {
  BushaPay.resetForTesting();
});

describe('BushaPaySheet — initial render', () => {
  test('renders the chooser shimmer while initialization is pending', () => {
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={() => {}}
      />
    );
    expect(screen.getByLabelText('Loading payment options')).toBeTruthy();
    expect(screen.getByTestId('mock-webview')).toBeTruthy();
  });
});

describe('BushaPaySheet — WebView lifecycle', () => {
  test('first onLoadEnd injects initCheckout with form fields', () => {
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={() => {}}
      />
    );
    act(() => webViewMock.__lastWebView!.fireLoadEnd());
    expect(webViewMock.__injectedScripts.length).toBe(1);
    const script = webViewMock.__injectedScripts[0];
    expect(script).toContain('initCheckout(');
    expect(script).toContain('"public_key":"pub_x"');
    expect(script).toContain('"quote_amount":"10000"');
    expect(script).toContain('"_checkoutUrl"');
    expect(script).toContain('https://pay.busha.co/pay');
  });

  test('autoSelect=stablecoins appends ?paymentMethod=stablecoins to the form action', () => {
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="stablecoins"
        onResult={() => {}}
      />
    );
    act(() => webViewMock.__lastWebView!.fireLoadEnd());
    expect(webViewMock.__injectedScripts[0]).toContain(
      '?paymentMethod=stablecoins'
    );
  });

  test('second onLoadEnd injects autoSelectScript when autoSelect != none', () => {
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="bushaApp"
        onResult={() => {}}
      />
    );
    act(() => webViewMock.__lastWebView!.fireLoadEnd());
    act(() => webViewMock.__lastWebView!.fireLoadEnd());
    expect(webViewMock.__injectedScripts.length).toBe(2);
    expect(webViewMock.__injectedScripts[1]).toContain('var target = "Busha"');
  });

  test('second onLoadEnd does not inject auto-select when autoSelect == none', () => {
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={() => {}}
      />
    );
    act(() => webViewMock.__lastWebView!.fireLoadEnd());
    act(() => webViewMock.__lastWebView!.fireLoadEnd());
    expect(webViewMock.__injectedScripts.length).toBe(1);
  });
});

describe('BushaPaySheet — bridge messages', () => {
  test('ready message hides the shimmer', async () => {
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={() => {}}
      />
    );
    act(() =>
      webViewMock.__lastWebView!.emitMessage(JSON.stringify({ type: 'ready' }))
    );
    expect(screen.queryByLabelText('Loading payment options')).toBeNull();
  });

  test('success message delivers a BushaPaySuccess with full data', () => {
    const onResult = jest.fn();
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={onResult}
      />
    );
    act(() =>
      webViewMock.__lastWebView!.emitMessage(
        JSON.stringify({
          type: 'success',
          data: { data: { id: 'PAYR_S', status: 'completed' } },
        })
      )
    );
    expect(onResult).toHaveBeenCalledTimes(1);
    expect(onResult.mock.calls[0]?.[0]).toMatchObject({
      type: 'success',
      paymentId: 'PAYR_S',
      hasFullData: true,
    });
  });

  test('close message delivers a cancelled result', () => {
    const onResult = jest.fn();
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={onResult}
      />
    );
    act(() =>
      webViewMock.__lastWebView!.emitMessage(JSON.stringify({ type: 'close' }))
    );
    expect(onResult).toHaveBeenCalledWith({ type: 'cancelled' });
  });

  test('error message delivers an error with code and message', () => {
    const onResult = jest.fn();
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={onResult}
      />
    );
    act(() =>
      webViewMock.__lastWebView!.emitMessage(
        JSON.stringify({
          type: 'error',
          data: { message: 'boom', code: 'E_BOOM' },
        })
      )
    );
    expect(onResult).toHaveBeenCalledWith({
      type: 'error',
      message: 'boom',
      code: 'E_BOOM',
    });
  });

  test('only the first terminal message delivers a result', () => {
    const onResult = jest.fn();
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={onResult}
      />
    );
    act(() =>
      webViewMock.__lastWebView!.emitMessage(JSON.stringify({ type: 'close' }))
    );
    act(() =>
      webViewMock.__lastWebView!.emitMessage(
        JSON.stringify({ type: 'success', data: {} })
      )
    );
    expect(onResult).toHaveBeenCalledTimes(1);
    expect(onResult.mock.calls[0]?.[0]).toEqual({ type: 'cancelled' });
  });

  test('non-JSON messages are ignored', () => {
    const onResult = jest.fn();
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={onResult}
      />
    );
    act(() => webViewMock.__lastWebView!.emitMessage('not json {'));
    expect(onResult).not.toHaveBeenCalled();
  });

  test('messages of unknown type are ignored', () => {
    const onResult = jest.fn();
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={onResult}
      />
    );
    act(() =>
      webViewMock.__lastWebView!.emitMessage(
        JSON.stringify({ type: 'mystery', data: {} })
      )
    );
    expect(onResult).not.toHaveBeenCalled();
  });
});

describe('BushaPaySheet — onShouldStartLoadWithRequest', () => {
  test('allows http/https URLs', () => {
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={() => {}}
      />
    );
    expect(
      webViewMock.__lastWebView!.shouldStartLoad('https://pay.busha.co/pay')
    ).toBe(true);
    expect(
      webViewMock.__lastWebView!.shouldStartLoad('http://example.com/x')
    ).toBe(true);
  });

  test('rejects non-web schemes and forwards them to Linking.openURL', () => {
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={() => {}}
      />
    );
    expect(
      webViewMock.__lastWebView!.shouldStartLoad(
        'co.busha.apple://busha.co/pay'
      )
    ).toBe(false);
    expect(mockOpenURL).toHaveBeenCalledWith('co.busha.apple://busha.co/pay');
  });

  test('allows requests with unparseable URLs (no decision)', () => {
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={() => {}}
      />
    );
    expect(webViewMock.__lastWebView!.shouldStartLoad('garbage')).toBe(true);
  });
});

describe('BushaPaySheet — deep-link forwarding', () => {
  test('a callback handled by the SDK while the sheet is open delivers a result', () => {
    const onResult = jest.fn();
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={onResult}
      />
    );
    BushaPay.handleDeepLink(
      'co.example.testapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_DL'
    );
    expect(onResult).toHaveBeenCalledTimes(1);
    expect(onResult.mock.calls[0]?.[0]).toMatchObject({
      type: 'success',
      paymentId: 'PAYR_DL',
    });
  });

  test('a non-callback URI does not deliver a result', () => {
    const onResult = jest.fn();
    render(
      <BushaPaySheet
        visible
        config={config}
        autoSelect="none"
        onResult={onResult}
      />
    );
    BushaPay.handleDeepLink('https://example.com/foo');
    expect(onResult).not.toHaveBeenCalled();
  });
});

describe('autoSelect helpers', () => {
  test('autoSelectParam maps to the pug-pay query keys', () => {
    expect(autoSelectParam('bushaApp')).toBe('busha');
    expect(autoSelectParam('stablecoins')).toBe('stablecoins');
    expect(autoSelectParam('none')).toBeNull();
  });

  test('autoSelectRowPrefix maps to the pug-pay chooser labels', () => {
    expect(autoSelectRowPrefix('bushaApp')).toBe('Busha');
    expect(autoSelectRowPrefix('stablecoins')).toBe('Stablecoins');
    expect(autoSelectRowPrefix('none')).toBeNull();
  });
});
