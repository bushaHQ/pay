import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { SvgXml } from 'react-native-svg';

import type { BushaPayConfig } from '../config';
import {
  BUSHA_ICON_SVG,
  BUSHA_LOGO_SVG,
  WALLET_OUTLINE_SVG,
} from '../svg-icons';

export type PaymentChoice = 'bushaApp' | 'stablecoins';

type Props = {
  visible: boolean;
  config: BushaPayConfig;
  onChoose: (choice: PaymentChoice) => void;
  onDismiss: () => void;
};

const formatAmount = (amount: string): string => {
  const n = Number(amount);
  if (!Number.isFinite(n)) return amount;
  const hasDecimals = n % 1 !== 0;
  const fixed = n.toFixed(hasDecimals ? 2 : 0);
  const [whole, fraction] = fixed.split('.');
  const grouped = (whole ?? '').replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return fraction ? `${grouped}.${fraction}` : grouped;
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
    animationType="fade"
    onRequestClose={onDismiss}
  >
    <Pressable style={styles.backdrop} onPress={onDismiss}>
      <Pressable style={styles.dialog} onPress={() => {}}>
        <View style={styles.body}>
          <View style={styles.header}>
            <Text style={styles.amount}>
              Pay {formatAmount(config.quoteAmount)} {config.quoteCurrency}
            </Text>
            <Pressable
              onPress={onDismiss}
              hitSlop={12}
              accessibilityRole="button"
              accessibilityLabel="Close"
            >
              <Text style={styles.close}>✕</Text>
            </Pressable>
          </View>
          <Text style={styles.merchant}>To Pushup Design Agency</Text>
          <View style={styles.gap32} />
          <Text style={styles.heading}>Choose a payment method</Text>
          <View style={styles.gap12} />
          <PaymentMethodTile
            name="Busha"
            description="Make payment directly from your busha account"
            iconXml={BUSHA_ICON_SVG}
            onPress={() => onChoose('bushaApp')}
          />
          <View style={styles.gap16} />
          <PaymentMethodTile
            name="Stablecoins"
            description="Make payment from an external wallet"
            iconXml={WALLET_OUTLINE_SVG}
            onPress={() => onChoose('stablecoins')}
          />
          <View style={styles.gap32} />
          <SecuredByFooter />
        </View>
      </Pressable>
    </Pressable>
  </Modal>
);

type TileProps = {
  name: string;
  description: string;
  iconXml: string;
  onPress: () => void;
};

const PaymentMethodTile = ({
  name,
  description,
  iconXml,
  onPress,
}: TileProps) => (
  <Pressable
    onPress={onPress}
    accessibilityRole="button"
    accessibilityLabel={name}
    style={styles.tile}
  >
    <View style={styles.iconCircle}>
      <SvgXml xml={iconXml} width={20} height={20} color={kTextHigh} />
    </View>
    <View style={styles.tileTextWrap}>
      <Text style={styles.tileName}>{name}</Text>
      <Text style={styles.tileDescription}>{description}</Text>
    </View>
    <Text style={styles.chevron}>›</Text>
  </Pressable>
);

const SecuredByFooter = () => (
  <View style={styles.footer}>
    <Text style={styles.footerText}>Secured by</Text>
    <View style={styles.footerGap} />
    <SvgXml xml={BUSHA_LOGO_SVG} height={14} width={63} />
  </View>
);

const kTextHigh = '#000000';
const kTextMid = '#586558';
const kContainmentPrimary = '#EDF2ED';
const kContainmentSecondary = '#D1D9D1';
const kContainmentTertiary = '#FFFFFF';

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'center',
    alignItems: 'stretch',
    paddingHorizontal: 16,
    paddingVertical: 24,
  },
  dialog: {
    backgroundColor: kContainmentPrimary,
    borderRadius: 20,
    overflow: 'hidden',
  },
  body: { padding: 20 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  amount: {
    fontSize: 24,
    fontWeight: '700',
    color: kTextHigh,
    flexShrink: 1,
  },
  close: { fontSize: 20, color: kTextHigh, paddingHorizontal: 4 },
  merchant: {
    marginTop: 8,
    fontSize: 16,
    fontWeight: '400',
    color: kTextMid,
  },
  heading: {
    fontSize: 18,
    fontWeight: '500',
    color: kTextHigh,
  },
  tile: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: kContainmentTertiary,
    borderRadius: 16,
    padding: 16,
  },
  iconCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: kContainmentSecondary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tileTextWrap: {
    flex: 1,
    marginHorizontal: 16,
  },
  tileName: { fontSize: 16, fontWeight: '600', color: kTextHigh },
  tileDescription: {
    marginTop: 2,
    fontSize: 12,
    fontWeight: '400',
    color: kTextMid,
  },
  chevron: { fontSize: 24, color: kTextMid, lineHeight: 24 },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  footerText: { fontSize: 12, fontWeight: '400', color: kTextMid },
  footerGap: { width: 8 },
  gap12: { height: 12 },
  gap16: { height: 16 },
  gap32: { height: 32 },
});
