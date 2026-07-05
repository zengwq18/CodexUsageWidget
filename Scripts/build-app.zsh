#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${ROOT_DIR}/dist/CodexUsageWidget.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICON_FILE="${ROOT_DIR}/Resources/AppIcon.icns"
APP_VERSION="0.3.1"
APP_BUILD="7"

cd "${ROOT_DIR}"
mkdir -p ".build/module-cache"
export CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.build/module-cache"
swift build --disable-sandbox -c release

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp ".build/release/CodexUsageWidget" "${MACOS_DIR}/CodexUsageWidget"

if [[ ! -f "${ICON_FILE}" ]]; then
  echo "Missing ${ICON_FILE}. Run: swift Scripts/generate-icon.swift" >&2
  exit 1
fi

cp "${ICON_FILE}" "${RESOURCES_DIR}/AppIcon.icns"

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>CodexUsageWidget</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex-usage-widget</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>CodexUsageWidget</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built ${APP_DIR}"
