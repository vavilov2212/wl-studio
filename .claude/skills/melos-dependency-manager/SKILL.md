---
name: melos-dependency-manager
description: "Activate when adding, removing, or updating pubspec dependencies, resolving package version conflicts, or managing cross-package links in the monorepo."
---

# Capability: Monorepo Dependency Manager

## 1. Structural Awareness
- The workspace is a Melos monorepo with core configuration in `melos.yaml`.
- Main app location: `apps\worklog_studio\`
- UI Kit location: `packages\worklog_studio_style_system\`

## 2. Dependency Synchronization Rules
- When adding or updating a third-party package, check both `pubspec.yaml` files to prevent version mismatch or dependency hell. Shared libraries (like `collection`, `uuid`, etc.) must use identical versions in both the app and the style system package.
- Do not add feature-specific or business-logic packages directly into `packages\worklog_studio_style_system`.

## 3. Tooling Restrictions
- **NEVER** suggest or run bare `flutter pub get` or `dart pub get` commands inside subdirectories.
- To link packages and resolve dependencies, always guide the user to run (or run yourself via tools): `fvm exec melos bootstrap` from the root directory.
