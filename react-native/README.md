# @busha/pay-react-native

Official React Native SDK for accepting crypto payments via Busha.

## Installation

```sh
npm install @busha/pay-react-native react-native-webview expo-application
# or
yarn add @busha/pay-react-native react-native-webview expo-application
```

### Bare React Native (no Expo) — one-time setup

If your app is bare React Native and you haven't adopted Expo modules yet,
run this once to enable `expo-application` and any future Expo-module peer
dependencies:

```sh
npx install-expo-modules@latest
```

This sets up the Expo modules infrastructure in your native iOS/Android
projects. It is a one-time change; after this step the SDK — and any
`expo-*` package — works like any other React Native library.

Expo managed, Expo dev client, and Expo Go users already have this and
need no extra setup.

## Quick Start

### 1. Wrap your app with `BushaPayProvider`

```tsx
import { BushaPayProvider } from '@busha/pay-react-native';

export default function App() {
  return (
    <BushaPayProvider publicKey="pub_xxx" environment="sandbox">
      {/* your app */}
    </BushaPayProvider>
  );
}
```

The provider reads your bundle ID automatically via `expo-application`
and derives the callback URL scheme from it (`<bundle_id>.busha-pay`).

### 2. Launch checkout

```tsx
import { useBushaPay } from '@busha/pay-react-native';

function CheckoutButton() {
  const { checkout } = useBushaPay();

  const onPress = async () => {
    const result = await checkout({
      quoteAmount: '10000',
      quoteCurrency: 'NGN',
      targetCurrency: 'NGN',
      sourceCurrency: 'USDT',
      metaName: 'Jane Doe',
      metaEmail: 'jane@example.com',
    });

    switch (result.type) {
      case 'success':
        // Verify via webhook server-side before fulfilling the order.
        console.log('Payment completed:', result.paymentId);
        break;
      case 'cancelled':
        console.log('User cancelled');
        break;
      case 'error':
        console.log('Error:', result.message, result.code);
        break;
    }
  };

  return <Button title="Pay Now" onPress={onPress} />;
}
```

### 3. Forward deep links to the SDK

The Busha app (and the web checkout's "I've paid" button) returns the
user to your app via a custom URL scheme. Your app owns URL delivery —
the SDK does not subscribe to `Linking` itself. Forward matching URLs to
`BushaPay.handleDeepLink`:

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

`BushaPay.handleDeepLink(url)` returns `true` if the URL was a Busha
callback and was consumed.

## Platform Setup

Both platforms need two things:

1. **Register your app's callback URL scheme** (`<bundle_id>.busha-pay`) so
   the Busha app can return the result to you.
2. **Declare the Busha app's URL scheme as launchable** so the SDK can
   deep-link into the installed Busha mobile app.

### Expo (managed or prebuild)

In your `app.json`, set the callback scheme and the iOS allow-list:

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

#### iOS — `ios/YourApp/Info.plist`

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
    <!-- Sandbox/staging Busha app (only if using environment="sandbox") -->
    <string>co.busha.boro.development</string>
</array>
```

#### Android — `android/app/src/main/AndroidManifest.xml`

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

Also add the Busha app package visibility to the root `<manifest>` element (required on Android 11+):

```xml
<manifest ...>
    <queries>
        <package android:name="co.busha.android" />
        <!-- Sandbox/staging only -->
        <package android:name="co.busha.android.development" />
    </queries>
    ...
</manifest>
```

### Testing the callback

Simulate a Busha callback to verify your setup:

```sh
# iOS simulator
xcrun simctl openurl booted "com.example.myapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_test"

# Android emulator
adb shell am start -a android.intent.action.VIEW \
  -d "com.example.myapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_test"
```

Replace `com.example.myapp` with your actual bundle ID. If everything is
wired up, your app comes to the foreground and `checkout()` resolves with
a success result.

## Result Types

`checkout()` resolves with a discriminated union:

```ts
type BushaPayResult =
  | { type: 'success'; paymentId: string; checkoutId: string; status: string; rawData?: Record<string, unknown> }
  | { type: 'cancelled' }
  | { type: 'error'; message: string; code?: string };
```

| `type` | Description |
|---|---|
| `'success'` | Payment completed. Contains `paymentId`, `checkoutId`, and `status`. Web-checkout flows also populate `rawData` with the full pug-pay response. |
| `'cancelled'` | User dismissed the checkout or backed out of the Busha app. |
| `'error'` | Something went wrong. Contains `message` and optional `code`. |

**Always verify the payment server-side via webhooks.** The client result is a UX hint, not the source of truth.

## Configuration

Fields on `BushaPayConfig` (the argument to `checkout()`):

| Field | Type | Required | Description |
|---|---|---|---|
| `quoteAmount` | `string` | yes | Amount to charge (e.g., `'10000'`) |
| `quoteCurrency` | `string` | yes | Currency for the amount (e.g., `'NGN'`) |
| `targetCurrency` | `string` | yes | Settlement currency |
| `sourceCurrency` | `string` | yes | Crypto asset the user pays with (e.g., `'USDT'`) |
| `reference` | `string` | no | Custom transaction reference |
| `metaName` | `string` | no | Customer name |
| `metaEmail` | `string` | no | Customer email |
| `metaPhone` | `string` | no | Customer phone |
| `source` | `string` | no | Source label (defaults to `'payment-link'` on the checkout side) |
| `sourceId` | `string` | no | Optional correlation ID for your own records |

## Find Your Public Key

1. Log in to the [Busha Business dashboard](https://dash.busha.io).
2. Go to **Settings → Developer Tools**.
3. Copy your **Public Key** (starts with `pub_`).

Use your sandbox key for testing and production key for live payments.

## License

MIT
