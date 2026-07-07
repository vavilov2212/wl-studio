# Worklog Studio Monorepo Configuration & Guidelines

> Output style and tool-priority rules (verbosity, native tools → MCP → LSP → Bash) live in `~/.claude/CLAUDE.md` (global) and apply here too.

## 1. Project Architecture & Path Map
This is a Flutter monorepository managed via Melos.
- **Root Directory:** Workspace root containing `melos.yaml`.
- **Main Application:** `apps\worklog_studio\`
  * *Entry Points:* `apps\worklog_studio\lib\main.dart` and `apps\worklog_studio\lib\main_development.dart`.
- **UI Kit & Design System:** `packages\worklog_studio_style_system\`
  * *Entry Point:* `packages\worklog_studio_style_system\lib\worklog_studio_style_system.dart` (barrel export file).
  * **UI Kit Reference:** `packages\worklog_studio_style_system\UI_KIT.md` - read this first on any UI task. Contains all components, props, tokens, and theme architecture. Do not crawl source files to discover what exists; consult this file instead.

## 2. Environment Constraints (Strictly Windows)
- The development environment is **Windows**. All filesystem paths must use backslashes (`\`).
- Completely ignore and never crawl platform-specific directories for other OS targets (`macos\`, `ios\`, `android\`, `linux\`, `web\`).

## 3. Strict Token Optimization & File Exclusions
To optimize context limits and minimize token waste, your file-reading, search, or listing tools (native `Read`/`Grep`/`Glob`, or the `filesystem` MCP server as fallback) **MUST NEVER** access, search, or index:
- `.fvm\` (Internal SDK cache)
- `.git\` (Version control metadata)
- `.dart_tool\` (Local transient dart files)
- `**\build\` (All build and compilation artifacts)
- `*.freezed.dart` and `*.g.dart` (All auto-generated code-gen files)

## 4. Tooling & Command Cheatsheet
Always use `fvm` as a wrapper for commands. Never run global `flutter` or `dart`.
- **Bootstrap Monorepo:** `fvm exec melos bootstrap` (Run from root)
- **Clean Project:** `fvm exec melos clean`
- **Get/Resolve Dependencies:** `fvm exec melos bootstrap` from root — never run bare `flutter pub get` / `dart pub get` in a subdirectory (see `melos-dependency-manager` skill)
- **Run Code Generation:** `fvm flutter pub run build_runner build --delete-conflicting-outputs` (Inside specific package/app directory)
- **Run Tests:** `fvm flutter test test/core/ test/feature/ --reporter expanded` (From `apps\worklog_studio\`) — see `apps\worklog_studio\CLAUDE.md` for the mandatory TDD workflow.

## 5. Git Commit Conventions
- **Never** add a `Co-Authored-By: Claude` (or any AI-attribution) trailer to commit messages. Commits must list only the human author.

## 6. Active Project Skills Matrix
You have 7 custom Project Skills configured. Analyze the user's prompt and internally align your behavior with the corresponding skill:
1. `codebase-navigator-pro`: Use for code exploration, logic tracing, and onboarding. Enforces "Grep-First" strategy.
2. `codegen-sentinel`: Use when editing models or classes with annotations. Enforces the `.freezed.dart` exclusion and reminds about build_runner.
3. `l10n-asset-stubber`: Use for UI tasks. Enforces an asset freeze (use `Placeholder()`, standard `Icons`) and requires hardcoded strings to have `// TODO: l10n`.
4. `melos-dependency-manager`: Use when modifying `pubspec.yaml` files, syncing versions, or using Melos.
5. `design-system-guard`: Use to protect the separation between app logic and the UI kit. Prevents hardcoded colors/paddings in `apps\`.
6. `surgical-refactor-pro`: Use for deep code reviews, optimizing widget trees, splitting widgets, and cleaning memory leaks (`dispose`).
7. `windows-desktop-expert`: Use for desktop lifecycle, shortcuts, window sizing, and native Windows integration.

---

## 7. Structural Refactoring Log

Plan file: `docs/superpowers/plans/2026-07-07-structural-refactoring.md`

User overrides on the plan:
- Item 2: setState removals - proceed with caution, do not break mini panel functionality
- Item 3: Choose Option A - commit to get_it/injectable for all repos
- Item 4: SKIPPED (l10n infrastructure)
- Item 5: go_router ok, but pages intentionally recreated on tab change (no IndexedStack)
- Item 30: Choose Option B - isolate work_log feature (do not delete)
- Item 32: SKIPPED (hardcoded placeholder stats)
- Item 38: SKIPPED (dependency_overrides uuid)

---

### Refactoring Entry #1 - Item 29

**[Verified Facts]**
- Completed: Item 29 - Delete `in_memory_time_entry_repository.dart`
- File removed: `apps/worklog_studio/lib/data/in_memory_time_entry_repository.dart`
- Method: `git rm` (tracked removal)
- Test result: 209/209 passed

**[What Worked]**
- Grepping for the filename before deletion confirmed zero imports - safe to remove with no cascading changes.
- `git rm` (not OS delete) keeps the removal in the staging area for clean commit.

**[Distilled Rules]**
- Always grep for imports before deleting any Dart file, even an obviously dead one.
- Run tests from `apps/worklog_studio/` directory, not from root.

**[Pitfalls & What to Avoid]**
- None encountered. File was 100% commented out with no consumers.

**[What's Next]**
- Item 37: Remove commented-out `country_flags` dep line from `packages/worklog_studio_style_system/pubspec.yaml`. No prerequisites.

---

### Refactoring Entry #2 - Items 37, 43, 33, 54, 55, 35, 36 (Quick Wins batch)

**[Verified Facts]**
- Item 37: Deleted `# country_flags: ^1.2.1` comment from `packages/worklog_studio_style_system/pubspec.yaml`.
- Item 43: Translated all Russian docstrings in `time_tracker_event.dart` and `time_tracker_state.dart` to English. Removed "what" inline comments on Freezed factory fields (described by name already); kept only "why" doc comments.
- Item 33: Removed commented-out code blocks from `welcome_layout.dart` (commented import, Russian comment, `_menuItem` function, PopoverSurface alt child, task creation block) and `data_layout.dart` (rootBundle line, TODO comment, Spacer line) and `plan_json.dart` (print, JS code block, commented save call). `firebase_options.dart` left untouched - its `///` lines are legitimate generated API docs, not dead code.
- Item 54: `git mv feature/desktop/ipc/ -> feature/desktop/data/`. Updated 4 import paths (3 lib files + 1 test file).
- Item 55: Created `feature/desktop/bloc/` folder. `git mv mini_tracker_cubit.dart` from `presentation/` to `bloc/`. Updated 7 import paths (6 lib files + 1 test file).
- Item 35: `http` kept - used in `data_layout.dart` (work_log prototype, will be resolved by Item 30). `idb_shim` kept - used in web-specific `session_handle_db_web.dart`, legitimate dependency.
- Item 36: `cached_network_image` had zero usages in style system lib - removed from `pubspec.yaml`, ran `fvm exec melos bootstrap`.
- Test result: 209/209 passed after all changes.

**[What Worked]**
- Pattern for folder renames: `git mv` + grep for all consumers + batch-update imports.
- `replace_all` not needed for import updates since each import path is unique per file.
- Running bootstrap after pubspec changes before running tests avoids stale lock file issues.

**[Distilled Rules]**
- After any `git mv` on a Dart file, always grep both `lib/` and `test/` directories for old import paths.
- `firebase_options.dart` has `///` example code - this is not dead code, do not remove.
- `http` dep in `pubspec.yaml` cannot be removed until Item 30 (work_log isolation) is complete.
- When bootstrap is needed, run it from the monorepo root with `fvm exec melos bootstrap`.

**[Pitfalls & What to Avoid]**
- Edit tool will fail with "String not found" if a file was already modified in the session - always re-read the current line range before making further edits to the same file.
- Do not remove `idb_shim` even though the project is Windows-only: the web platform directory exists and the dep is actively imported.

**[What's Next]**
- All Quick Wins are now complete (items 29, 37, 43, 33, 54, 55, 35, 36). Item 32 and 38 were skipped per user.
- Next structural item: **Item 34** - Audit Firebase deps (`firebase_core`, `firebase_ai`). No prerequisites.
- After Item 34: **Item 30** - Isolate `work_log` feature (Option B). No prerequisites beyond Item 34 decision.

---

### Refactoring Entry #3 - Items 39, 58 (Centralize date/duration formatting)

**[Verified Facts]**
- Item 39: Expanded `DateFormatter` in `core/utils/date_formatter.dart` with 6 static methods: `formatDurationHms`, `formatDurationHm`, `formatDateHeader`, `formatTime12h`, `formatTimeHhMm`, `formatTimeRange`.
- Migrated 9 files: `active_timer_text.dart`, `live_duration_text.dart`, `simple_timer_text.dart`, `time_entry_card.dart`, `time_entry_drawer.dart`, `history_page.dart`, `home_page.dart`, `tasks_drawer.dart`, `app_shell.dart`, `mini_panel.dart`.
- Also fixed pre-existing dead-code null checks in `time_entry_drawer.dart` and removed unused `project.dart` import there.
- Item 58: Deleted `feature/common/utils/date_format_utils.dart` after confirming zero consumers.
- Test result: 209/209 passed.

**[What Worked]**
- Grep for all call sites before touching imports - catches hidden usages.
- Delete private methods only after confirming linter marks them unused_element.

**[Distilled Rules]**
- `DateFormatUtils.formatTimeRangeWithDate` is fully replaced by `DateFormatter.formatTimeRange` - identical logic.
- `_formatTime` (12h clock) maps to `DateFormatter.formatTime12h`.
- `_formatDuration` (Xh Ym) maps to `DateFormatter.formatDurationHm`.
- `_formatExactDuration` / `_formatDuration` (HH:mm:ss) map to `DateFormatter.formatDurationHms`.

**[What's Next]**
- Next item: **Item 40** - Replace MiniTrackerCubit raw state with Freezed sealed class.