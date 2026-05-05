import {
  afterEach,
  beforeEach,
  describe,
  expect,
  jest,
  test,
} from '@jest/globals';
import { act, fireEvent, render, screen } from '@testing-library/react-native';
import { useEffect } from 'react';
import { AppState, Linking, Pressable, Text, View } from 'react-native';

jest.mock('expo-application');
jest.mock('react-native-svg');
jest.mock('react-native-webview');

const { BushaPayProvider, useBushaPay } = require('../provider');

const { BushaPay } = require('../sdk');

const webViewMock = require('react-native-webview');

type Result = import('../result').BushaPayResult;

const config = {
  quoteAmount: '10000',
  quoteCurrency: 'NGN',
  targetCurrency: 'NGN',
  sourceCurrency: 'USDT',
};

const CALLBACK_PREFIX = 'co.example.testapp.busha-pay://callback';

const mockOpenURL = jest
  .spyOn(Linking, 'openURL')
  .mockImplementation(async () => {});
const mockCanOpenURL = jest
  .spyOn(Linking, 'canOpenURL')
  .mockImplementation(async () => false);

let mockAppStateListener: ((next: string) => void) | null = null;
jest
  .spyOn(AppState, 'addEventListener')

  .mockImplementation(((_evt: string, listener: (next: string) => void) => {
    mockAppStateListener = listener;
    return { remove: () => (mockAppStateListener = null) };
  }) as any);

type HarnessProps = {
  onResult: (r: Result) => void;
  triggerKey?: number;
};

const Harness = ({ onResult, triggerKey = 0 }: HarnessProps) => {
  const { checkout } = useBushaPay();
  return (
    <View>
      <Pressable
        accessibilityLabel="open"
        onPress={() => {
          checkout(config).then(onResult);
        }}
      >
        <Text>open</Text>
      </Pressable>
      {triggerKey > 0 && (
        <SecondCheckoutTrigger onResult={onResult} key={triggerKey} />
      )}
    </View>
  );
};

const SecondCheckoutTrigger = ({
  onResult,
}: {
  onResult: (r: Result) => void;
}) => {
  const { checkout } = useBushaPay();
  useEffect(() => {
    checkout(config).then(onResult);
  }, [checkout, onResult]);
  return null;
};

const renderProvider = (onResult: (r: Result) => void) =>
  render(
    <BushaPayProvider publicKey="pub_x">
      <Harness onResult={onResult} />
    </BushaPayProvider>
  );

beforeEach(() => {
  webViewMock.__resetWebViewMock();
  mockOpenURL.mockClear();
  mockCanOpenURL.mockClear();
  mockCanOpenURL.mockImplementation(async () => false);
  mockAppStateListener = null;
  BushaPay.resetForTesting();
});

afterEach(() => {
  BushaPay.resetForTesting();
});

describe('BushaPayProvider — chooser flow', () => {
  test('initializes the SDK with the provided publicKey', () => {
    expect(BushaPay.isInitialized).toBe(false);
    renderProvider(() => {});
    expect(BushaPay.isInitialized).toBe(true);
    expect(BushaPay.publicKey).toBe('pub_x');
  });

  test('opens the chooser on checkout', () => {
    renderProvider(() => {});
    fireEvent.press(screen.getByLabelText('open'));
    expect(screen.getByText('Choose a payment method')).toBeTruthy();
  });

  test('dismissing the chooser delivers cancelled', async () => {
    let result: Result | undefined;
    renderProvider((r) => {
      result = r;
    });
    fireEvent.press(screen.getByLabelText('open'));
    await act(async () => {
      fireEvent.press(screen.getByLabelText('Close'));
    });
    expect(result).toEqual({ type: 'cancelled' });
  });
});

describe('BushaPayProvider — Stablecoins flow', () => {
  test('selecting Stablecoins opens the sheet and forwards a deep-link success', async () => {
    let result: Result | undefined;
    renderProvider((r) => {
      result = r;
    });
    fireEvent.press(screen.getByLabelText('open'));
    await act(async () => {
      fireEvent.press(screen.getByLabelText('Stablecoins'));
    });
    expect(screen.getByLabelText('Loading payment options')).toBeTruthy();

    await act(async () => {
      BushaPay.handleDeepLink(
        `${CALLBACK_PREFIX}?status=completed&paymentRequestId=PAYR_S1`
      );
    });
    expect(result).toMatchObject({ type: 'success', paymentId: 'PAYR_S1' });
  });
});

describe('BushaPayProvider — Busha app flow', () => {
  test('canOpenURL=false → falls through to the web sheet with autoSelect=bushaApp', async () => {
    mockCanOpenURL.mockImplementation(async () => false);
    let result: Result | undefined;
    renderProvider((r) => {
      result = r;
    });
    fireEvent.press(screen.getByLabelText('open'));
    await act(async () => {
      fireEvent.press(screen.getByLabelText('Busha'));
    });
    expect(mockOpenURL).not.toHaveBeenCalled();
    expect(screen.getByLabelText('Loading payment options')).toBeTruthy();
    act(() => webViewMock.__lastWebView!.fireLoadEnd());
    const firstScript = webViewMock.__injectedScripts[0];
    expect(firstScript).toContain('?method=busha');

    await act(async () => {
      BushaPay.handleDeepLink(`${CALLBACK_PREFIX}?status=cancelled`);
    });
    expect(result).toEqual({ type: 'cancelled' });
  });

  test('canOpenURL=true → launches the deep link and forwards the callback success', async () => {
    mockCanOpenURL.mockImplementation(async () => true);
    let result: Result | undefined;
    renderProvider((r) => {
      result = r;
    });
    fireEvent.press(screen.getByLabelText('open'));
    await act(async () => {
      fireEvent.press(screen.getByLabelText('Busha'));
    });
    expect(mockOpenURL).toHaveBeenCalledTimes(1);
    const launched = mockOpenURL.mock.calls[0]?.[0] as string;
    expect(launched.startsWith('co.busha.apple://busha.co/pay?')).toBe(true);
    expect(launched).toContain('public_key=pub_x');
    expect(launched).toContain('quote_amount=10000');

    await act(async () => {
      BushaPay.handleDeepLink(
        `${CALLBACK_PREFIX}?status=completed&paymentRequestId=PAYR_BA1`
      );
    });
    expect(result).toMatchObject({
      type: 'success',
      paymentId: 'PAYR_BA1',
    });
  });

  test('Busha launch + cancelled callback resolves to cancelled', async () => {
    mockCanOpenURL.mockImplementation(async () => true);
    let result: Result | undefined;
    renderProvider((r) => {
      result = r;
    });
    fireEvent.press(screen.getByLabelText('open'));
    await act(async () => {
      fireEvent.press(screen.getByLabelText('Busha'));
    });
    await act(async () => {
      BushaPay.handleDeepLink(`${CALLBACK_PREFIX}?status=cancelled`);
    });
    expect(result).toEqual({ type: 'cancelled' });
  });

  test('Busha launch + error callback extracts error_code and error_message', async () => {
    mockCanOpenURL.mockImplementation(async () => true);
    let result: Result | undefined;
    renderProvider((r) => {
      result = r;
    });
    fireEvent.press(screen.getByLabelText('open'));
    await act(async () => {
      fireEvent.press(screen.getByLabelText('Busha'));
    });
    await act(async () => {
      BushaPay.handleDeepLink(
        `${CALLBACK_PREFIX}?status=failed&error_code=NET_DOWN&error_message=No%20signal`
      );
    });
    expect(result).toEqual({
      type: 'error',
      message: 'No signal',
      code: 'NET_DOWN',
    });
  });

  test('Busha launch + AppState resume without callback within 1.5s resolves to cancelled', async () => {
    jest.useFakeTimers();
    mockCanOpenURL.mockImplementation(async () => true);
    let result: Result | undefined;
    renderProvider((r) => {
      result = r;
    });
    fireEvent.press(screen.getByLabelText('open'));
    await act(async () => {
      fireEvent.press(screen.getByLabelText('Busha'));
    });
    expect(mockAppStateListener).not.toBeNull();
    act(() => mockAppStateListener!('active'));
    await act(async () => {
      jest.advanceTimersByTime(1500);
    });
    expect(result).toEqual({ type: 'cancelled' });
    jest.useRealTimers();
  });
});

describe('BushaPayProvider — concurrency', () => {
  test('a second checkout while the first is in flight returns CHECKOUT_IN_PROGRESS', async () => {
    const results: Result[] = [];
    const onResult = (r: Result) => results.push(r);
    const { rerender } = render(
      <BushaPayProvider publicKey="pub_x">
        <Harness onResult={onResult} />
      </BushaPayProvider>
    );
    fireEvent.press(screen.getByLabelText('open'));

    await act(async () => {
      rerender(
        <BushaPayProvider publicKey="pub_x">
          <Harness onResult={onResult} triggerKey={1} />
        </BushaPayProvider>
      );
    });

    expect(results.length).toBe(1);
    expect(results[0]).toMatchObject({
      type: 'error',
      code: 'CHECKOUT_IN_PROGRESS',
    });
  });

  test('useBushaPay throws outside a provider', () => {
    const Bare = () => {
      useBushaPay();
      return null;
    };
    const prevError = console.error;
    console.error = () => {};
    try {
      expect(() => render(<Bare />)).toThrow(
        /useBushaPay must be used inside <BushaPayProvider>/
      );
    } finally {
      console.error = prevError;
    }
  });
});
