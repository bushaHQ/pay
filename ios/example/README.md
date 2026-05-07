# Busha Store (iOS example)

A small SwiftUI app that consumes the local `BushaPay` Swift Package via SPM. Mirrors the [Flutter](../../flutter/example/) and [React Native](../../react-native/example/) examples — same product list, same flow.

## Requirements

- Xcode 15+
- iOS 14+ Simulator
- A Busha **public key** (sandbox is fine — see [Find Your Public Key](../README.md#find-your-public-key)).
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen) **only if you want to regenerate** `BushaStore.xcodeproj` after editing [`project.yml`](./project.yml). The committed `.xcodeproj` works without it.

## Run

The app reads `BushaPublicKey` from the bundle's `Info.plist`, which is templated from the `BUSHA_PUBLIC_KEY` build setting (see [`project.yml`](./project.yml)). Easiest way is to source the repo's `.env`:

```bash
# from the repo root
set -a && . .env && set +a
cd ios/example
xcodebuild \
  -project BushaStore.xcodeproj \
  -scheme BushaStore \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  BUSHA_PUBLIC_KEY=$BUSHA_PUBLIC_KEY \
  build
```

Or open `BushaStore.xcodeproj` in Xcode, edit **BushaStore → Build Settings → User-Defined → BUSHA_PUBLIC_KEY**, paste your key, and ⌘R.

## Testing the callback round-trip

```bash
xcrun simctl openurl booted "co.busha.example.store.busha-pay://callback?status=completed&paymentRequestId=PAYR_test"
```

If wired correctly, the app comes to the foreground and the receipt screen shows `Payment successful`.

## What's wired up

This example applies everything documented in the SDK [README](../README.md):

- **Initialization** in `BushaStoreApp.swift`: `BushaPay.initialize(publicKey:, environment: .sandbox)`.
- **Callback URL scheme** in `Info.plist` via `CFBundleURLTypes` — derived from `$(PRODUCT_BUNDLE_IDENTIFIER).busha-pay`.
- **`LSApplicationQueriesSchemes`** for `co.busha.apple` (live) and `co.busha.boro.development` (sandbox), so `UIApplication.canOpenURL` can detect the Busha app.
- **Deep-link forwarding** via SwiftUI's `.onOpenURL { BushaPay.handleDeepLink($0) }`.
- **Checkout** via the completion-handler API in `ProductDetailView.swift`, presenting from the topmost view controller.

## Regenerating the Xcode project

After editing `project.yml`:

```bash
brew install xcodegen      # one-time
xcodegen generate
```
