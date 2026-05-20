# Busha Pay Android SDK

[![CI](https://github.com/bushaHQ/pay/actions/workflows/ci.yml/badge.svg?branch=dev)](https://github.com/bushaHQ/pay/actions/workflows/ci.yml)
![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/bushaHQ/pay/dev/android/coverage-badge.json)

Official Android (Kotlin) SDK for accepting crypto payments via Busha.

## Requirements

- Android 5.0 (API 21) or higher
- Kotlin 1.9+
- AndroidX

## Installation

The SDK is distributed via [JitPack](https://jitpack.io). Add the JitPack
repository — in `settings.gradle.kts`:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

Then add the dependency to your module's `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.github.bushaHQ.pay-android:pay-android:0.0.1")
}
```

> **Note:** the SDK is authored in the [bushaHQ/pay](https://github.com/bushaHQ/pay) monorepo under `android/`, and each release is mirrored to the standalone [bushaHQ/pay-android](https://github.com/bushaHQ/pay-android) repo that JitPack builds from. Issues, PRs, and source live in the monorepo.

The SDK ships with a single runtime dependency — `androidx.webkit` — which it uses to inject the checkout bridge reliably across WebView versions.

## Quick Start

### 1. Initialize the SDK

Call `initialize` once, ideally from your `Application`:

```kotlin
import android.app.Application
import co.busha.pay.BushaEnvironment
import co.busha.pay.BushaPay

class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        BushaPay.initialize(
            context = this,
            publicKey = "pub_xxx",
            environment = BushaEnvironment.SANDBOX, // or BushaEnvironment.LIVE
        )
    }
}
```

### 2. Launch checkout

```kotlin
import co.busha.pay.BushaPay
import co.busha.pay.BushaPayConfig
import co.busha.pay.BushaPayResult

BushaPay.checkout(
    activity = this,
    config = BushaPayConfig(
        quoteAmount = "10000",
        quoteCurrency = "NGN",
        targetCurrency = "NGN",
        sourceCurrency = "USDT",
        metaName = "Jane Doe",
        metaEmail = "jane@example.com",
    ),
) { result ->
    when (result) {
        is BushaPayResult.Success -> println("Paid: ${result.paymentId}")
        is BushaPayResult.Cancelled -> println("Cancelled: ${result.reason}")
        is BushaPayResult.Error -> println("Error: ${result.message}")
    }
}
```

The completion lambda is called **exactly once**, on the main thread.

## Platform setup

### Register your callback URL scheme

The SDK derives the callback URL scheme from your application id:

```
<your.application.id>.busha-pay
```

Add an `<intent-filter>` for it to the activity that should receive the
callback — typically your launcher activity — and give that activity
`launchMode="singleTask"` so the callback reuses the existing instance:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTask">

    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>

    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <!-- ${applicationId} is substituted at build time -->
        <data android:scheme="${applicationId}.busha-pay" />
    </intent-filter>
</activity>
```

### Launching the Busha app

To deep-link into the Busha app the SDK needs to query for it. The
required `<queries>` entries (and the `INTERNET` permission) ship in the
SDK's own manifest and merge into your app automatically — no setup
needed on your side.

## Forwarding the callback to the SDK

The SDK does **not** register a deep-link receiver itself — that avoids
conflicts with whatever URL handling your app already does. Forward
Busha callbacks from the activity that owns the intent filter:

```kotlin
import android.content.Intent
import android.os.Bundle
import co.busha.pay.BushaPay

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forwardBushaCallback(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        forwardBushaCallback(intent)
    }

    private fun forwardBushaCallback(intent: Intent?) {
        val data = intent?.data?.toString() ?: return
        // returns true if the URL was a Busha Pay callback
        BushaPay.handleDeepLink(data)
    }
}
```

### Testing the callback

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "com.example.myapp.busha-pay://callback?status=completed&paymentRequestId=PAYR_test"
```

Replace `com.example.myapp` with your application id. If wired
correctly, your app comes to the foreground and the
`BushaPay.checkout(…)` completion fires with a `Success` result.

## How it works

1. The SDK opens a chooser with two options: **Busha** or **Stablecoins**.
2. **Busha** — if the Busha app is installed, the SDK deep-links into it.
   If not, it falls back to the web checkout.
3. **Stablecoins** — opens the web checkout in a translucent Activity
   hosting a `WebView`.
4. The result is delivered to the completion lambda.

## Result types

`BushaPayResult` is a sealed interface:

| Type | Description |
|---|---|
| `BushaPayResult.Success` | Payment completed. Contains `paymentId` and `status`, plus optional full payment data. |
| `BushaPayResult.Cancelled` | Checkout ended without a completed payment. Inspect `reason` (see below). |
| `BushaPayResult.Error` | Something went wrong. Contains `message` and an optional `code`. |

### Cancellation reasons

`BushaPayResult.Cancelled` carries a `reason` so you can tell *how* the
checkout ended:

| `BushaPayCancelledReason` | Meaning |
|---|---|
| `DISMISSED` | The user closed the chooser or the web checkout sheet. |
| `REJECTED` | The Busha app reported the user explicitly rejected the payment. `paymentId` is populated so you can reconcile the request server-side. |
| `ABANDONED` | The user returned from the Busha app without a callback. The outcome is **unverified** — the payment may still have succeeded. Always reconcile server-side (webhook / status API) before showing the user a final state. |

### Full vs limited data

When payment completes via the **web checkout**, `BushaPayResult.Success`
includes full data (amounts, currencies). When payment completes via the
**Busha app**, only `paymentId` and `status` are available — check
`result.hasFullData`.

**Always verify the payment server-side via webhooks.** The client
result is a UX hint, not the source of truth.

### Common error codes

`BushaPayResult.Error.message` is **diagnostic** — useful for logs and
support tickets but not safe to surface to end users verbatim. Branch on
`code` for UX decisions:

| Code | Meaning |
|---|---|
| `CHECKOUT_IN_PROGRESS` | A previous `BushaPay.checkout(…)` call hasn't resolved yet |
| `WEBVIEW_LOAD_ERROR` | Network failure, DNS error, or other platform-level load failure |
| `WEBVIEW_HTTP_ERROR` | Non-2xx HTTP response from the checkout endpoint |
| `WEBVIEW_TIMEOUT` | Checkout page didn't bootstrap within 30 seconds |
| `WEBVIEW_PROCESS_TERMINATED` | The WebView renderer process was killed by the system |
| `HTML_LOAD_ERROR` | The bundled checkout HTML asset failed to load |
| `BUSHA_APP_LAUNCH_FAILED` | The Busha app deep-link launch failed |

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
| `allowedPaymentMethods` | `List<PaymentMethod>?` | No | Restricts which payment methods the chooser offers. See [Restricting payment methods](#restricting-payment-methods). |

## Restricting payment methods

By default, checkout shows a chooser with two tiles: **Busha** and
**Stablecoins**. Pass `allowedPaymentMethods` to skip the chooser or
hide tiles:

```kotlin
BushaPayConfig(
    quoteAmount = "10000",
    quoteCurrency = "NGN",
    targetCurrency = "NGN",
    sourceCurrency = "USDT",
    // Skip the chooser and route directly to the Busha app
    // (with web fallback if it isn't installed).
    allowedPaymentMethods = listOf(PaymentMethod.BUSHA_APP),
)
```

| `allowedPaymentMethods` | Behavior |
|---|---|
| `null` (default) or `emptyList()` | Show the full chooser. |
| `[BUSHA_APP]` | Skip the chooser; deep-link into the Busha app, falling through to the web checkout if the app isn't installed. |
| `[STABLECOINS]` | Skip the chooser; open the web checkout directly. |
| `[BUSHA_APP, STABLECOINS]` | Show the chooser with only those tiles. |

## Find your public key

1. Log in to your [Busha Business dashboard](https://dash.busha.io).
2. Go to **Settings → Developer Tools**.
3. Copy your **Public Key** (starts with `pub_`).

Use your sandbox key for testing and production key for live payments.

## Building locally

From the repo root:

```bash
make build-android   # sync shared assets + assemble the release AAR
```

Or directly with Gradle, from `android/`:

```bash
./gradlew :pay-android:assembleRelease
./gradlew :pay-android:jacocoTestReport   # unit tests + coverage
```

`make sync-android` copies the shared checkout HTML and converts the
shared SVG icons into Android vector drawables. It needs `node` on your
`PATH` (it shells out to `svg2vectordrawable` via `npx`).

## License

MIT
