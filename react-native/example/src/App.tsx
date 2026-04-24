import { MaterialIcons } from '@expo/vector-icons';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Linking,
  Platform,
  Pressable,
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import {
  BushaPay,
  BushaPayProvider,
  useBushaPay,
  type BushaPayResult,
} from '@busha/pay-react-native';

const PUBLIC_KEY = process.env.EXPO_PUBLIC_BUSHA_PUBLIC_KEY ?? '';

type Product = {
  id: string;
  name: string;
  description: string;
  price: string;
  currency: string;
  emoji: string;
};

const PRODUCTS: Product[] = [
  {
    id: 'p1',
    name: 'Macbook Pro 13"',
    description: 'Apple M3 chip, 16GB unified memory, 512GB SSD storage.',
    price: '20000',
    currency: 'NGN',
    emoji: '💻',
  },
  {
    id: 'p2',
    name: 'iPhone 15 Pro',
    description: '256GB, Titanium. The best iPhone yet.',
    price: '15000',
    currency: 'NGN',
    emoji: '📱',
  },
  {
    id: 'p3',
    name: 'AirPods Pro',
    description:
      'Active Noise Cancellation, Transparency mode, Adaptive Audio.',
    price: '8500',
    currency: 'NGN',
    emoji: '🎧',
  },
];

type Screen =
  | { kind: 'home' }
  | { kind: 'detail'; product: Product }
  | { kind: 'receipt'; product: Product; result: BushaPayResult };

export default function App() {
  return (
    <SafeAreaProvider>
      <BushaPayProvider publicKey={PUBLIC_KEY} environment="sandbox">
        <Root />
      </BushaPayProvider>
    </SafeAreaProvider>
  );
}

function Root() {
  const [screen, setScreen] = useState<Screen>({ kind: 'home' });

  useEffect(() => {
    const sub = Linking.addEventListener('url', ({ url }) => {
      BushaPay.handleDeepLink(url);
    });
    Linking.getInitialURL().then((url) => {
      if (url) BushaPay.handleDeepLink(url);
    });
    return () => sub.remove();
  }, []);

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar barStyle="dark-content" />
      {screen.kind === 'home' && (
        <HomeScreen
          onSelect={(product) => setScreen({ kind: 'detail', product })}
        />
      )}
      {screen.kind === 'detail' && (
        <ProductDetailScreen
          product={screen.product}
          onBack={() => setScreen({ kind: 'home' })}
          onComplete={(result) =>
            setScreen({ kind: 'receipt', product: screen.product, result })
          }
        />
      )}
      {screen.kind === 'receipt' && (
        <ReceiptScreen
          product={screen.product}
          result={screen.result}
          onBackToStore={() => setScreen({ kind: 'home' })}
        />
      )}
    </SafeAreaView>
  );
}

function AppBar({ title, onBack }: { title: string; onBack?: () => void }) {
  return (
    <View style={styles.appBar}>
      {onBack ? (
        <Pressable onPress={onBack} hitSlop={12} style={styles.appBarLeading}>
          <MaterialIcons name="arrow-back" size={22} color="#111" />
        </Pressable>
      ) : (
        <View style={styles.appBarLeading} />
      )}
      <Text style={styles.appBarTitle} numberOfLines={1}>
        {title}
      </Text>
      <View style={styles.appBarLeading} />
    </View>
  );
}

function ProductRow({
  product,
  onPress,
}: {
  product: Product;
  onPress: () => void;
}) {
  return (
    <TouchableOpacity style={styles.card} onPress={onPress} activeOpacity={0.7}>
      <View style={styles.cardRow}>
        <Text style={styles.cardEmoji}>{product.emoji}</Text>
        <View style={styles.flex}>
          <Text style={styles.cardName}>{product.name}</Text>
          <Text style={styles.cardPrice}>₦{product.price}</Text>
        </View>
        <MaterialIcons name="chevron-right" size={22} color="#9e9e9e" />
      </View>
    </TouchableOpacity>
  );
}

const Separator = () => <View style={styles.separator} />;

function HomeScreen({ onSelect }: { onSelect: (p: Product) => void }) {
  return (
    <View style={styles.flex}>
      <AppBar title="Busha Store" />
      <FlatList
        data={PRODUCTS}
        keyExtractor={(p) => p.id}
        contentContainerStyle={styles.listContent}
        ItemSeparatorComponent={Separator}
        renderItem={({ item }) => (
          <ProductRow product={item} onPress={() => onSelect(item)} />
        )}
      />
    </View>
  );
}

function ProductDetailScreen({
  product,
  onBack,
  onComplete,
}: {
  product: Product;
  onBack: () => void;
  onComplete: (result: BushaPayResult) => void;
}) {
  const { checkout } = useBushaPay();
  const [isProcessing, setProcessing] = useState(false);

  const handleBuy = useCallback(async () => {
    setProcessing(true);
    try {
      const result = await checkout({
        quoteAmount: product.price,
        quoteCurrency: product.currency,
        targetCurrency: 'USDT',
        sourceCurrency: 'USDT',
        reference: `ORDER_${product.id}_${Date.now()}`,
        metaName: 'Test Customer',
        metaEmail: 'test@example.com',
      });
      onComplete(result);
    } finally {
      setProcessing(false);
    }
  }, [checkout, product, onComplete]);

  return (
    <View style={styles.flex}>
      <AppBar title={product.name} onBack={onBack} />
      <View style={styles.detailContainer}>
        <View style={styles.detailHero}>
          <Text style={styles.detailEmoji}>{product.emoji}</Text>
        </View>
        <Text style={styles.detailName}>{product.name}</Text>
        <Text style={styles.detailPrice}>₦{product.price}</Text>
        <Text style={styles.detailDescription}>{product.description}</Text>
        <View style={styles.flex} />
        <Pressable
          onPress={handleBuy}
          disabled={isProcessing}
          style={({ pressed }) => [
            styles.buyButton,
            (pressed || isProcessing) && styles.buyButtonPressed,
          ]}
        >
          {isProcessing ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <Text style={styles.buyButtonLabel}>Buy for ₦{product.price}</Text>
          )}
        </Pressable>
      </View>
    </View>
  );
}

type ReceiptInfo = {
  icon: keyof typeof MaterialIcons.glyphMap;
  color: string;
  title: string;
  details: string;
};

const receiptInfoFor = (result: BushaPayResult): ReceiptInfo => {
  switch (result.type) {
    case 'success':
      return {
        icon: 'check-circle',
        color: '#2e7d32',
        title: 'Payment successful',
        details: `Payment ID: ${result.paymentId}\nStatus: ${result.status}`,
      };
    case 'cancelled':
      return {
        icon: 'cancel',
        color: '#ef6c00',
        title: 'Payment cancelled',
        details: 'You cancelled the payment.',
      };
    case 'error':
      return {
        icon: 'error-outline',
        color: '#c62828',
        title: 'Payment failed',
        details: `Error: ${result.message}${result.code ? `\nCode: ${result.code}` : ''}`,
      };
  }
};

function ReceiptScreen({
  product,
  result,
  onBackToStore,
}: {
  product: Product;
  result: BushaPayResult;
  onBackToStore: () => void;
}) {
  const info = receiptInfoFor(result);
  return (
    <View style={styles.flex}>
      <AppBar title="Receipt" />
      <View style={styles.receiptContainer}>
        <View style={styles.receiptHeader}>
          <MaterialIcons name={info.icon} size={80} color={info.color} />
          <Text style={[styles.receiptTitle, { color: info.color }]}>
            {info.title}
          </Text>
        </View>
        <View style={styles.receiptCard}>
          <View style={styles.cardRow}>
            <Text style={styles.receiptProductEmoji}>{product.emoji}</Text>
            <View style={styles.flex}>
              <Text style={styles.cardName}>{product.name}</Text>
              <Text style={styles.cardPrice}>₦{product.price}</Text>
            </View>
          </View>
          <View style={styles.divider} />
          <Text style={styles.receiptDetails}>{info.details}</Text>
        </View>
        <View style={styles.flex} />
        <Pressable style={styles.secondaryButton} onPress={onBackToStore}>
          <Text style={styles.secondaryButtonLabel}>Back to store</Text>
        </Pressable>
      </View>
    </View>
  );
}

const BRAND = '#00C853';
const BORDER = '#eee';
const TEXT_SECONDARY = '#555';

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#fff' },
  flex: { flex: 1 },
  appBar: {
    height: 48,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: BORDER,
    backgroundColor: '#fff',
  },
  appBarLeading: { width: 32, alignItems: 'center', justifyContent: 'center' },
  appBarTitle: {
    flex: 1,
    fontSize: 17,
    fontWeight: '600',
    textAlign: 'center',
    color: '#111',
  },
  listContent: { padding: 16 },
  separator: { height: 12 },
  card: {
    borderWidth: 1,
    borderColor: BORDER,
    borderRadius: 12,
    padding: 16,
    backgroundColor: '#fff',
  },
  cardRow: { flexDirection: 'row', alignItems: 'center', gap: 16 },
  cardEmoji: { fontSize: 40 },
  cardName: { fontSize: 16, fontWeight: '600', color: '#111' },
  cardPrice: { fontSize: 14, color: TEXT_SECONDARY, marginTop: 4 },
  detailContainer: { flex: 1, padding: 24 },
  detailHero: { alignItems: 'center', marginBottom: 24 },
  detailEmoji: { fontSize: 120 },
  detailName: { fontSize: 24, fontWeight: '700', color: '#111' },
  detailPrice: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    marginTop: 8,
  },
  detailDescription: { fontSize: 14, color: TEXT_SECONDARY, marginTop: 16 },
  buyButton: {
    backgroundColor: BRAND,
    paddingVertical: 16,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  buyButtonPressed: { opacity: 0.85 },
  buyButtonLabel: { color: '#fff', fontSize: 16, fontWeight: '600' },
  receiptContainer: { flex: 1, padding: 24 },
  receiptHeader: { alignItems: 'center', marginTop: 32, marginBottom: 24 },
  receiptTitle: {
    fontSize: 22,
    fontWeight: '700',
    marginTop: 16,
    textAlign: 'center',
  },
  receiptCard: {
    borderWidth: 1,
    borderColor: BORDER,
    borderRadius: 12,
    padding: 16,
    backgroundColor: '#fff',
  },
  receiptProductEmoji: { fontSize: 32 },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: BORDER,
    marginVertical: 16,
  },
  receiptDetails: {
    fontSize: 12,
    fontFamily: Platform.select({
      ios: 'Courier',
      android: 'monospace',
      default: 'monospace',
    }),
    color: '#333',
  },
  secondaryButton: {
    borderWidth: 1,
    borderColor: BORDER,
    paddingVertical: 16,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 16,
  },
  secondaryButtonLabel: { fontSize: 16, fontWeight: '600', color: '#111' },
});
