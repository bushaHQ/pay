import { describe, expect, jest, test } from '@jest/globals';
import { render, screen } from '@testing-library/react-native';

jest.mock('expo-application');
jest.mock('react-native-svg');

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { ChooserShimmer } = require('../ChooserShimmer');

describe('ChooserShimmer', () => {
  test('renders with the loading payment options accessibility label', () => {
    render(<ChooserShimmer />);
    expect(
      screen.getByLabelText('Loading payment options')
    ).toBeTruthy();
  });

  test('unmounts cleanly without throwing', () => {
    const { unmount } = render(<ChooserShimmer />);
    expect(() => unmount()).not.toThrow();
  });
});
