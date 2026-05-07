#!/usr/bin/env bash
# Build, install, and launch the BushaStore example on an iOS simulator.
#
# Picks the destination in this order:
#   1. Any iOS simulator that is already in `Booted` state — reuse it.
#   2. Else: $SIM_FALLBACK_NAME on the latest installed iOS runtime.
#
# Reads BUSHA_PUBLIC_KEY from the environment (the VS Code launch config
# wires this via `envFile`; on the command line, source the repo's .env
# first: `set -a && . .env && set +a && ios/example/scripts/run.sh`).
#
# Override the fallback with:
#   SIM_FALLBACK_NAME="iPhone 17 Pro" ios/example/scripts/run.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEME="BushaStore"
BUNDLE_ID="co.busha.example.store"
SIM_FALLBACK_NAME="${SIM_FALLBACK_NAME:-iPhone 16 Pro Max}"
DERIVED_DATA="$EXAMPLE_DIR/build/derivedData"

if [ -z "${BUSHA_PUBLIC_KEY:-}" ]; then
  echo "BUSHA_PUBLIC_KEY is not set. Source the repo's .env or pass it explicitly." >&2
  exit 1
fi

read -r -d '' SIM_PICKER <<'PY' || true
import json, os, re, sys

data = json.load(sys.stdin)["devices"]
fallback_name = os.environ["SIM_FALLBACK_NAME"]

# 1) Anything already booted on iOS — reuse it.
for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    for dev in devices:
        if dev.get("state") == "Booted" and dev.get("isAvailable", True):
            print(f"{dev['udid']}\t{dev['name']}")
            sys.exit(0)

# 2) Fallback: find the named sim on the latest iOS runtime.
def parse_version(rt):
    m = re.search(r"iOS-(\d+)(?:-(\d+))?", rt)
    return (int(m.group(1)), int(m.group(2) or 0)) if m else (-1, -1)

candidates = []
for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    for dev in devices:
        if dev.get("name") == fallback_name and dev.get("isAvailable", True):
            candidates.append((parse_version(runtime), dev))

if not candidates:
    sys.exit(0)

candidates.sort(key=lambda x: x[0], reverse=True)
dev = candidates[0][1]
print(f"{dev['udid']}\t{dev['name']}")
PY

# Pick the simulator UDID + name. Prefer any booted iOS sim; fall back to
# SIM_FALLBACK_NAME on the latest iOS runtime. Returns "udid<TAB>name" or
# empty on failure.
SIM_INFO=$(xcrun simctl list devices -j \
  | SIM_FALLBACK_NAME="$SIM_FALLBACK_NAME" python3 -c "$SIM_PICKER")

if [ -z "$SIM_INFO" ]; then
  echo "No booted simulator and no '$SIM_FALLBACK_NAME' available. Open Xcode → Window → Devices and Simulators to install one." >&2
  exit 1
fi

UDID="${SIM_INFO%%	*}"
SIM_NAME="${SIM_INFO#*	}"

echo "→ Building $SCHEME for $SIM_NAME"
xcodebuild \
  -project "$EXAMPLE_DIR/$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  -configuration Debug \
  BUSHA_PUBLIC_KEY="$BUSHA_PUBLIC_KEY" \
  build \
  | xcbeautify 2>/dev/null || cat

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$SCHEME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Built .app not found at $APP_PATH" >&2
  exit 1
fi

STATE=$(xcrun simctl list devices -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; \
print(next(dev['state'] for rt in d for dev in d[rt] if dev['udid']=='$UDID'))")

if [ "$STATE" != "Booted" ]; then
  echo "→ Booting simulator $SIM_NAME ($UDID)"
  xcrun simctl boot "$UDID"
fi

open -a Simulator || true

echo "→ Installing $SCHEME.app"
xcrun simctl install "$UDID" "$APP_PATH"

echo "→ Launching $BUNDLE_ID"
xcrun simctl launch --console-pty "$UDID" "$BUNDLE_ID"
