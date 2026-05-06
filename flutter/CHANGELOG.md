## 0.2.1 - 2026-05-06

- fix(sdk): point checkout URL at *.io (f1a2682)

## 0.2.0 - 2026-05-06

- refactor: move PaymentMethod into its own module (278f5e7)
- refactor(flutter): inline tile filter with collection-if instead of helper (69a55fe)
- docs: document allowedPaymentMethods on both SDK READMEs (f3b0c0f)
- feat: set allowedPaymentMethods on BushaPayConfig allowing to bypass chooser (da84cdf)
- Merge pull request #23 from bushaHQ/fix/webview-error-handling (05beb48)
- fix(sdk): tighten WebView error messages + document error codes (d22cdcb)
- fix(sdk): surface WebView load errors as BushaPayError (29cdb61)
- fix(sdk): use the correct query param when skipping the chooser (4224c96)

## 0.1.0 - 2026-05-06

- refactor: move PaymentMethod into its own module (278f5e7)
- refactor(flutter): inline tile filter with collection-if instead of helper (69a55fe)
- docs: document allowedPaymentMethods on both SDK READMEs (f3b0c0f)
- feat: set allowedPaymentMethods on BushaPayConfig allowing to bypass chooser (da84cdf)
- Merge pull request #23 from bushaHQ/fix/webview-error-handling (05beb48)
- fix(sdk): tighten WebView error messages + document error codes (d22cdcb)
- fix(sdk): surface WebView load errors as BushaPayError (29cdb61)
- fix(sdk): use the correct query param when skipping the chooser (4224c96)

## 0.1.1 - 2026-05-04

- refactor(sdk): drop source / sourceId from BushaPayConfig (214985a)
- fix(flutter): include checkout HTML asset in published package (0812831)

## 0.0.2 - 2026-04-24

- build(release): v0.0.2 [skip ci] (254e51c)
- docs(sdk): add install-from-GitHub instructions (a82a404)
- refactor: drop unused checkoutId from BushaPaySuccess (2c65456)
- chore: add example flutter app (84d77ab)
- chore: shim BushaPayBridge to native sdks (1cee2ee)
- feat: shared webview script (d93fac2)
- feat: early sdk version (2f7dede)

## 0.0.1

- Initial release
- Accept crypto payments with `BushaPay.checkout()`
- Pay with the Busha app or with stablecoins via in-app WebView
- Sandbox and live environment support
