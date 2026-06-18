# Release Guide (macOS + Sparkle)

## 📌 Requirements
- Flutter installed
- Sparkle configured
- Sandbox disabled (entitlements)

---

## 📚 Table of Contents

- [Workflow](#-workflow)
- [Versioning](#-versioning)
- [Version flow](#-version-flow)
- [build.sh](#-buildsh)
- [publish.sh](#-publishsh)
- [release.sh](#-releasesh-manual-github-release)
- [Paths](#-paths)
- [Local testing](#-local-testing)
- [First release (manual, no CI)](#-first-release-manual-no-ci)
- [Important](#important)

---

## 🚀 Workflow

```bash
cd apps/worklog_studio
```

### Development build (pre-release)

```bash
./tool/build.sh dev
./tool/publish.sh
```

### Release build

```bash
./tool/build.sh release
./tool/publish.sh
```

### Manual GitHub release (optional)

```bash
./tool/release.sh
```

---

## 🧠 Versioning

Format:

```
MAJOR.MINOR.PATCH[-dev.N]+BUILD
```

Examples:

```
1.0.1
1.0.2-dev.1
1.0.2-dev.5
1.0.2
```

---

## 🔄 Version flow

```
1.0.1
↓
1.0.2-dev.1
1.0.2-dev.2
...
1.0.2-dev.N
↓
1.0.2
↓
1.0.3-dev.1
```

---

## 🏠 build.sh

```bash
./tool/build.sh dev        # next dev version
./tool/build.sh release    # finalize version
./tool/build.sh 2.0.0      # manual version
```

Behavior:

- `dev`:
  - `1.0.1 → 1.0.2-dev.1`
  - `1.0.2-dev.3 → 1.0.2-dev.4`

- `release`:
  - `1.0.2-dev.5 → 1.0.2`

- always increments `BUILD`

---

## 🚀 publish.sh

```bash
./tool/publish.sh
```

Does:
- commit `pubspec.yaml`
- create tag (`v1.0.2-dev.3` or `v1.0.2`)
- atomic push (commit + tag)

CI should handle build & GitHub release.

---

## 📤 release.sh (manual GitHub release)

```bash
./tool/release.sh
```

Does:
- creates GitHub release for current tag
- uploads `dmg/worklogStudio.dmg`
- marks prerelease automatically if version contains `dev`

Use when:
- CI is not configured
- or you need to publish release manually

---

## 📦 Paths

```
build/macos/Build/Products/Release/worklog_studio.app
```

```
dmg/worklogStudio.dmg
```

```
release/appcast.xml
```

---

## 🌐 Local testing

```bash
npx serve .
```

```
http://localhost:3000/release/appcast.xml
```

---

## ⚠️ Notes

- ❌ do not use `file://`
- ❗ run app from `/Applications`
- ❗ BUILD must always increase

---

## 🧪 Update check

```dart
SparkleBridge.checkForUpdates();
```

---

## ✅ Checklist

- [ ] Run `build.sh` (dev or release)
- [ ] Run `publish.sh` (triggers CI)
- [ ] (optional) Run `release.sh` if publishing manually
- [ ] Start server
- [ ] Install app to `/Applications`
- [ ] Verify update

---

## 🚀 First release (manual, no CI)

Step-by-step:

```bash
cd apps/worklog_studio
```

### 1. Build release

```bash
./tool/build.sh release
```

This will:
- bump version
- build macOS app
- create `dmg/worklogStudio.dmg`
- generate `release/appcast.xml`

### 2. Publish tag

```bash
./tool/publish.sh
```

This will:
- commit version
- create tag (e.g. `v1.0.1`)
- push to GitHub

### 3. Create GitHub release

```bash
./tool/release.sh
```

This will:
- create release on GitHub
- upload `.dmg`
- attach changelog

### 4. Verify URLs

Make sure:
- DMG is available at:
  ```
  https://github.com/<user>/<repo>/releases/download/vX.X.X/worklogStudio.dmg
  ```
- appcast points to this URL

---

## Important
- appcast must use **HTTPS** (no localhost in production)
- `sparkle:version` must increase every release
- `sparkle:shortVersionString` must match app version
- release notes link should point to GitHub release