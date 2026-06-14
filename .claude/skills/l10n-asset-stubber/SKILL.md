---
name: l10n-asset-stubber
description: "Activate when creating or modifying UI layouts that require images, icons, or text strings."
---

# Capability: UI Stubbing & Asset Restrictions

## 1. Asset Freeze Rule
- Do not attempt to add, import, or reference real image files, custom SVGs, or external asset paths in `pubspec.yaml` or Dart code. Asset management is temporarily frozen.
- **Visual Stubs:** When the UI layout requires an image or illustration, always use `Placeholder()` or a styled `Container(color: Colors.grey)` as a temporary visual block.

## 2. Icon Restrictions
- Do not use or install external icon packs (like FontAwesome, RemixIcon, etc.).
- Use **only** standard Material icons via the built-in `Icons.icon_name` class.

## 3. Localization (l10n) Protocol
- There is currently NO localization system configured in the project.
- Write all UI strings as hardcoded text in the language currently used in the layout.
- **CRITICAL:** Every hardcoded string must be immediately appended with a `// TODO: l10n` comment so the user can easily extract it later.
  * *Example:* `text: 'Рабочий лог', // TODO: l10n`
