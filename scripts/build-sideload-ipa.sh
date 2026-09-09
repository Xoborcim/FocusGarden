#!/bin/bash
# Build and export FocusGarden IPA for Sideloadly (free Apple ID).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="FocusGarden-Sideload"
CONFIG="Sideload"
ARCHIVE="$ROOT/build/FocusGarden-Sideload.xcarchive"
EXPORT_DIR="$ROOT/build/sideload-ipa"
EXPORT_OPTIONS="$ROOT/scripts/ExportOptions-Sideload.plist"

cd "$ROOT"
mkdir -p build

echo "→ Archiving ($SCHEME / $CONFIG)…"
xcodebuild \
  -project FocusGarden.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  archive

echo "→ Exporting IPA…"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

IPA=$(find "$EXPORT_DIR" -name "*.ipa" | head -1)
if [[ -n "$IPA" ]]; then
  cp "$IPA" "$ROOT/build/FocusGarden-Sideload.ipa"
  echo ""
  echo "✓ IPA ready: $ROOT/build/FocusGarden-Sideload.ipa"
  echo ""
  echo "Share that file with friends. They install via Sideloadly + their Apple ID."
  echo "Remind them: reinstall every 7 days (free account expiry)."
else
  echo "Export finished but no .ipa found in $EXPORT_DIR"
  exit 1
fi
