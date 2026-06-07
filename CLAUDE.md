# Worklog Studio Monorepo Configuration & Guidelines

## 1. Project Architecture & Path Map
This is a Flutter monorepository managed via Melos.
- **Root Directory:** Workspace root containing `melos.yaml`.
- **Main Application:** `apps\worklog_studio\`
  * *Entry Points:* `apps\worklog_studio\lib\main.dart` and `apps\worklog_studio\lib\main_development.dart`.
- **UI Kit & Design System:** `packages\worklog_studio_style_system\`
  * *Entry Point:* `packages\worklog_studio_style_system\lib\worklog_studio_style_system.dart` (barrel export file).

## 2. Environment Constraints (Strictly Windows)
- The development environment is **Windows**. All filesystem paths must use backslashes (`\`).
- Completely ignore and never crawl platform-specific directories for other OS targets (`macos\`, `ios\`, `android\`, `linux\`, `web\`).

## 3. Strict Token Optimization & File Exclusions
To optimize context limits and minimize token waste, your filesystem tools (`read_file`, `search_grep`, `list_directory`) **MUST NEVER** access, search, or index:
- `.fvm\` (Internal SDK cache)
- `.git\` (Version control metadata)
- `.dart_tool\` (Local transient dart files)
- `**\build\` (All build and compilation artifacts)
- `*.freezed.dart` and `*.g.dart` (All auto-generated code-gen files)

## 4. Tooling & Command Cheatsheet
Always use `fvm` as a wrapper for commands. Never run global `flutter` or `dart`.
- **Bootstrap Monorepo:** `fvm exec melos bootstrap` (Run from root)
- **Clean Project:** `fvm exec melos clean`
- **Get Dependencies:** `fvm flutter pub get` (Inside specific package/app directory)
- **Run Code Generation:** `fvm flutter pub run build_runner build --delete-conflicting-outputs` (Inside specific package/app directory)
- **Run Tests:** `fvm flutter test test/core/ test/feature/ --reporter expanded` (From `apps\worklog_studio\`)

## 5. Test-Driven Development (TDD) — Mandatory
All new business logic and bug fixes **must** follow the Red → Green → Refactor cycle.

**Rules:**
- **Write the test first.** Before writing any implementation code for a new feature or fix, write a failing test that defines the expected behaviour. Commit or at minimum present the failing test before touching production code.
- **Minimal implementation.** Write only enough production code to make the failing test pass. Do not add untested logic speculatively.
- **Refactor under green.** Once the test is green, clean up the implementation. The test suite must remain green throughout refactoring.
- **No production code without a test.** Every new public method, service, use-case, or domain rule must have a corresponding unit test in `apps\worklog_studio\test\`. UI-only changes are exempt, but any logic extracted from a widget must be tested.
- **Test location conventions:**
  - Pure domain / service logic → `test\core\`
  - Bloc / state-machine behaviour → `test\feature\`
  - Shared fakes and helpers → `test\helpers\`
- **Test doubles:** Prefer hand-rolled fakes (see `test\helpers\test_fakes.dart`) for stateful collaborators. Use `mocktail` mocks only for pure event-sources or when the collaborator has no meaningful state.
- **Tests must pass before build.** `fvm flutter test test/core/ test/feature/` is executed by `build.sh`, `build.ps1`, and the CI `test` job. A red test blocks the build.

## 6. Active Project Skills Matrix
You have 7 custom Project Skills configured. Analyze the user's prompt and internally align your behavior with the corresponding skill:
1. `codebase-navigator-pro`: Use for code exploration, logic tracing, and onboarding. Enforces "Grep-First" strategy.
2. `codegen-sentinel`: Use when editing models or classes with annotations. Enforces the `.freezed.dart` exclusion and reminds about build_runner.
3. `l10n-asset-stubber`: Use for UI tasks. Enforces an asset freeze (use `Placeholder()`, standard `Icons`) and requires hardcoded strings to have `// TODO: l10n`.
4. `melos-dependency-manager`: Use when modifying `pubspec.yaml` files, syncing versions, or using Melos.
5. `design-system-guard`: Use to protect the separation between app logic and the UI kit. Prevents hardcoded colors/paddings in `apps\`.
6. `surgical-refactor-pro`: Use for deep code reviews, optimizing widget trees, splitting widgets, and cleaning memory leaks (`dispose`).
7. `windows-desktop-expert`: Use for desktop lifecycle, shortcuts, window sizing, and native Windows integration.