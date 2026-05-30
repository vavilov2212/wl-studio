#!/bin/bash

set -e

echo "🚀 Manual GitHub release..."

# -----------------------------
# 1. Get version
# -----------------------------

VERSION_LINE=$(grep '^version:' pubspec.yaml)
CURRENT_VERSION=$(echo $VERSION_LINE | sed 's/version: //')

NAME=$(echo $CURRENT_VERSION | cut -d+ -f1)
TAG="v$NAME"

DMG_PATH="dmg/worklogStudio.dmg"

# -----------------------------
# 2. Check tag exists (early)
# -----------------------------

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "❌ Tag does not exist: $TAG"
  echo "👉 Run publish.sh first"
  exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
  echo "❌ DMG not found: $DMG_PATH"
  exit 1
fi

# -----------------------------
# 3. Detect prerelease
# -----------------------------

if [[ "$TAG" == *"dev"* ]]; then
  PRERELEASE_FLAG="--prerelease"
  echo "⚠️ Creating PRE-release"
else
  PRERELEASE_FLAG=""
  echo "✅ Creating RELEASE"
fi


# -----------------------------
# 4 Generate changelog
# -----------------------------

PREV_TAG=$(git describe --tags --abbrev=0 "$TAG"^ 2>/dev/null || echo "")

if [ -z "$PREV_TAG" ]; then
  echo "ℹ️ No previous tag found"
  CHANGELOG=$(git log --pretty=format:"- %s")
else
  echo "📜 Changelog from $PREV_TAG to $TAG"
  CHANGELOG=$(git log "$PREV_TAG"..HEAD --pretty=format:"- %s")
fi

# write to temp file
CHANGELOG_FILE=$(mktemp)
echo "$CHANGELOG" > $CHANGELOG_FILE

# -----------------------------
# 5. Create GitHub release
# -----------------------------

TITLE="Release $NAME"

gh release create "$TAG" "$DMG_PATH" \
  --title "$TITLE" \
  --notes-file "$CHANGELOG_FILE" \
  $PRERELEASE_FLAG

rm "$CHANGELOG_FILE"

echo "🎉 GitHub release created: $TAG"