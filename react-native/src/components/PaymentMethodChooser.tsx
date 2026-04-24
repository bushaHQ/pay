import {
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

import type { BushaPayConfig } from '../config';

export type PaymentChoice = 'bushaApp' | 'stablecoins';

type Props = {
  visible: boolean;
  config: BushaPayConfig;
  onChoose: (choice: PaymentChoice) => void;
  onDismiss: () => void;
};

export const PaymentMethodChooser = ({
  visible,
  config,
  onChoose,
  onDismiss,
}: Props) => (
  <Modal
    visible={visible}
    transparent
    animationType="slide"
    onRequestClose={onDismiss}
  >
    <Pressable style={styles.backdrop} onPress={onDismiss}>
      <Pressable style={styles.sheet} onPress={() => {}}>
        <View style={styles.handle} />
        <Text style={styles.title}>
          Pay {config.quoteAmount} {config.quoteCurrency}
        </Text>
        <Text style={styles.subtitle}>How would you like to pay?</Text>

        <TouchableOpacity
          style={styles.option}
          onPress={() => onChoose('bushaApp')}
          accessibilityRole="button"
          accessibilityLabel="Pay with Busha app"
        >
          <Text style={styles.optionTitle}>Pay with Busha app</Text>
          <Text style={styles.optionBody}>
            Redirect to the Busha app to complete your payment.
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.option}
          onPress={() => onChoose('stablecoins')}
          accessibilityRole="button"
          accessibilityLabel="Pay with stablecoins"
        >
          <Text style={styles.optionTitle}>Pay with stablecoins</Text>
          <Text style={styles.optionBody}>
            Pay from any external wallet without leaving the app.
          </Text>
        </TouchableOpacity>
      </Pressable>
    </Pressable>
  </Modal>
);

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  sheet: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    padding: 20,
    paddingBottom: 36,
  },
  handle: {
    alignSelf: 'center',
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#ddd',
    marginBottom: 16,
  },
  title: { fontSize: 20, fontWeight: '600', marginBottom: 4 },
  subtitle: { fontSize: 14, color: '#666', marginBottom: 16 },
  option: {
    padding: 16,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#eee',
    marginBottom: 12,
  },
  optionTitle: { fontSize: 16, fontWeight: '600', marginBottom: 4 },
  optionBody: { fontSize: 13, color: '#666' },
});
