#!/usr/bin/env bash
# Builds a debug simulator app for each store shot, seeds sample data,
# launches it on the booted simulator and saves a RAW screenshot
# (xcrun simctl io screenshot). No cropping, framing or editing.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-$HOME/Downloads/mitsumori-screenshots-raw}"
BUNDLE=jp.mitsumori.app
mkdir -p "$OUT"
xcrun simctl list devices booted | grep -q Booted || { echo "boot a simulator first" >&2; exit 1; }
xcrun simctl status_bar booted override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || true

# Close other apps so the status bar shows no "back to app" breadcrumb.
for app in $(xcrun simctl spawn booted launchctl list | sed -nE 's/.*UIKitApplication:([^[]+)\[.*/\1/p' | grep -v '^com\.apple\.' | sort -u); do
  xcrun simctl terminate booted "$app" 2>/dev/null || true
done

shot() { # name premium tab doc
  local name=$1 premium=$2 tab=$3 doc=${4:-}
  flutter build ios --simulator --debug --dart-define=SCREENSHOT=true \
    --dart-define=SCREENSHOT_PREMIUM=$premium --dart-define=SCREENSHOT_TAB=$tab \
    --dart-define=SCREENSHOT_DOC=$doc >/dev/null
  xcrun simctl terminate booted $BUNDLE 2>/dev/null || true
  xcrun simctl install booted build/ios/iphonesimulator/Runner.app
  local data
  data="$(xcrun simctl get_app_container booted $BUNDLE data)"
  rm -rf "$data/Documents/mitsumori_seikyu"
  python3 tool/seed_demo_data.py "$data/Documents"
  xcrun simctl launch booted $BUNDLE >/dev/null
  sleep 10
  xcrun simctl io booted screenshot "$OUT/$name.png"
  sips -g pixelWidth -g pixelHeight "$OUT/$name.png" | tail -2
}

shot 01-documents true 0
shot 02-estimate-edit true 10 demo-estimate
shot 03-invoice-pdf true 12 demo-invoice
shot 04-paywall false 11
echo "saved to $OUT"
