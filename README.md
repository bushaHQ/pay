# Busha Pay SDKs

Official Busha Pay SDKs — Flutter, Android, iOS, React Native. One repo, one flow, four languages.

## Status

| SDK | Location | Status |
|---|---|---|
| Flutter | [`flutter/`](./flutter) | ✅ Released |
| React Native | [`react-native/`](./react-native) | ✅ Released |
| iOS | [`ios/`](./ios) | ✅ Released |
| Android | [`android/`](./android) | 🔜 Placeholder |

**Status legend** — ✅ **Released**: tagged on the registry/git and consumable by integrators. 🟡 **Ready**: code-complete and tested but not yet tagged. 🔜 **Placeholder**: not implemented.

## Repo layout

```
busha_pay/
├── shared/
│   ├── busha_pay_checkout.html   # Single source of truth for the WebView shell
│   └── icons/                    # Shared chooser icons
├── flutter/                      # Flutter SDK (Dart) + example app
├── react-native/                 # React Native SDK (TypeScript) + example app
├── ios/                          # iOS SDK (Swift Package) + example app
├── android/                      # Android SDK (Kotlin/Gradle)
├── Makefile                      # SDK orchestrator (sync / build / test / publish)
└── .github/workflows/            # ci.yml + release.yml
```

The SDKs share the same WebView shell — [`shared/busha_pay_checkout.html`](./shared/busha_pay_checkout.html) is the canonical copy. The Makefile's per-SDK sync targets copy it (and the chooser icons) into each SDK's expected asset format; the SDKs never edit their local copy.

The shared HTML is platform-agnostic: a hidden form plus an `initCheckout(config)` entry point. Everything platform-specific (the bridge to native, the `postMessage` listener, any WebView quirks) is injected by each SDK as a document-start user script that defines `window.BushaPayBridge(payload)`. Adding a new SDK means writing that shim once — the HTML never branches on platform.

## Integration docs

- [Flutter SDK](./flutter/README.md) · [example](./flutter/example/)
- [React Native SDK](./react-native/README.md) · [example](./react-native/example/)
- [iOS SDK](./ios/README.md) · [example](./ios/example/)
- [Android SDK](./android/README.md) (coming soon)

## Contributing

```bash
# Sync the shared HTML/icons into the SDK that needs them. Per-SDK
# targets only pull in the tooling that platform requires (e.g.
# `sync-ios` needs `librsvg` for SVG → PDF; `sync-rn` needs `node`).
make sync-flutter
make sync-rn
make sync-ios
make sync                # Or run all three at once

# Build / test individual SDKs
make build-flutter
make build-rn
make build-ios           # `make test-ios` for XCTest
make build-all           # All SDKs at once

# iOS example app — see `ios/example/README.md` for setup. After
# sourcing the repo's `.env`:
ios/example/scripts/run.sh
```

iOS-specific tools you'll need locally:

- Xcode 15+ with iOS 14+ simulators
- `librsvg` for `make sync-ios` (`brew install librsvg`)
- `xcodegen` only if you want to regenerate `ios/example/BushaStore.xcodeproj` after editing `ios/example/project.yml` (`brew install xcodegen`)

## License

MIT — see [LICENSE](./LICENSE).
