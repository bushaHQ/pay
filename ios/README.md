# Busha Pay iOS SDK

[![CI](https://github.com/bushaHQ/pay/actions/workflows/ci.yml/badge.svg?branch=dev)](https://github.com/bushaHQ/pay/actions/workflows/ci.yml)
![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/bushaHQ/pay/dev/ios/coverage-badge.json)

Official iOS (Swift Package) SDK for accepting crypto payments via Busha.

## Requirements

- iOS 14+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies…** and enter:

```
https://github.com/bushaHQ/pay-ios
```

Pick the version and add the **BushaPay** library to your target.

For a `Package.swift`:

```swift
.package(url: "https://github.com/bushaHQ/pay-ios", from: "0.0.1"),
```

then list `BushaPay` as a target dependency.

> **Note:** the SDK is authored in the [bushaHQ/pay](https://github.com/bushaHQ/pay) monorepo under `ios/`. Each release is mirrored to the standalone [bushaHQ/pay-ios](https://github.com/bushaHQ/pay-ios) repo above so Swift Package Manager can resolve it the way it expects (`Package.swift` at root, plain `v<version>` tags). Issues, PRs, and source live in the monorepo.

## Quick Start

### 1. Initialize the SDK

In your `AppDelegate` or `@main` app:

```swift
import BushaPay

BushaPay.initialize(
    publicKey: "pub_xxx",
    environment: .sandbox  // or .live
)
```

### 2. Launch checkout

```swift
import BushaPay
import UIKit

final class CheckoutButton: UIButton {
    func payNow(from presenter: UIViewController) {
        BushaPay.checkout(
            config: BushaPayConfig(
                quoteAmount: "10000",
                quoteCurrency: "NGN",
                targetCurrency: "NGN",
                sourceCurrency: "USDT",
                metaName: "Jane Doe",
                metaEmail: "jane@example.com"
            ),
            from: presenter
        ) { result in
            switch result {
            case .success(let payment):
                print("Paid: \(payment.paymentId)")
            case .cancelled(let cancelled):
                print("Cancelled: \(cancelled.reason)")
            case .error(let err):
                print("Error: \(err.message)")
            }
        }
    }
}
```

Or with async/await:

```swift
let result = await BushaPay.checkout(config: config, from: viewController)
```

## Platform setup

### Register your callback URL scheme

The SDK derives the callback URL scheme from your bundle identifier:

```
<your.bundle.id>.busha-pay
```

Add this to `Info.plist` under `CFBundleURLTypes`:

```xml
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
```

### Allow launching the Busha app

Add the Busha app's URL schemes to `LSApplicationQueriesSchemes` so `UIApplication.canOpenURL(_:)` returns `true` when the app is installed:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <!-- Production Busha app -->
    <string>co.busha.apple</string>
    <!-- Sandbox/staging Busha app (only needed if you use .sandbox) -->
    <string>co.busha.boro.development</string>
</array>
```

## Forwarding the callback to the SDK

The SDK does **not** subscribe to incoming URLs itself — that avoids conflicts with whatever URL handling your app already does (Universal Links, scene-delegate routing, third-party deep-link libs, etc.). You forward Busha callbacks with one call:

```swift
BushaPay.handleDeepLink(url) // returns true if the URL was a Busha callback
```

### Where to call it

#### `UIApplicationDelegate` (UIKit lifecycle)

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if BushaPay.handleDeepLink(url) {
        return true
    }
    // …your own URL handling…
    return false
}
```

#### `UISceneDelegate` (scene-based apps)

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
        if BushaPay.handleDeepLink(context.url) { continue }
        // …your own URL handling…
    }
}
```

#### SwiftUI app

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if BushaPay.handleDeepLink(url) { return }
                    // …your own URL handling…
                }
        }
    }
}
```

### Testing the callback

```bash
xcrun simctl openurl booted "com.example.myapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_test"
```

Replace `com.example.myapp` with your bundle identifier. If wired correctly, your app comes to the foreground and the `BushaPay.checkout(…)` completion fires with `.success(_)`.

## How it works

1. The SDK opens a chooser with two options: **Pay with Busha app** or **Pay with Stablecoins**.
2. **Busha app** — if installed (`UIApplication.canOpenURL`), the SDK deep-links into it. If not, it falls back to the web checkout.
3. **Stablecoins** — opens the web checkout in an in-app `WKWebView`.
4. The result is delivered to the completion handler.

## Result types

| Case | Description |
|---|---|
| `.success(BushaPaySuccess)` | Payment completed. Contains `paymentId` and `status`, plus optional full payment data. |
| `.cancelled(BushaPayCancelled)` | Checkout ended without a completed payment. Inspect `reason` (see below). |
| `.error(BushaPayError)` | Something went wrong. Contains `message` and optional `code`. |

### Cancellation reasons

`BushaPayCancelled` carries a `reason` so you can tell *how* the checkout ended:

| `BushaPayCancelledReason` | Meaning |
|---|---|
| `.dismissed` | The user closed the in-app chooser or web checkout sheet. |
| `.rejected` | The Busha app reported the user explicitly rejected the payment. `paymentId` is populated so you can reconcile the request server-side. |
| `.abandoned` | The user returned from the Busha app without a callback. The outcome is **unverified** — the payment may still have succeeded. Always reconcile server-side (webhook / status API) before showing the user a final state. |

### Full vs limited data

When payment completes via the **web checkout**, `BushaPaySuccess` includes full data (amounts, currencies). When payment completes via the **Busha app**, only `paymentId` and `status` are available — check `result.hasFullData`.

**Always verify the payment server-side via webhooks.** The client result is a UX hint, not the source of truth.

### Common error codes

`BushaPayError.message` is **diagnostic** — useful for logs and support tickets but not safe to surface to end users verbatim. Branch on `BushaPayError.code` for UX decisions:

| Code | Meaning |
|---|---|
| `CHECKOUT_IN_PROGRESS` | A previous `BushaPay.checkout(…)` call hasn't resolved yet |
| `WEBVIEW_LOAD_ERROR` | Network failure, DNS error, or other platform-level load failure |
| `WEBVIEW_HTTP_ERROR` | Non-2xx HTTP response from the checkout endpoint |
| `WEBVIEW_TIMEOUT` | Checkout page didn't bootstrap within 30 seconds |
| `HTML_LOAD_ERROR` | The bundled checkout HTML resource failed to load |
| `BUSHA_APP_LAUNCH_FAILED` | `UIApplication.open` reported the deep-link launch as unsuccessful |

## Configuration

| Parameter | Type | Required | Description |
|---|---|---|---|
| `quoteAmount` | `String` | Yes | Amount to charge (e.g., `"10000"`) |
| `quoteCurrency` | `String` | Yes | Currency for the amount (e.g., `"NGN"`) |
| `targetCurrency` | `String` | Yes | Settlement currency |
| `sourceCurrency` | `String` | Yes | Crypto asset for payment (e.g., `"USDT"`) |
| `reference` | `String?` | No | Custom transaction reference |
| `metaName` | `String?` | No | Customer name |
| `metaEmail` | `String?` | No | Customer email |
| `metaPhone` | `String?` | No | Customer phone |
| `allowedPaymentMethods` | `[PaymentMethod]?` | No | Restricts which payment methods the chooser offers. See [Restricting payment methods](#restricting-payment-methods). |

## Restricting payment methods

By default, checkout shows a chooser with two tiles: **Busha** and **Stablecoins**. Pass `allowedPaymentMethods` to skip the chooser or hide tiles:

```swift
BushaPayConfig(
    quoteAmount: "10000",
    quoteCurrency: "NGN",
    targetCurrency: "NGN",
    sourceCurrency: "USDT",
    // Skip the chooser and route directly to the Busha app
    // (with web fallback if it isn't installed).
    allowedPaymentMethods: [.bushaApp]
)
```

| `allowedPaymentMethods` | Behavior |
|---|---|
| `nil` (default) or `[]` | Show the full chooser. |
| `[.bushaApp]` | Skip the chooser; deep-link into the Busha app, falling through to the web checkout if the app isn't installed. |
| `[.stablecoins]` | Skip the chooser; open the web checkout directly. |
| `[.bushaApp, .stablecoins]` | Show the chooser with only those tiles. |

## Find your public key

1. Log in to your [Busha Business dashboard](https://dash.busha.io).
2. Go to **Settings → Developer Tools**.
3. Copy your **Public Key** (starts with `pub_`).

Use your sandbox key for testing and production key for live payments.

## Building locally

The package builds with `xcodebuild` against an iOS simulator destination. From the repo root:

```bash
make build-ios
make test-ios
```

Override the destination with `IOS_DESTINATION=…` if you don't have an iPhone simulator handy.

## License

MIT
