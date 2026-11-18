#!/bin/zsh
# Build, install, and launch the Openactive iOS + watchOS apps in the simulator.
# Requires Xcode (simctl + iOS/watchOS SDKs): run once after installing Xcode:
#   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPLE="$REPO_ROOT/apple"
DD="$APPLE/build"
IOS_APP_ID="org.openactive.OpenactiveApp"
WATCH_APP_ID="org.openactive.OpenactiveWatch"

fail() { echo "✗ $*" >&2; exit 1; }

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild not found — install Xcode, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
xcodebuild -version >/dev/null 2>&1 || fail "Xcode is not fully installed yet (App Store download finished?)"

# First booted-by-default devices: newest iPhone and Apple Watch available.
udid_of() {
  xcrun simctl list devices -j | python3 -c "
import json, sys
wanted = sys.argv[1]
devices = json.load(sys.stdin)['devices']
for runtime, entries in devices.items():
    for d in entries:
        if wanted in d['name'] and d['isAvailable']:
            print(d['udid']); sys.exit(0)
sys.exit(1)
" "$1"
}

IPHONE=$(udid_of "iPhone") || fail "No iPhone simulator available (install the iOS runtime in Xcode → Settings → Components)"
WATCH=$(udid_of "Apple Watch") || fail "No Apple Watch simulator available (install the watchOS runtime in Xcode → Settings → Components)"
echo "iPhone simulator : $(xcrun simctl list devices | grep -m1 "$IPHONE" | sed 's/^ *//' || echo "$IPHONE")"
echo "Watch simulator  : $WATCH"

xcrun simctl pair "$WATCH" "$IPHONE" 2>/dev/null && echo "Paired watch ↔ iPhone" || echo "Pairing skipped (already paired ok)"

mkdir -p "$DD"

echo "▸ Building OpenactiveApp (iOS Simulator)…"
(cd "$APPLE" && xcodebuild -scheme OpenactiveApp -destination "platform=iOS Simulator,id=$IPHONE" -derivedDataPath "$DD/ios" build >/dev/null)
IOS_BIN="$DD/ios/Build/Products/Debug-iphonesimulator/OpenactiveApp"
[[ -x "$IOS_BIN" ]] || fail "iOS build product not found at $IOS_BIN"

IOS_APP="$DD/OpenactiveApp.app"
rm -rf "$IOS_APP"; mkdir -p "$IOS_APP"
cp "$IOS_BIN" "$IOS_APP/OpenactiveApp"
cat > "$IOS_APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>OpenactiveApp</string>
  <key>CFBundleIdentifier</key><string>org.openactive.OpenactiveApp</string>
  <key>CFBundleName</key><string>Openactive</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>UILaunchScreen</key><dict/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key><true/>
    <key>NSAllowsArbitraryLoads</key><true/>
  </dict>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Show your position along the downloaded tour track.</string>
</dict>
</plist>
PLIST

WATCH_SCHEME="OpenactiveWatch"
echo "▸ Building OpenactiveWatch (watchOS Simulator)…"
(cd "$APPLE" && xcodebuild -scheme "$WATCH_SCHEME" -destination "platform=watchOS Simulator,id=$WATCH" -derivedDataPath "$DD/watch" build >/dev/null)
WATCH_BIN="$DD/watch/Build/Products/Debug-watchsimulator/OpenactiveWatch"
[[ -x "$WATCH_BIN" ]] || fail "watchOS build product not found at $WATCH_BIN"

WATCH_APP="$DD/OpenactiveWatch.app"
rm -rf "$WATCH_APP"; mkdir -p "$WATCH_APP"
cp "$WATCH_BIN" "$WATCH_APP/OpenactiveWatch"
cat > "$WATCH_APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>OpenactiveWatch</string>
  <key>CFBundleIdentifier</key><string>org.openactive.OpenactiveWatch</string>
  <key>CFBundleName</key><string>Openactive Watch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>WKApplication</key><true/>
  <key>WKCompanionAppBundleIdentifier</key><string>org.openactive.OpenactiveApp</string>
  <key>UILaunchScreen</key><dict/>
</dict>
</plist>
PLIST

xcrun simctl bootstatus "$IPHONE" -b   >/dev/null 2>&1 || xcrun simctl boot "$IPHONE"
xcrun simctl bootstatus "$WATCH" -b    >/dev/null 2>&1 || xcrun simctl boot "$WATCH"
open -a Simulator
xcrun simctl install "$IPHONE" "$IOS_APP"     && echo "✓ iOS app installed"
xcrun simctl install "$WATCH" "$WATCH_APP"    && echo "✓ Watch app installed"
xcrun simctl launch "$IPHONE" "$IOS_APP_ID"   && echo "✓ iOS app launched"
xcrun simctl launch "$WATCH" "$WATCH_APP_ID"  && echo "✓ Watch app launched"

echo ""
echo "Openactive is running in the simulators."
echo "In the iOS app: Settings → server http://192.168.178.32:3456 (home Mac LAN IP), user 'test', password 'testpass'"
echo "The simulator shares the Mac's network, so it reaches the home server directly."
echo "Full offline test: download a trip, then stop the server (npm stop) — map + track still work."
