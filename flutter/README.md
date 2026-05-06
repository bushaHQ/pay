# Busha Pay Flutter SDK

[![CI](https://github.com/bushaHQ/pay/actions/workflows/ci.yml/badge.svg?branch=dev)](https://github.com/bushaHQ/pay/actions/workflows/ci.yml)
![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/bushaHQ/pay/dev/flutter/coverage-badge.json)

Official Flutter SDK for accepting crypto payments via Busha.

## Installation

```yaml
dependencies:
  busha_pay: ^0.0.1
```

### Installing from GitHub

The SDK is released as a zipped artifact on [github.com/bushaHQ/pay/releases](https://github.com/bushaHQ/pay/releases) under tags shaped `flutter/v<version>`. To consume a release directly from the monorepo without going through pub.dev, point your `pubspec.yaml` at the tag and the `flutter/` subfolder:

```yaml
dependencies:
  busha_pay:
    git:
      url: https://github.com/bushaHQ/pay
      ref: flutter/v0.0.1
      path: flutter
```

Replace `v0.0.1` with the version you want. Every git checkout re-resolves from the tagged commit, so your lockfile stays reproducible.

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:busha_pay/busha_pay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BushaPay.init(
    publicKey: 'pub_xxx',
    environment: BushaEnvironment.sandbox, // Use .live for production
  );

  runApp(const MyApp());
}
```

### 2. Launch Checkout

```dart
ElevatedButton(
  onPressed: () {
    BushaPay.checkout(
      context: context,
      config: BushaPayConfig(
        quoteAmount: '10000',
        quoteCurrency: 'NGN',
        targetCurrency: 'NGN',
        sourceCurrency: 'USDT',
        metaName: 'John Doe',
        metaEmail: 'john@example.com',
      ),
      onComplete: (result) {
        switch (result) {
          case BushaPaySuccess(:final paymentId):
            print('Payment $paymentId completed');
          case BushaPayCancelled():
            print('User cancelled');
          case BushaPayError(:final message):
            print('Error: $message');
        }
      },
    );
  },
  child: Text('Pay Now'),
)
```

## Platform Setup

Both platforms need two things:

1. **Register your app's callback URL scheme** so the Busha app can return the payment result to you (scheme is `<your.bundle.id>.busha-pay`).
2. **Declare the Busha app's URL scheme as launchable** so the SDK can deep-link into the Busha mobile app when it's installed.

### iOS

Add the following to `ios/Runner/Info.plist`:

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
    <!-- Sandbox/staging Busha app (only needed if you use BushaEnvironment.sandbox) -->
    <string>co.busha.boro.development</string>
</array>
```

### Android

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

Replace `com.example.myapp` with your actual package name / bundle identifier. If set up correctly, your app will come to the foreground and `onComplete` will fire with a `BushaPaySuccess` result.

## Forwarding the Callback to the SDK

The SDK does **not** subscribe to incoming URLs itself — that avoids conflicts with whatever deep-link mechanism your app already uses (Flutter's built-in `Router`, `app_links`, `uni_links`, etc.). You wire up URL delivery in your own app and forward Busha callbacks with a single call:

```dart
BushaPay.handleDeepLink(uri); // returns true if the URL was a Busha callback
```

### Important: `FlutterDeepLinkingEnabled` flag

Flutter has a built-in deep-link handler (see the [official guide](https://docs.flutter.dev/ui/navigation/deep-linking)) that, when enabled, routes incoming URLs through your app's `Router`/`Navigator`. Whether you want it on depends on how you're handling the callback:

| Your approach | `FlutterDeepLinkingEnabled` (iOS `Info.plist`) <br>`flutter_deeplinking_enabled` (Android `AndroidManifest.xml`) |
|---|---|
| Option A or B (Flutter `Router` / `go_router`) | **`true`** — let Flutter deliver URLs to your router |
| Option C or D (plugin: `app_links` / `uni_links`) | **`false`** — otherwise Flutter and the plugin both handle the same URL, stacking a second screen on top |

```xml
<!-- iOS: ios/Runner/Info.plist -->
<key>FlutterDeepLinkingEnabled</key>
<true/>   <!-- or <false/> -->
```

```xml
<!-- Android: android/app/src/main/AndroidManifest.xml — inside your <activity> -->
<meta-data
  android:name="flutter_deeplinking_enabled"
  android:value="true" />  <!-- or "false" -->
```

### Wiring options

Pick whichever matches the deep-link approach your app already uses. Each one ends with a call to `BushaPay.handleDeepLink(uri)` and returns `true` if the URL was a Busha callback.

#### Option A — Flutter `Router` API (directly)

If you're using `MaterialApp.router` with a `RouterDelegate` / `RouteInformationParser` of your own, intercept the incoming route info and route Busha callbacks to the SDK:

```dart
class AppRouteInformationParser extends RouteInformationParser<AppRoute> {
  @override
  Future<AppRoute> parseRouteInformation(RouteInformation info) async {
    final uri = info.uri;
    if (BushaPay.handleDeepLink(uri)) {
      // Consumed by the SDK — return a no-op / current route.
      return AppRoute.current();
    }
    // ...your own routing logic
    return AppRoute.fromUri(uri);
  }
}
```

Remember to set `FlutterDeepLinkingEnabled = true` on iOS and `flutter_deeplinking_enabled = "true"` on Android so Flutter delivers the URL to your parser.

#### Option B — `go_router`

Add a top-level `redirect` that consumes Busha callbacks before routing:

```dart
final router = GoRouter(
  routes: [...],
  redirect: (context, state) {
    if (BushaPay.handleDeepLink(state.uri)) {
      return null; // consumed — don't navigate anywhere
    }
    return null;
  },
);
```

Set `FlutterDeepLinkingEnabled = true` / `flutter_deeplinking_enabled = "true"` — `go_router` relies on Flutter's built-in delivery.

#### Option C — `app_links` package

```dart
import 'package:app_links/app_links.dart';

final _appLinks = AppLinks();

@override
void initState() {
  super.initState();
  _appLinks.uriLinkStream.listen(BushaPay.handleDeepLink);
}
```

Keep `FlutterDeepLinkingEnabled = false` / `flutter_deeplinking_enabled = "false"` so only `app_links` receives the URL.

#### Option D — `uni_links` package

```dart
import 'package:uni_links/uni_links.dart';

uriLinkStream.listen((uri) {
  if (uri != null) BushaPay.handleDeepLink(uri);
});
```

Keep `FlutterDeepLinkingEnabled = false` / `flutter_deeplinking_enabled = "false"` so only `uni_links` receives the URL.

## How It Works

1. The SDK opens a chooser with two options: **Pay with Busha app** or **Pay with stablecoins**.
2. **Busha app** — if the app is installed, the SDK deep-links into it. If it isn't, it falls back to the web checkout.
3. **Stablecoins** — opens the web checkout in an in-app WebView.
4. Either way, the result is delivered to your `onComplete` callback.

## Result Types

| Type | Description |
|------|-------------|
| `BushaPaySuccess` | Payment completed. Contains `paymentId` and `status`, plus optional full payment data. |
| `BushaPayCancelled` | User dismissed the checkout or backed out. |
| `BushaPayError` | Something went wrong. Contains `message` and optional `code`. |

### Full vs Limited Data

When payment completes via the **web checkout**, `BushaPaySuccess` includes full data: amounts, currencies, exchange rate, timeline, etc.

When payment completes via the **Busha app**, only `paymentId` and `status` are available. Use `result.hasFullData` to check.

**Always verify the payment server-side via webhooks.** The client result is a UX hint, not the source of truth.

### Common error codes

`BushaPayError.message` is **diagnostic** — useful for logs and support tickets but not safe to surface to end users verbatim. Branch on `BushaPayError.code` for UX decisions and craft your own user-facing copy:

| Code | Meaning |
|------|---------|
| `CHECKOUT_IN_PROGRESS` | A previous `BushaPay.checkout()` call hasn't resolved yet |
| `WEBVIEW_LOAD_ERROR` | Network failure, DNS error, or other platform-level load failure |
| `WEBVIEW_HTTP_ERROR` | Non-2xx HTTP response from the checkout endpoint |
| `WEBVIEW_TIMEOUT` | Checkout page didn't bootstrap within 30 seconds |
| `HTML_LOAD_ERROR` | The bundled checkout HTML asset failed to load |

`code` is also populated when the error originates from a Busha-app deep-link callback or from the checkout page itself — in those cases it carries whatever code the upstream system reported. Treat unknown codes as generic errors.

## Configuration

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `quoteAmount` | `String` | Yes | Amount to charge (e.g., `'10000'`) |
| `quoteCurrency` | `String` | Yes | Currency for the amount (e.g., `'NGN'`) |
| `targetCurrency` | `String` | Yes | Settlement currency |
| `sourceCurrency` | `String` | Yes | Crypto asset for payment (e.g., `'USDT'`) |
| `reference` | `String?` | No | Custom transaction reference |
| `metaName` | `String?` | No | Customer name |
| `metaEmail` | `String?` | No | Customer email |
| `metaPhone` | `String?` | No | Customer phone |

## Find Your Public Key

1. Log in to your [Busha Business dashboard](https://dash.busha.io).
2. Go to **Settings → Developer Tools**.
3. Copy your **Public Key** (starts with `pub_`).

Use your sandbox key for testing and production key for live payments.

## License

MIT