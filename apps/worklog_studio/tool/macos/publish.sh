#!/bin/bash

set -e

echo "🚀 Publishing (atomic)..."

VERSION_LINE=$(grep '^version:' pubspec.yaml)
CURRENT_VERSION=$(echo $VERSION_LINE | sed 's/version: //')

NAME=$(echo $CURRENT_VERSION | cut -d+ -f1)
TAG="v$NAME"

BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "🏷 Tag: $TAG"
echo "🌿 Branch: $BRANCH"

# # ensure we are on main branch
# if [ "$BRANCH" != "main" ]; then
#   echo "❌ You must publish from 'main' branch (current: $BRANCH)"
#   exit 1
# fi

# check if there are changes to commit
if git diff --quiet && git diff --cached --quiet; then
  echo "❌ No changes to release"
  exit 1
fi

# check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "❌ Tag already exists: $TAG"
  exit 1
fi

# commit version
git add pubspec.yaml release/appcast.xml
git commit -m "release $TAG" || echo "no changes"

# create tag
git tag $TAG

# atomic push
git push --atomic origin $BRANCH $TAG

echo "✅ Tag pushed (CI should handle release)"