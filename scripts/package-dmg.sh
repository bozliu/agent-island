#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
CONFIG_PLIST="$ROOT_DIR/Config/ServiceConfig.local.plist"

APP_NAME="${AGENT_ISLAND_PRODUCT_NAME:-${VIBE_ISLAND_PRODUCT_NAME:-Agent Island}}"
APP_DIR="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_NAME="${AGENT_ISLAND_DMG_NAME:-${VIBE_ISLAND_DMG_NAME:-AgentIsland.dmg}}"
DMG_PATH="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="${AGENT_ISLAND_VOLUME_NAME:-${VIBE_ISLAND_VOLUME_NAME:-Agent Island}}"
BACKGROUND_DIR="$STAGING_DIR/.background"
BACKGROUND_PATH="$BACKGROUND_DIR/dmg-background.tiff"

read_plist_value() {
  local plist_path="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
}

load_local_configuration() {
  [[ -f "$CONFIG_PLIST" ]] || return 0

  local value
  value="$(read_plist_value "$CONFIG_PLIST" ProductName)"; [[ -n "$value" ]] && APP_NAME="$value"
  value="$(read_plist_value "$CONFIG_PLIST" DMGName)"; [[ -n "$value" ]] && DMG_NAME="$value"
  value="$(read_plist_value "$CONFIG_PLIST" VolumeName)"; [[ -n "$value" ]] && VOLUME_NAME="$value"
}

generate_fallback_background() {
  swift -e '
import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let title = CommandLine.arguments[2]
let size = NSSize(width: 960, height: 600)
let image = NSImage(size: size)
image.lockFocus()
let colors = [
    NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.52, alpha: 1),
    NSColor(calibratedRed: 0.35, green: 0.47, blue: 0.86, alpha: 1),
    NSColor(calibratedRed: 0.93, green: 0.74, blue: 0.52, alpha: 1)
]
let gradient = NSGradient(colors: colors)!
gradient.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: size)), angle: 35)
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 48, weight: .black),
    .foregroundColor: NSColor.white.withAlphaComponent(0.88)
]
NSString(string: title).draw(at: NSPoint(x: 44, y: 44), withAttributes: attrs)
image.unlockFocus()
try image.tiffRepresentation!.write(to: destination)
' "$BACKGROUND_PATH" "$VOLUME_NAME"
}

load_local_configuration
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$DMG_NAME"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found at $APP_DIR. Run scripts/build-app.sh first." >&2
  exit 1
fi

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR" "$BACKGROUND_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

generate_fallback_background

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -layout GPTSPUD \
  -fs HFS+ \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "Created dmg at: $DMG_PATH"
