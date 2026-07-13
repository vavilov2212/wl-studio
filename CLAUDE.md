👉 IMPORTANT: Before writing any new code, adding features, or refactoring, you MUST first read POST_MORTEM.md and strictly follow the architectural rules and Production Guardrails recorded there.

# Worklog Studio

Flutter desktop time-tracking application (Windows/macOS), organized as a Melos-managed
monorepo: the main app lives in `apps\worklog_studio\`, with a shared UI kit / design
system in `packages\worklog_studio_style_system\`.

## Basic Commands
Always use `fvm` as a wrapper for commands. Never run global `flutter` or `dart`.
- **Bootstrap monorepo:** `fvm exec melos bootstrap` (run from root)
- **Clean project:** `fvm exec melos clean`
- **Run code generation:** `fvm flutter pub run build_runner build --delete-conflicting-outputs` (inside specific package/app directory)
- **Run tests:** `fvm flutter test test/core/ test/feature/ --reporter expanded` (from `apps\worklog_studio\`)
