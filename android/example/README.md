# Busha Store — Android example

A one-screen demo app that integrates the Busha Pay Android SDK: a
product, a **Pay** button, and a line that reports the checkout result.

It's wired as the `:example` module of the `android/` Gradle project and
depends on `:pay-android` directly (`implementation(project(":pay-android"))`),
so it always builds against the SDK source in this repo.

## Run it

1. Open the `android/` directory in Android Studio, or use the CLI below.
2. Put your sandbox public key in
   [`ExampleApp.kt`](src/main/kotlin/co/busha/pay/example/ExampleApp.kt)
   (`PUBLIC_KEY`) — grab one from
   [dash.busha.io](https://dash.busha.io) → Settings → Developer Tools.
3. Build and install on a device or emulator:

```bash
cd android
./gradlew :example:installDebug
```

## What it shows

- **Initialization** — `BushaPay.initialize(...)` in
  [`ExampleApp`](src/main/kotlin/co/busha/pay/example/ExampleApp.kt).
- **Checkout** — `BushaPay.checkout(...)` and result handling in
  [`StoreActivity`](src/main/kotlin/co/busha/pay/example/StoreActivity.kt).
- **Callback wiring** — the `${applicationId}.busha-pay` intent filter in
  [`AndroidManifest.xml`](src/main/AndroidManifest.xml) plus
  `BushaPay.handleDeepLink(...)` in `onCreate` / `onNewIntent`.

## Test the callback

With the app running:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "co.busha.pay.example.busha-pay://callback?status=completed&paymentRequestId=PAYR_test"
```

The app returns to the foreground and the status line shows the
delivered `Success` result.
