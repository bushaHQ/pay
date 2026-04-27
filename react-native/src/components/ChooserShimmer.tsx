import { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View } from 'react-native';

const kPrimary = '#EDF2ED';
const kBase = '#D1D9D1';
const kTile = '#FFFFFF';

export const ChooserShimmer = () => {
  const opacity = useRef(new Animated.Value(0.5)).current;

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, {
          toValue: 1,
          duration: 750,
          useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 0.5,
          duration: 750,
          useNativeDriver: true,
        }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, [opacity]);

  return (
    <View
      style={styles.container}
      accessibilityLabel="Loading payment options"
      accessible
    >
      <Animated.View style={[styles.body, { opacity }]}>
        <View style={styles.headerRow}>
          <SkeletonBox width={180} height={28} radius={6} />
          <SkeletonBox width={24} height={24} circle />
        </View>
        <View style={styles.gap8} />
        <SkeletonBox width={220} height={18} radius={6} />
        <View style={styles.gap32} />
        <SkeletonBox width={200} height={21} radius={6} />
        <View style={styles.gap12} />
        <SkeletonTile />
        <View style={styles.gap16} />
        <SkeletonTile />
        <View style={styles.gap32} />
        <View style={styles.footer}>
          <SkeletonBox width={60} height={14} radius={4} />
          <View style={styles.footerGap} />
          <SkeletonBox width={50} height={14} radius={4} />
        </View>
      </Animated.View>
    </View>
  );
};

type SkeletonBoxProps = {
  width: number | `${number}%`;
  height: number;
  radius?: number;
  circle?: boolean;
};

const SkeletonBox = ({
  width,
  height,
  radius = 0,
  circle = false,
}: SkeletonBoxProps) => (
  <View
    style={{
      width,
      height,
      backgroundColor: kBase,
      borderRadius: circle ? height / 2 : radius,
    }}
  />
);

const SkeletonTile = () => (
  <View style={styles.tile}>
    <SkeletonBox width={40} height={40} circle />
    <View style={styles.tileTextWrap}>
      <SkeletonBox width={110} height={18} radius={4} />
      <View style={styles.tileGap} />
      <SkeletonBox width="100%" height={14} radius={4} />
    </View>
    <SkeletonBox width={24} height={24} radius={4} />
  </View>
);

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: kPrimary },
  body: { padding: 20 },
  headerRow: {
    height: 48,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  tile: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderRadius: 16,
    backgroundColor: kTile,
  },
  tileTextWrap: { flex: 1, marginHorizontal: 16 },
  tileGap: { height: 4 },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  footerGap: { width: 8 },
  gap8: { height: 8 },
  gap12: { height: 12 },
  gap16: { height: 16 },
  gap32: { height: 32 },
});
