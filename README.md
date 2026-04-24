# Busha Pay SDKs

Official Busha Pay SDKs — Flutter, Android, iOS, React Native. One repo, one flow, four languages.

## Status

| SDK | Location | Status |
|---|---|---|
| Flutter | [`flutter/`](./flutter) | ✅ Shipping |
| React Native | [`react-native/`](./react-native) | ✅ Shipping |
| Android | [`android/`](./android) | 🔜 Placeholder |
| iOS | [`ios/`](./ios) | 🔜 Placeholder |

## Repo layout

```
busha_pay/
├── shared/
│   └── busha_pay_checkout.html   # Single source of truth for the WebView shell
├── flutter/                      # Flutter SDK (Dart)
├── android/                      # Android SDK (Kotlin/Gradle)
├── ios/                          # iOS SDK (Swift Package)
├── react-native/                 # React Native SDK (TypeScript)
├── Makefile                      # SDK Orchestrator
└── .github/workflows/            # ci.yml + release.yml
```

The four SDKs share the same WebView shell — [`shared/busha_pay_checkout.html`](./shared/busha_pay_checkout.html) is the canonical copy. `make sync` copies it into every SDK's asset folder; the SDKs never edit their local copy.

The shared HTML is platform-agnostic: it's just a hidden form + an `initCheckout(config)` entry point. Everything platform-specific (the bridge to native, the `postMessage` listener, any WebView quirks) is injected by each SDK as a document-start user script that defines `window.BushaPayBridge(payload)`. Adding a new SDK means writing that shim once — the HTML never needs to branch on platform.

## Integration docs

Each SDK has its own README:

- [Flutter SDK docs](./flutter/README.md)
- [React Native SDK docs](./react-native/README.md)
- [Android SDK docs](./android/README.md) (coming soon)
- [iOS SDK docs](./ios/README.md) (coming soon)

## Contributing

```bash
make sync              # Copy the shared HTML into every SDK's asset folder
make build-flutter     # Build an individual SDK (build-android, build-ios, build-rn)
make build-all         # Or build them all
```

## License

MIT — see [LICENSE](./LICENSE).
