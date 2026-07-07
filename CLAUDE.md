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
- Next items: **Item 41** (Freezed MiniTrackerState) and **Item 42** (MiniPanelCommandBus) - see Entry #4.

---

### Refactoring Entry #4 - Items 41, 42 (Freezed MiniTrackerState + MiniPanelCommandBus)

**[Verified Facts]**
- Item 41: Converted `MiniTrackerState` to `@freezed abstract class` with private constructor `const MiniTrackerState._()`. Manually wrote `mini_tracker_cubit.freezed.dart` (build_runner blocked by Dart 3.10.4 + `native_toolchain_c` build hooks).
- Item 42: Created `feature/desktop/bloc/mini_panel_command_bus.dart` - standalone `MiniPanelCommandBus` with broadcast `StreamController<MiniPanelCommand>`. Removed `_commandController`, `commands` getter, `emitCommand()`, and `close()` override from `MiniTrackerCubit`. Wrapped `BlocProvider<MiniTrackerCubit>` in `MultiProvider` in `app.dart` to also provide `MiniPanelCommandBus`. Updated `mini_panel.dart` and test to use bus instead of cubit.
- Test result: 209/209 passed.

**[What Worked]**
- Manually writing `.freezed.dart` by copying the Freezed v3 pattern from existing project files (`dashboard_charts_bloc.freezed.dart`, `time_tracker_bloc.freezed.dart`) for list field handling.
- Using `MiniTrackerState(...)` direct constructor in `updateFromSnapshot` instead of `state.copyWith(...)` to avoid nullable `activeEntry` copyWith semantics.

**[Distilled Rules]**
- build_runner is broken with Dart 3.10.4 + `native_toolchain_c 0.19.1`. Always write Freezed files manually. Copy pattern from existing `*.freezed.dart` in the project - list fields need private backing `_field`, `EqualUnmodifiableListView` getter, and `DeepCollectionEquality` in equality/hashCode.
- `MiniPanelCommand` enum lives in `mini_tracker_cubit.dart` (not the bus file) because it is part of the state domain.
- `MiniPanelCommandBus` is registered as a `Provider<MiniPanelCommandBus>` with `dispose: (_, bus) => bus.dispose()` - not a BlocProvider.

**[Pitfalls & What to Avoid]**
- Do not add an explicit `provider` import alongside `flutter_bloc` - `flutter_bloc` already re-exports `provider` and the duplicate causes a conflict lint.
- Stale IDE diagnostics showed errors at pre-edit line numbers. Verify file state via grep, not IDE.

**[What's Next]**
- Item 44: Standardize all relative imports to `package:worklog_studio/` absolute imports. Add `always_use_package_imports: true` lint rule.

---

### Refactoring Entry #5 - Items 44, 45, 47, 48, 50 (Imports + test coverage)

**[Verified Facts]**
- Item 44: Added `always_use_package_imports: true` to `analysis_options.yaml`. Converted 54 relative imports across 29 `lib/` files to `package:worklog_studio/...` URIs. Includes conditional platform stub import in `entity/session/.../input_storage.dart`. Zero remaining relative imports.
- Item 45: `app_drawer_host.dart` is alive and consumed by `app_shell.dart`. It is the widget layer driven by `DrawerHostController` (which is the state). Not redundant - no action taken.
- Item 47: Created `test/feature/project_task_state_test.dart` (15 tests). Added `FakeProjectRepository` and `FakeTaskRepository` to `test_fakes.dart`.
- Item 48: Created `test/feature/entity_resolver_test.dart` (12 tests). Uses real `TimeTrackerBloc` with fake deps - simpler than a fake BLoC.
- Item 50: Created `test/feature/work_log_raw_data_bloc_test.dart` (6 tests). Used plain `flutter_test` stream subscription (no `bloc_test` package - not in pubspec).
- Test count: 209 -> 242 (+33).

**[What Worked]**
- For `EntityResolver` tests: creating a real `TimeTrackerBloc` with `FakeTimeEntryRepository` and dispatching `TimeTrackerLoaded` gives a properly-populated state without needing a fake BLoC.
- `await Future<void>.delayed(Duration.zero)` is sufficient to let async ChangeNotifier `_init()` and BLoC event handlers complete in tests.

**[Distilled Rules]**
- `bloc_test` package is NOT in the project's pubspec. Use `bloc.stream.listen` + `Future.delayed(Duration.zero)` for BLoC state assertions.
- For ChangeNotifier tests: construct, wait one microtask, then assert. No `pumpEventQueue` needed.
- Windows drive-letter case mismatch (d: vs D:) can produce spurious `argument_type_not_assignable` IDE diagnostics. They clear on full analysis and do not affect `flutter test`.

**[Pitfalls & What to Avoid]**
- Do not use `bloc_test` in new test files until it is added to `pubspec.yaml`.

**[What's Next]**
- Item 53: Extract `_BarChart` fl_chart config from `dashboard_charts_section.dart`.
- Item 56: Create `feature/settings/presentation/` subfolders and move screen files.
- Item 57: Assess `_DetailItem` in `tasks_drawer.dart` for reuse.
- Item 59: Audit `app_bar/` six-file split.
- Item 60: Audit `entity/session/` and `entity/user/`.

---

### Refactoring Entry #6 - Items 53, 56, 24, 30, 31 + audits 57/59/60

**[Verified Facts]**
- Item 53: Extracted `_buildBarChartData({required chartMaxY, required interval})` from `_BarChartState.build()`. The method uses `context.theme`/`context.colorsPalette` directly. `build()` is now pure layout + scale computation (~25 lines).
- Item 56: `git mv` both settings screen files to `feature/settings/presentation/`. Updated one import in `app_shell.dart`.
- Item 24: Removed silent `try/catch {}` around `getIt<IdleMonitor>()` in `app.dart`. `PlatformIdleMonitor` is `@LazySingleton` and its constructor is safe.
- Item 30 (Option B): Added `// PROTOTYPE: not active` comment to `raw_txt.dart` (last uncovered file). Other presentation files already had it from prior session.
- Item 31: `feature/home/data/` directory does not exist - `mock_data.dart` was already removed.
- Item 57 (audit): `_DetailItem` is tasks-specific (0 consumers in other drawer files). No extraction needed - YAGNI.
- Item 59 (audit): All 6 `app_bar/` files have distinct roles (`AppBarService` = state, `AppBarProvider` = push config, `AppBarScope` = read + InheritedWidget propagation). Not redundant. No merges.
- Item 60 (audit): `entity/session/` and `entity/user/` are active - consumed by `work_log` feature via injectable. They are cross-cutting auth/session concerns, distinct from feature-vertical code. No migration needed.
- Test count: 242/242 (unchanged).

**[Distilled Rules]**
- `feature/home/data/` no longer exists - no `mock_data.dart` to delete.
- `app_bar/` six-file split is intentional: service (state) + provider (write) + scope (read/inherit) is a well-designed push-pull pattern, not redundancy.
- `entity/` top-level is for cross-cutting auth/session concerns that don't fit the single-feature vertical slice model.

**[What's Next]**
- Item 7: DONE (see Entry #7).
- Item 8: Split `mini_panel.dart` (1051 lines) into 4 files.
- Items 9-11: Smaller page splits.
- Item 12: TrackerPanelCubit (depends on Item 7).

---

### Refactoring Entry #7 - Item 7 (Split app_shell.dart)

**[Verified Facts]**
- Item 7: Split `app_shell.dart` (1005 lines) into 4 files:
  - `feature/app/layout/app_route.dart` - `AppRoute` enum + `isSettingsRoute` helper (avoids circular imports)
  - `feature/time_tracker/presentation/global_time_tracker_panel.dart` - `GlobalTimeTrackerPanel` + `_GlobalTimeTrackerPanelState`
  - `feature/app/layout/app_bar/top_app_bar.dart` - `TopAppBar`
  - `feature/app/layout/sidebar_navigation.dart` - `SidebarNavigation` + `_SidebarNavigationState`
  - `feature/app/layout/app_shell.dart` - now only `AppShell`/`_AppShellState` (~160 lines)
- Fixed pre-existing unused `theme` variable in `_navItem` during extraction.
- Test count: 242/242 (unchanged).

**[What Worked]**
- Placing `AppRoute` in its own `app_route.dart` avoids a circular import (`app_shell.dart` imports `sidebar_navigation.dart` which needs `AppRoute`).
- `TopAppBar` is a thin stateless wrapper - it only needs `worklog_studio_style_system.dart` + the new `GlobalTimeTrackerPanel` import.
- `GlobalTimeTrackerPanel` needs the explicit `colors_palette_entity.dart` import because `ColorsPalette` appears as a named parameter type in `_buildTimerAndAction`.

**[Distilled Rules]**
- When extracting a class that references an enum from the containing file, put the enum in a third shared file rather than importing the old file (circular dep risk).
- `sidebar_navigation.dart` imports `app_route.dart` directly, NOT `app_shell.dart`.
- `_navItem` in `SidebarNavigation` does not use a `theme` local - the linter catches this. Remove it on extraction.

**[What's Next]**
- Item 8: Split `mini_panel.dart` (~1051 lines). Same 4-file pattern.
- Item 12: TrackerPanelCubit (depends on Item 7 - now unblocked).