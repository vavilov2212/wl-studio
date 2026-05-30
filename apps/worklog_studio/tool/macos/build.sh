#!/bin/bash

set -e

PROJECT_DIR="$(pwd)"
APP_NAME="worklog_studio"
DMG_NAME="dmg/worklogStudio.dmg"
APPCAST_PATH="release/appcast.xml"

echo "🚀 Starting release..."

# -----------------------------
# CLI info
# -----------------------------

echo "📥 Command: ./build.sh $@"
echo ""
echo "Available commands:"
echo "  dev      → next dev version"
echo "  release  → finalize dev version"
echo "  patch    → bump patch (1.0.1 → 1.0.2)"
echo "  minor    → bump minor (1.0.1 → 1.1.0)"
echo "  major    → bump major (1.0.1 → 2.0.0)"
echo "  X.Y.Z    → set exact version"
echo ""

# -----------------------------
# 1. Versioning (dev / release / semver)
# -----------------------------

VERSION_LINE=$(grep '^version:' pubspec.yaml)
CURRENT_VERSION=$(echo $VERSION_LINE | sed 's/version: //')

NAME=$(echo $CURRENT_VERSION | cut -d+ -f1)
BUILD=$(echo $CURRENT_VERSION | cut -d+ -f2)

TYPE=$1

# Detect dev version
if [[ "$NAME" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)-dev\.([0-9]+)$ ]]; then
  BASE_MAJOR=${BASH_REMATCH[1]}
  BASE_MINOR=${BASH_REMATCH[2]}
  BASE_PATCH=${BASH_REMATCH[3]}
  DEV_NUM=${BASH_REMATCH[4]}
  IS_DEV=true
elif [[ "$NAME" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  BASE_MAJOR=${BASH_REMATCH[1]}
  BASE_MINOR=${BASH_REMATCH[2]}
  BASE_PATCH=${BASH_REMATCH[3]}
  IS_DEV=false
else
  echo "❌ Unsupported version format: $NAME"
  exit 1
fi

if [ "$TYPE" = "dev" ]; then
  if [ "$IS_DEV" = true ]; then
    DEV_NUM=$((DEV_NUM + 1))
    NEW_NAME="$BASE_MAJOR.$BASE_MINOR.$BASE_PATCH-dev.$DEV_NUM"
  else
    BASE_PATCH=$((BASE_PATCH + 1))
    NEW_NAME="$BASE_MAJOR.$BASE_MINOR.$BASE_PATCH-dev.1"
  fi

elif [ "$TYPE" = "release" ]; then
  NEW_NAME="$BASE_MAJOR.$BASE_MINOR.$BASE_PATCH"

elif [ "$TYPE" = "patch" ]; then
  BASE_PATCH=$((BASE_PATCH + 1))
  NEW_NAME="$BASE_MAJOR.$BASE_MINOR.$BASE_PATCH"

elif [ "$TYPE" = "minor" ]; then
  BASE_MINOR=$((BASE_MINOR + 1))
  BASE_PATCH=0
  NEW_NAME="$BASE_MAJOR.$BASE_MINOR.$BASE_PATCH"

elif [ "$TYPE" = "major" ]; then
  BASE_MAJOR=$((BASE_MAJOR + 1))
  BASE_MINOR=0
  BASE_PATCH=0
  NEW_NAME="$BASE_MAJOR.$BASE_MINOR.$BASE_PATCH"

elif [[ "$TYPE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  NEW_NAME="$TYPE"

else
  echo "❌ Unknown command: $TYPE"
  exit 1
fi

NEW_BUILD=$((BUILD + 1))
NEW_VERSION="$NEW_NAME+$NEW_BUILD"

echo "----------------------------------------"
echo "📦 Version change"
echo "  from: $CURRENT_VERSION"
echo "  to:   $NEW_VERSION"
echo "----------------------------------------"

sed -i '' "s/version: .*/version: $NEW_VERSION/" pubspec.yaml

# -----------------------------
# 2. Build
# -----------------------------

flutter build macos

# -----------------------------
# 3. Prepare dmg folder
# -----------------------------

rm -rf dmg
mkdir dmg
mkdir dmg/tmp

cp -R build/macos/Build/Products/Release/$APP_NAME.app dmg/tmp/
ln -s /Applications dmg/tmp/Applications

# -----------------------------
# 4. Create dmg
# -----------------------------

hdiutil create -volname "Worklog Studio" \
  -srcfolder dmg/tmp \
  -ov -format UDZO $DMG_NAME

rm -rf dmg/tmp

# -----------------------------
# 5. Sign dmg
# -----------------------------

SIGN_TOOL=$(find ~/Library/Developer/Xcode/DerivedData -name sign_update | head -n 1)

if [ -z "$SIGN_TOOL" ]; then
  echo "❌ sign_update not found"
  exit 1
fi

SIGN_OUTPUT=$($SIGN_TOOL $DMG_NAME)

# Extract only the edSignature value (avoid picking up file size or other numbers)
SIGNATURE=$(echo "$SIGN_OUTPUT" | grep "sparkle:edSignature" | awk -F '"' '{print $2}')

echo "🔐 Signature: $SIGNATURE"

# -----------------------------
# 6. File size
# -----------------------------

FILE_SIZE=$(stat -f%z $DMG_NAME)

echo "📏 Size: $FILE_SIZE"

# -----------------------------
# 7. Update appcast
# -----------------------------

SHORT_VERSION=$(echo $NEW_NAME)
BUILD_VERSION=$NEW_BUILD

# get repo url
REPO_URL=$(git config --get remote.origin.url)
REPO_URL=${REPO_URL%.git}
REPO_URL=${REPO_URL/git@github.com:/https://github.com/}

DOWNLOAD_URL="$REPO_URL/releases/download/v$SHORT_VERSION/worklogStudio.dmg"
RELEASE_NOTES_URL="$REPO_URL/releases/tag/v$SHORT_VERSION"

cat > $APPCAST_PATH <<EOL
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
    xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel>
  <title>Worklog Studio Updates</title>
  <link>$REPO_URL</link>
  <description>Latest updates for Worklog Studio</description>
  <language>en</language>

  <item>
    <title>Version $SHORT_VERSION</title>
    <sparkle:releaseNotesLink>$RELEASE_NOTES_URL</sparkle:releaseNotesLink>
    <pubDate>$(date -R)</pubDate>

    <enclosure
      url="$DOWNLOAD_URL"
      sparkle:version="$BUILD_VERSION"
      sparkle:shortVersionString="$SHORT_VERSION"
      sparkle:edSignature="$SIGNATURE"
      length="$FILE_SIZE"
      type="application/octet-stream"/>
  </item>

</channel>
</rss>
EOL

echo "✅ appcast updated"

echo "🎉 Release ready!"