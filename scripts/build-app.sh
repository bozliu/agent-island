#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/.build/release"
PUBLIC_RESOURCES_DIR="$ROOT_DIR/App/BundleResources"
CONFIG_PLIST="$ROOT_DIR/Config/ServiceConfig.local.plist"
ENTITLEMENTS_PATH="$ROOT_DIR/scripts/entitlements.plist"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

APP_NAME="${AGENT_ISLAND_PRODUCT_NAME:-${VIBE_ISLAND_PRODUCT_NAME:-Agent Island}}"
APP_EXECUTABLE="agent-island"
HELPER_EXECUTABLE="agent-island-bridge"
BUNDLE_ID="${AGENT_ISLAND_BUNDLE_ID:-${VIBE_ISLAND_BUNDLE_ID:-app.agentisland.macos}}"
APP_VERSION="${AGENT_ISLAND_VERSION:-${VIBE_ISLAND_VERSION:-1.0.18}}"
REPOSITORY_URL="${AGENT_ISLAND_REPOSITORY_URL:-${VIBE_ISLAND_WEBSITE_URL:-https://github.com/bozliu/agent-island}}"
DOWNLOAD_URL="${AGENT_ISLAND_DOWNLOAD_URL:-${VIBE_ISLAND_DOWNLOAD_URL:-https://github.com/bozliu/agent-island/releases}}"
REPOSITORY_OWNER="${AGENT_ISLAND_REPOSITORY_OWNER:-${VIBE_ISLAND_REPOSITORY_OWNER:-bozliu}}"
REPOSITORY_NAME="${AGENT_ISLAND_REPOSITORY_NAME:-${VIBE_ISLAND_REPOSITORY_NAME:-agent-island}}"
SU_FEED_URL="${AGENT_ISLAND_SU_FEED_URL:-${VIBE_ISLAND_SU_FEED_URL:-}}"
SU_PUBLIC_ED_KEY="${AGENT_ISLAND_SU_PUBLIC_ED_KEY:-${VIBE_ISLAND_SU_PUBLIC_ED_KEY:-}}"
SU_AUTOMATICALLY_UPDATE="${AGENT_ISLAND_SU_AUTOMATICALLY_UPDATE:-${VIBE_ISLAND_SU_AUTOMATICALLY_UPDATE:-}}"
SU_ENABLE_AUTOMATIC_CHECKS="${AGENT_ISLAND_SU_ENABLE_AUTOMATIC_CHECKS:-${VIBE_ISLAND_SU_ENABLE_AUTOMATIC_CHECKS:-}}"
SU_SCHEDULED_CHECK_INTERVAL="${AGENT_ISLAND_SU_SCHEDULED_CHECK_INTERVAL:-${VIBE_ISLAND_SU_SCHEDULED_CHECK_INTERVAL:-}}"
USAGE_ENABLED="${AGENT_ISLAND_USAGE_ENABLED:-${VIBE_ISLAND_USAGE_ENABLED:-true}}"
SIGN_IDENTITY="${AGENT_ISLAND_SIGN_IDENTITY:-${VIBE_ISLAND_SIGN_IDENTITY:--}}"

APP_DIR="$DIST_DIR/$APP_NAME.app"

read_plist_value() {
  local plist_path="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
}

load_local_configuration() {
  [[ -f "$CONFIG_PLIST" ]] || return 0

  local value
  value="$(read_plist_value "$CONFIG_PLIST" ProductName)"; [[ -n "$value" ]] && APP_NAME="$value"
  value="$(read_plist_value "$CONFIG_PLIST" BundleID)"; [[ -n "$value" ]] && BUNDLE_ID="$value"
  value="$(read_plist_value "$CONFIG_PLIST" Version)"; [[ -n "$value" ]] && APP_VERSION="$value"
  value="$(read_plist_value "$CONFIG_PLIST" RepositoryURL)"; [[ -n "$value" ]] && REPOSITORY_URL="$value"
  value="$(read_plist_value "$CONFIG_PLIST" DownloadURL)"; [[ -n "$value" ]] && DOWNLOAD_URL="$value"
  value="$(read_plist_value "$CONFIG_PLIST" RepositoryOwner)"; [[ -n "$value" ]] && REPOSITORY_OWNER="$value"
  value="$(read_plist_value "$CONFIG_PLIST" RepositoryName)"; [[ -n "$value" ]] && REPOSITORY_NAME="$value"
  value="$(read_plist_value "$CONFIG_PLIST" SUFeedURL)"; [[ -n "$value" ]] && SU_FEED_URL="$value"
  value="$(read_plist_value "$CONFIG_PLIST" SUPublicEDKey)"; [[ -n "$value" ]] && SU_PUBLIC_ED_KEY="$value"
  value="$(read_plist_value "$CONFIG_PLIST" SUAutomaticallyUpdate)"; [[ -n "$value" ]] && SU_AUTOMATICALLY_UPDATE="$value"
  value="$(read_plist_value "$CONFIG_PLIST" SUEnableAutomaticChecks)"; [[ -n "$value" ]] && SU_ENABLE_AUTOMATIC_CHECKS="$value"
  value="$(read_plist_value "$CONFIG_PLIST" SUScheduledCheckInterval)"; [[ -n "$value" ]] && SU_SCHEDULED_CHECK_INTERVAL="$value"
  value="$(read_plist_value "$CONFIG_PLIST" UsageEnabled)"; [[ -n "$value" ]] && USAGE_ENABLED="$value"
}

write_info_plist() {
  cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>ATSApplicationFontsPath</key>
  <string>Fonts</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_EXECUTABLE</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Agent Island uses Apple Events to jump you back to the terminal session that needs attention.</string>
  <key>NSQuitAlwaysKeepsWindows</key>
  <false/>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>AgentIslandDownloadURL</key>
  <string>$DOWNLOAD_URL</string>
  <key>AgentIslandUsageEnabled</key>
  <$USAGE_ENABLED/>
  <key>AgentIslandRepositoryURL</key>
  <string>$REPOSITORY_URL</string>
</dict>
</plist>
PLIST

  local plist="$APP_DIR/Contents/Info.plist"

  if [[ -n "$REPOSITORY_OWNER" ]]; then
    /usr/libexec/PlistBuddy -c "Add :AgentIslandRepositoryOwner string $REPOSITORY_OWNER" "$plist"
  fi
  if [[ -n "$REPOSITORY_NAME" ]]; then
    /usr/libexec/PlistBuddy -c "Add :AgentIslandRepositoryName string $REPOSITORY_NAME" "$plist"
  fi
  if [[ -n "$SU_FEED_URL" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $SU_FEED_URL" "$plist"
  fi
  if [[ -n "$SU_PUBLIC_ED_KEY" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SU_PUBLIC_ED_KEY" "$plist"
  fi
  if [[ -n "$SU_AUTOMATICALLY_UPDATE" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUAutomaticallyUpdate bool $SU_AUTOMATICALLY_UPDATE" "$plist"
  fi
  if [[ -n "$SU_ENABLE_AUTOMATIC_CHECKS" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool $SU_ENABLE_AUTOMATIC_CHECKS" "$plist"
  fi
  if [[ -n "$SU_SCHEDULED_CHECK_INTERVAL" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUScheduledCheckInterval integer $SU_SCHEDULED_CHECK_INTERVAL" "$plist"
  fi
}

mkdir -p "$DIST_DIR"
load_local_configuration

APP_DIR="$DIST_DIR/$APP_NAME.app"
rm -rf "$APP_DIR"

swift "$ROOT_DIR/scripts/generate_app_icon.swift" "$PUBLIC_RESOURCES_DIR"
swift "$ROOT_DIR/scripts/generate_default_sounds.swift" "$PUBLIC_RESOURCES_DIR"

swift build -c release --product AgentIslandApp
swift build -c release --product agent-island-bridge

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Helpers" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/AgentIslandApp" "$APP_DIR/Contents/MacOS/$APP_EXECUTABLE"
cp "$BUILD_DIR/agent-island-bridge" "$APP_DIR/Contents/Helpers/$HELPER_EXECUTABLE"
chmod +x "$APP_DIR/Contents/MacOS/$APP_EXECUTABLE" "$APP_DIR/Contents/Helpers/$HELPER_EXECUTABLE"

if [[ -d "$PUBLIC_RESOURCES_DIR" ]]; then
  ditto "$PUBLIC_RESOURCES_DIR" "$APP_DIR/Contents/Resources"
fi

write_info_plist

cat > "$ENTITLEMENTS_PATH" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.automation.apple-events</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -d "$APP_DIR/Contents/Frameworks" ]]; then
  find "$APP_DIR/Contents/Frameworks" -maxdepth 1 -mindepth 1 | while read -r framework_path; do
    codesign --force --deep --sign "$SIGN_IDENTITY" "$framework_path"
  done
fi

codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR/Contents/Helpers/$HELPER_EXECUTABLE"
codesign --force --deep --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" "$APP_DIR"

echo "Built app bundle at: $APP_DIR"
