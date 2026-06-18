#!/bin/bash
# Swap the live macOS app icon (macos/Runner/Assets.xcassets/AppIcon.appiconset)
# between the prod and dev variants. Run this before `flutter run`/`flutter
# build -d macos` — the Xcode project is not flavor-aware, so the icon must
# be swapped on disk ahead of time.
#
# Usage (from apps/worklog_studio/):
#   ./tool/macos/select_app_icon.sh dev
#   ./tool/macos/select_app_icon.sh prod

set -e

FLAVOR="$1"
if [[ "$FLAVOR" != "dev" && "$FLAVOR" != "prod" ]]; then
  echo "Usage: select_app_icon.sh <dev|prod>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$FLAVOR" = "dev" ]; then
  VARIANT_NAME="Dev"
else
  VARIANT_NAME="Prod"
fi

MAC_ICON_DIR="$SCRIPT_DIR/../../macos/Runner/Assets.xcassets/AppIcon.appiconset"
MAC_SOURCE_DIR="$SCRIPT_DIR/../../macos/Runner/Assets.xcassets/AppIcon$VARIANT_NAME.appiconset"

cp "$MAC_SOURCE_DIR"/*.png "$MAC_ICON_DIR"/

echo "macOS app icon switched to '$FLAVOR'."
