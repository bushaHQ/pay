# Busha Pay React Native SDK

Official React Native SDK for accepting crypto payments via Busha.

## Installation

```sh
npm install @busha/pay-react-native react-native-webview expo-application
# or
yarn add @busha/pay-react-native react-native-webview expo-application
```

### Installing from GitHub

Each release ships an npm-installable tarball on [github.com/bushaHQ/pay/releases](https://github.com/bushaHQ/pay/releases) under tags shaped `react-native/v<version>`. You can install it directly from the release URL without going through the npm registry:

```sh
npm install https://github.com/bushaHQ/pay/releases/download/react-native/v0.0.1/busha_pay_react_native-0.0.1.tgz
# or with yarn:
yarn add https://github.com/bushaHQ/pay/releases/download/react-native/v0.0.1/busha_pay_react_native-0.0.1.tgz
```

Replace `v0.0.1` with the version you want. The peer deps (`react-native-webview`, `expo-application`) still need to be installed separately:

```sh
npm install react-native-webview expo-application
```

### Bare React Native — one-time setup

If your app is bare React Native and you haven't adopted Expo modules yet,
run this once to enable `expo-application` and any other `expo-*` peer
dependency:

```sh
npx install-expo-modules@latest
```

Expo managed, Expo dev client, and Expo Go users already have this and
need no extra setup.

## Quick Start

### 1. Initialize the SDK

Wrap your app with `BushaPayProvider`. The provider calls `BushaPay.init()`
on mount and auto-detects your app's bundle ID.

```tsx
import { BushaPayProvider } from '@busha/pay-react-native';

export default function App() {
  return (
    <BushaPayProvider publicKey="pub_xxx" environment="sandbox">
      <Home />
    </BushaPayProvider>
  );
}
```

Use `environment="live"` for production.

### 2. Launch Checkout

```tsx
import { Button } from 'react-native';
import { useBushaPay } from '@busha/pay-react-native';

function PayButton() {
  const { checkout } = useBushaPay();

  const onPress = async () => {
    const result = await checkout({
      quoteAmount: '10000',
      quoteCurrency: 'NGN',
      targetCurrency: 'NGN',
      sourceCurrency: 'USDT',
      metaName: 'John Doe',
      metaEmail: 'john@example.com',
    });

    switch (result.type) {
      case 'success':
        console.log('Payment completed:', result.paymentId);
        break;
      case 'cancelled':
        console.log('User cancelled');
        break;
      case 'error':
        console.log('Error:', result.message);
        break;
    }
  };

  return <Button title="Pay Now" onPress={onPress} />;
}
```

## Platform Setup

Both platforms need two things:

1. **Register your app's callback URL scheme** so the Busha app can return the payment result to you (scheme is `<your.bundle.id>.busha-pay`).
2. **Declare the Busha app's URL scheme as launchable** so the SDK can deep-link into the Busha mobile app when it's installed.

### Expo (managed or prebuild)

In `app.json`:

```json
{
  "expo": {
    "ios": {
      "bundleIdentifier": "com.example.myapp",
      "infoPlist": {
        "LSApplicationQueriesSchemes": [
          "co.busha.apple",
          "co.busha.boro.development"
        ]
      }
    },
    "android": {
      "package": "com.example.myapp"
    },
    "scheme": "com.example.myapp.busha-pay"
  }
}
```

Replace `com.example.myapp` with your real bundle ID / package name.

Android package-visibility queries (needed on Android 11+ so the Busha
app is discoverable by `canOpenURL`) are set via
[`expo-build-properties`](https://docs.expo.dev/versions/latest/sdk/build-properties/):

```sh
npx expo install expo-build-properties
```

```json
{
  "expo": {
    "plugins": [
      [
        "expo-build-properties",
        {
          "android": {
            "manifestQueries": {
              "package": [
                "co.busha.android",
                "co.busha.android.development"
              ]
            }
          }
        }
      ]
    ]
  }
}
```

### Bare React Native

#### iOS

Add the following to `ios/YourApp/Info.plist`:

```xml
<!-- 1. Register your app's callback URL scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER).busha-pay</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER).busha-pay</string>
        </array>
    </dict>
</array>

<!-- 2. Allow the SDK to launch the Busha app -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <!-- Production Busha app -->
    <string>co.busha.apple</string>
    <!-- Sandbox/staging Busha app (only needed if you use environment="sandbox") -->
    <string>co.busha.boro.development</string>
</array>
```

#### Android

Add the callback `<intent-filter>` to the main `<activity>` in `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    ...>
    <!-- existing intent-filters -->

    <!-- 1. Register your app's callback URL scheme -->
    <intent-filter android:autoVerify="false">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="${applicationId}.busha-pay" />
    </intent-filter>
</activity>
```

Also add the Busha app package visibility to the manifest's root `<manifest>` element (required on Android 11+):

```xml
<manifest ...>
    <!-- 2. Allow the SDK to launch the Busha app -->
    <queries>
        <package android:name="co.busha.android" />
        <!-- Sandbox/staging only -->
        <package android:name="co.busha.android.development" />
    </queries>
    ...
</manifest>
```

### Testing the callback

You can simulate a callback from the Busha app to verify your setup:

```bash
# iOS simulator
xcrun simctl openurl booted "com.example.myapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_test"

# Android emulator
adb shell am start -a android.intent.action.VIEW \
  -d "com.example.myapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_test"
```

Replace `com.example.myapp` with your actual package name / bundle identifier. If set up correctly, your app will come to the foreground and `checkout()` will resolve with a success result.

## Forwarding the Callback to the SDK

The SDK does **not** subscribe to incoming URLs itself — that avoids conflicts with whatever deep-link mechanism your app already uses (React Native `Linking`, `expo-linking`, React Navigation's `linking` config, etc.). You wire up URL delivery in your own app and forward Busha callbacks with a single call:

```ts
BushaPay.handleDeepLink(url); // returns true if the URL was a Busha callback
```

### Wiring options

Pick whichever matches the deep-link approach your app already uses. Each one ends with a call to `BushaPay.handleDeepLink(url)` and returns `true` if the URL was a Busha callback.

#### Option A — Built-in `Linking` (vanilla React Native)

```tsx
import { useEffect } from 'react';
import { Linking } from 'react-native';
import { BushaPay } from '@busha/pay-react-native';

useEffect(() => {
  const sub = Linking.addEventListener('url', ({ url }) => {
    BushaPay.handleDeepLink(url);
  });
  Linking.getInitialURL().then((url) => {
    if (url) BushaPay.handleDeepLink(url);
  });
  return () => sub.remove();
}, []);
```

#### Option B — `expo-linking`

```tsx
import { useEffect } from 'react';
import * as Linking from 'expo-linking';
import { BushaPay } from '@busha/pay-react-native';

useEffect(() => {
  const sub = Linking.addEventListener('url', ({ url }) => {
    BushaPay.handleDeepLink(url);
  });
  Linking.getInitialURL().then((url) => {
    if (url) BushaPay.handleDeepLink(url);
  });
  return () => sub.remove();
}, []);
```

#### Option C — React Navigation (`linking` config)

If your app uses `@react-navigation/native`'s deep-link handling, hook in via a `subscribe` function that forwards the URL to the SDK first, then falls through to navigation:

```tsx
import { NavigationContainer } from '@react-navigation/native';
import { Linking } from 'react-native';
import { BushaPay } from '@busha/pay-react-native';

const linking = {
  prefixes: ['com.example.myapp.busha-pay://', 'https://yourapp.com'],
  config: { /* your screens */ },
  subscribe(listener) {
    const sub = Linking.addEventListener('url', ({ url }) => {
      if (BushaPay.handleDeepLink(url)) return; // consumed by the SDK
      listener(url);
    });
    return () => sub.remove();
  },
};

<NavigationContainer linking={linking}>
  {/* ... */}
</NavigationContainer>
```

## How It Works

1. The SDK opens a chooser with two options: **Pay with Busha app** or **Pay with stablecoins**.
2. **Busha app** — if the app is installed, the SDK deep-links into it. If it isn't, it falls back to the web checkout.
3. **Stablecoins** — opens the web checkout in an in-app WebView.
4. Either way, the result is delivered to the promise returned by `checkout()`.

## Result Types

`checkout()` resolves with a discriminated union. Narrow by `result.type`:

| `type` | Description |
|---|---|
| `'success'` | Payment completed. Contains `paymentId` and `status`, plus optional full data. |
| `'cancelled'` | User dismissed the checkout or backed out. |
| `'error'` | Something went wrong. Contains `message` and optional `code`. |

```ts
type BushaPayResult =
  | {
      type: 'success';
      paymentId: string;
      status: string;
      hasFullData: boolean;
      // Populated only when `hasFullData === true` (web checkout path):
      sourceAmount?: string;
      sourceCurrency?: string;
      targetAmount?: string;
      targetCurrency?: string;
      requestedAmount?: string;
      currency?: string;
      rate?: Record<string, unknown>;
      merchantInfo?: Record<string, unknown>;
      timeline?: Record<string, unknown>;
      rawData?: Record<string, unknown>;
    }
  | { type: 'cancelled' }
  | { type: 'error'; message: string; code?: string };
```

### Full vs Limited Data

When payment completes via the **web checkout**, `BushaPaySuccess` includes full data: amounts, currencies, exchange rate, timeline, etc.

When payment completes via the **Busha app**, only `paymentId` and `status` are available. Use `result.hasFullData` to check.

**Always verify the payment server-side via webhooks.** The client result is a UX hint, not the source of truth.

## Configuration

| Parameter | Type | Required | Description |
|---|---|---|---|
| `quoteAmount` | `string` | Yes | Amount to charge (e.g., `'10000'`) |
| `quoteCurrency` | `string` | Yes | Currency for the amount (e.g., `'NGN'`) |
| `targetCurrency` | `string` | Yes | Settlement currency |
| `sourceCurrency` | `string` | Yes | Crypto asset for payment (e.g., `'USDT'`) |
| `reference` | `string?` | No | Custom transaction reference |
| `metaName` | `string?` | No | Customer name |
| `metaEmail` | `string?` | No | Customer email |
| `metaPhone` | `string?` | No | Customer phone |
| `source` | `string?` | No | Source label. Defaults to `'payment-link'`. |
| `sourceId` | `string?` | No | Optional ID you use to correlate the payment with your own records. |

## Find Your Public Key

1. Log in to your [Busha Business dashboard](https://dash.busha.io).
2. Go to **Settings → Developer Tools**.
3. Copy your **Public Key** (starts with `pub_`).

Use your sandbox key for testing and production key for live payments.

## License

MIT
