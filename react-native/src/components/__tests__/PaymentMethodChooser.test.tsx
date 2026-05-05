import { beforeEach, describe, expect, jest, test } from '@jest/globals';
import { fireEvent, render, screen } from '@testing-library/react-native';

jest.mock('expo-application');
jest.mock('react-native-svg');

const { PaymentMethodChooser } = require('../PaymentMethodChooser');

const { BushaPay } = require('../../sdk');

const baseConfig = {
  quoteAmount: '10000',
  quoteCurrency: 'NGN',
  targetCurrency: 'NGN',
  sourceCurrency: 'USDT',
};

beforeEach(() => {
  BushaPay.resetForTesting();
  BushaPay.init({ publicKey: 'pub_x' });
});

describe('PaymentMethodChooser layout', () => {
  test('renders the formatted amount, heading, both tiles, and footer', () => {
    render(
      <PaymentMethodChooser
        visible
        config={baseConfig}
        onChoose={() => {}}
        onDismiss={() => {}}
        merchantNameLoader={async () => null}
      />
    );

    expect(screen.getByText('Pay 10,000 NGN')).toBeTruthy();
    expect(screen.getByText('Choose a payment method')).toBeTruthy();
    expect(screen.getByText('Busha')).toBeTruthy();
    expect(screen.getByText('Stablecoins')).toBeTruthy();
    expect(
      screen.getByText('Make payment directly from your busha account')
    ).toBeTruthy();
    expect(
      screen.getByText('Make payment from an external wallet')
    ).toBeTruthy();
    expect(screen.getByText('Secured by')).toBeTruthy();
  });

  test('formats decimal amounts with two decimals and grouping', () => {
    render(
      <PaymentMethodChooser
        visible
        config={{ ...baseConfig, quoteAmount: '12345.5', quoteCurrency: 'USD' }}
        onChoose={() => {}}
        onDismiss={() => {}}
        merchantNameLoader={async () => null}
      />
    );
    expect(screen.getByText('Pay 12,345.50 USD')).toBeTruthy();
  });

  test('falls back to the raw amount string when not parseable', () => {
    render(
      <PaymentMethodChooser
        visible
        config={{ ...baseConfig, quoteAmount: 'abc', quoteCurrency: 'XYZ' }}
        onChoose={() => {}}
        onDismiss={() => {}}
        merchantNameLoader={async () => null}
      />
    );
    expect(screen.getByText('Pay abc XYZ')).toBeTruthy();
  });
});

describe('PaymentMethodChooser merchant line', () => {
  test('omits the merchant line when the loader returns null', () => {
    render(
      <PaymentMethodChooser
        visible
        config={baseConfig}
        onChoose={() => {}}
        onDismiss={() => {}}
        merchantNameLoader={async () => null}
      />
    );
    expect(screen.queryByText(/^To /)).toBeNull();
  });

  test('renders the merchant line once the loader resolves with a name', async () => {
    render(
      <PaymentMethodChooser
        visible
        config={baseConfig}
        onChoose={() => {}}
        onDismiss={() => {}}
        merchantNameLoader={async () => 'Pushup Design Agency'}
      />
    );
    expect(await screen.findByText('To Pushup Design Agency')).toBeTruthy();
  });
});

describe('PaymentMethodChooser selection', () => {
  test('tapping Busha calls onChoose with bushaApp', () => {
    const onChoose = jest.fn();
    render(
      <PaymentMethodChooser
        visible
        config={baseConfig}
        onChoose={onChoose}
        onDismiss={() => {}}
        merchantNameLoader={async () => null}
      />
    );
    fireEvent.press(screen.getByLabelText('Busha'));
    expect(onChoose).toHaveBeenCalledWith('bushaApp');
  });

  test('tapping Stablecoins calls onChoose with stablecoins', () => {
    const onChoose = jest.fn();
    render(
      <PaymentMethodChooser
        visible
        config={baseConfig}
        onChoose={onChoose}
        onDismiss={() => {}}
        merchantNameLoader={async () => null}
      />
    );
    fireEvent.press(screen.getByLabelText('Stablecoins'));
    expect(onChoose).toHaveBeenCalledWith('stablecoins');
  });

  test('tapping the close icon calls onDismiss', () => {
    const onDismiss = jest.fn();
    render(
      <PaymentMethodChooser
        visible
        config={baseConfig}
        onChoose={() => {}}
        onDismiss={onDismiss}
        merchantNameLoader={async () => null}
      />
    );
    fireEvent.press(screen.getByLabelText('Close'));
    expect(onDismiss).toHaveBeenCalled();
  });
});
