# POST MORTEM: Structural Refactoring (2026-07)

> **Status: authoritative.** This document is the distilled outcome of the full structural
> refactoring cycle (plan: `docs/superpowers/plans/2026-07-07-structural-refactoring.md`,
> ~55 items executed across Tiers 1-10). It supersedes the per-session refactoring log that
> previously lived in `CLAUDE.md`. Every rule below was paid for with a real bug, a failed
> test run, or a dead end - treat them as laws of this codebase, not suggestions.
>
> Final state at time of writing: **279/279 tests green**, `dart analyze` clean on all
> touched files, all work committed to `dev` in per-item commits.

---

## 1. FINAL ARCHITECTURE

### 1.1 Vertical-slice feature layout

Every feature under `apps\worklog_studio\lib\feature\<name>\` follows one canonical scaffold.
Folders that would be empty are omitted - never create placeholder directories.

```
feature/<name>/
  bloc/               BLoC or Cubit + events + states
  data/               feature-specific data sources / usecases (if any)
  presentation/
    <name>_page.dart  entry-point screen widget (thin coordinator)
    components/       sub-widgets used only by this feature
```

Cross-cutting layers outside `feature/`:

| Location | Responsibility |
|---|---|
| `lib\domain\` | Domain entities + **repository interfaces** (`Project`/`ProjectRepository` in `project.dart`, etc.) |
| `lib\data\` | Concrete repository implementations (`sqlite\`), `SystemClock`, `SettingsRepository` interface |
| `lib\state\` | Shared app state consumed by multiple features (`ProjectTaskState`, `EntityResolver`, `DrawerHostController`) |
| `lib\entity\` | Cross-cutting auth/session concerns (session, user) that do not fit a single feature slice |
| `lib\core\` | Services (`TimeTrackerService`, desktop platform services, idle monitor, DI), utils (`DateFormatter`) |
| `lib\feature\common\` | Widgets and cubits shared across features (`DrawerFormCubit`, `DeleteConfirmationRow`, `ProjectSelector`, `TaskSelector`, `InlineField`, drawer scaffolding) |

**Page split pattern** (applied to history, tasks, projects): the page file is a thin
coordinator; `components/<entity>_list.dart` holds the `XxxViewMode` enum + the card/table
switcher widget; `components/<entity>_table.dart` holds a top-level
`getXxxTableColumns(AppThemeExtension theme)` function. The ViewMode enum lives in the
*list component* file (putting it in the page file creates a circular import) and is
re-exported from the page file via `export ... show XxxViewMode` for backward compatibility.

**Extraction rule for enums:** when extracting a class that references an enum from its
containing file, move the enum to a third shared file (e.g. `app_route.dart`) instead of
importing the old file - otherwise you build a circular dependency.

### 1.2 Dependency Injection - final decision

**Option A was chosen: get_it + injectable everywhere.** There is exactly one way to obtain
a repository or service:

- Interfaces live in `lib\domain\` (or `lib\data\settings_repository.dart` for settings).
- Implementations are annotated `@LazySingleton(as: <Interface>)`
  (`SqliteTimeEntryRepository`, `SqliteProjectRepository`, `SqliteTaskRepository`,
  `SqliteSettingsRepository`, `PlatformIdleMonitor`).
- Everything is resolved via `getIt<Interface>()` from
  `core\services\service_locator\service_locator.dart`.
- `app.dart` builds `TimeTrackerService`/`ProjectTaskState` from `getIt`-resolved repos.
  **Never instantiate a `Sqlite*Repository` directly in widget/provider code.**
- `IdleMonitor` is registered conditionally in `runner.dart`
  (`PlatformIdleMonitor` on macOS channel platforms, `NoOpIdleMonitor` otherwise) and
  retrieved WITHOUT try/catch - a missing registration must fail fast, not silently
  disable idle detection.
- `WindowsDesktopService` additionally uses `GetIt.I.registerSingleton` /
  `unregister` for `HotkeyService`/`ReminderService` re-registration on re-init; both the
  raw `get_it` import and the `service_locator.dart` import are needed there.

**Codegen caveat:** `service_locator.config.dart` is nominally generated, but build_runner
is broken in this repo (see 3.1), so registrations are **edited manually**, preserving the
generated file's `_iNNN` import-prefix style.

### 1.3 State-management layering

| Layer | Used for | Examples |
|---|---|---|
| BLoC | Async, event-driven domain flows | `TimeTrackerBloc` (single source of truth for entries), `HistoryBloc`, `TasksBloc`, `ProjectsBloc`, `WorkLogRawDataBloc` |
| Cubit | Focused, imperative state containers | `TrackerPanelCubit` (comment draft + delegation to TimeTrackerBloc), `DrawerFormCubit<T>` (generic drawer draft + confirmingDelete), `MiniTrackerCubit` |
| ChangeNotifier / Provider | Shared caches and app-shell state | `ProjectTaskState` (project/task cache + CRUD + timer draft selection), `EntityResolver`, `DrawerHostController`, `AppNavigationController`, `AppBarService` |
| Plain object + Provider | Side-channel command streams | `MiniPanelCommandBus` (broadcast `StreamController<MiniPanelCommand>`; a Cubit is a state container, NOT a command bus - keep them separate) |

Key structural decisions:

- **Feature BLoCs are provided at `MainApp` level, not screen level.** Pages are
  intentionally recreated on tab change (no IndexedStack - explicit product decision).
  A screen-level BlocProvider would lose filter/sort/view-mode state on every tab switch.
- **`DrawerFormCubit<T>`** replaced per-drawer `setState` for `_draft` and
  `_isConfirmingDelete` in all three drawers. Contract:
  - `updateDraft(newDraft)` preserves `confirmingDelete`;
  - `reset(newDraft)` replaces the whole state (used in `didUpdateWidget` when widget
    identity changes - clears confirmingDelete AND swaps the draft atomically);
  - `cancelDelete()` only dismisses the confirmation (used when the drawer closes:
    `!widget.isOpen && oldWidget.isOpen`).
- **`TrackerPanelCubit`** owns only `draftComment`; the draft project/task stays in
  `ProjectTaskState` because many other widgets consume it. Do not duplicate it.
- **Flutter framework objects stay in widgets.** `TextEditingController`,
  `InlineFieldController`, `FocusNode` cannot live in a Cubit - they are widget-tree
  integrated. Pass them into extracted stateless children as constructor parameters;
  side effects in `build` (e.g. `commentController.text = persisted`) are safe when the
  child receives the same controller instance.
- **`MiniPanelCommand` enum** lives in `mini_tracker_cubit.dart` (it is part of the state
  domain); `MiniPanelCommandBus` is registered as a plain `Provider` with
  `dispose: (_, bus) => bus.dispose()`.
- **`app_bar/` six-file split is intentional**: `AppBarService` (state) +
  `AppBarProvider` (push/write) + `AppBarScope` (read/InheritedWidget propagation) is a
  deliberate push-pull pattern - do not "simplify" it into one file.

### 1.4 Design system boundary

- All visual tokens live in `packages\worklog_studio_style_system\`. The app consumes them
  via `context.theme` (`AppThemeExtension`) - `theme.colorsPalette`, `theme.spacings`,
  `theme.radiuses`, `theme.shadows`, `theme.commonTextStyles`.
- `ColorsPalette` groups: `base`, `background`, `border`, `text`, `accent`, and
  `sidebar` (`SidebarColors` - 8 white-alpha overlay tokens added during refactor; both
  light and dark palettes hold identical values because the sidebar background is always
  the dark `accent.nav`).
- The badge tint palette is `kBadgePalette` in
  `theme\colors_palette\badge_palette.dart`, exported from the package barrel.
  `BadgeUtils` (app side) keeps only the initials + hash lookup logic.
- **UI discovery goes through `packages\worklog_studio_style_system\UI_KIT.md`** - never
  crawl the package source to find out what components/props exist.
- Established token mappings from the refactor (use these instead of resurrecting hex):
  `0xFFeaeffd` / `0xFFebf0fd` -> `accent.primaryMuted`; `0xFFf8fafc` ->
  `background.canvas`; header white -> `background.surface`.

### 1.5 Shared UI components created during the refactor

| Component | Location | Contract |
|---|---|---|
| `DeleteConfirmationRow` | `feature/common/presentation/components/` | `isShowing`, `entityLabel`, `onConfirm`, `onCancel`; wraps the AnimatedSwitcher + danger InfoBar two-step delete. Call sites wrap it in `if (!_isNew)`. |
| `ProjectSelector` | same | `selectedProjectId`, `fieldController`, `onProjectSelected(String?)`, optional `fallbackLeading`/`trailing`. Handles Select + inline create + `handleEditorCommit/Close` internally. |
| `TaskSelector` | same | Same shape + `projectId` filter; inline task creation no-ops when `projectId == null`. |
| `DateFormatter` | `core/utils/date_formatter.dart` | The ONLY place for date/duration formatting: `formatDurationHms` (HH:mm:ss), `formatDurationHm` (Xh Ym), `formatDateHeader`, `formatTime12h`, `formatTimeHhMm`, `formatTimeRange`. Never write a private `_formatDuration` again. |

Deliberate non-migration: `GlobalTimeTrackerPanel`'s project/task selectors were NOT moved
to the shared `ProjectSelector`/`TaskSelector` - they delegate to `TrackerPanelCubit` with
`isRunning` semantics and `exitEditMode` behavior that differ from the drawer draft flow.

---

## 2. PRODUCTION GUARDRAILS

Each rule has its reason recorded - if the reason ever stops being true, revisit the rule.

### 2.1 Imports

- **Absolute `package:worklog_studio/...` imports only.** Enforced by
  `always_use_package_imports: true` in `analysis_options.yaml`.
  *Why:* relative imports break silently on file moves; the refactor migrated 54 relative
  imports across 29 files to make `git mv` safe.
- **Never import `package:provider/provider.dart` alongside `flutter_bloc` for
  `context.read/watch/select`** - flutter_bloc re-exports provider and the duplicate
  triggers a conflict lint. **Exception:** the `Consumer<T>` widget specifically fails to
  resolve through the transitive export in some files - when you use `Consumer`, add the
  explicit provider import.
- After any `git mv` of a Dart file, grep BOTH `lib/` and `test/` for the old import path.

### 2.2 State management

- **`setState` is allowed only for purely cosmetic local state**: hover, focus, animation
  toggles, visibility flips. *Why:* anything that crosses a widget boundary or feeds
  business logic (drafts, search queries, filters) belongs in a Bloc/Cubit where it is
  testable; the drawers and panels were rebuilt around this rule.
- Do not call `setState`/`addPostFrameCallback` to defer draft mutations. The old
  `addPostFrameCallback((_) => setState(...))` pattern in drawers existed only to dodge
  "setState during build" from `Select.onChanged`; with `DrawerFormCubit` the cubit
  `emit()` is safe to call directly from user-action callbacks.
- New feature screens with filter/sort/view-mode state get their own BLoC provided at
  `MainApp` level (see 1.3 - pages are recreated on tab change).
- The `_sentinel = Object()` copyWith pattern is the house style for state classes that
  need "explicitly set this nullable field to null" semantics
  (e.g. `filterExpandedOverride: null`).

### 2.3 Code generation (Freezed / injectable)

- **build_runner is broken** in this repo (Dart 3.10.4 + `native_toolchain_c 0.19.1`
  build-hook incompatibility). Consequences:
  - Write `.freezed.dart` files **by hand**, copying the Freezed v3 pattern from an
    existing generated file (`time_tracker_bloc.freezed.dart`,
    `dashboard_charts_bloc.freezed.dart`). List fields need the private `_field` backing,
    `EqualUnmodifiableListView` getter, and `DeepCollectionEquality` in ==/hashCode.
  - Edit `service_locator.config.dart` manually, keeping the `_iNNN` prefix style.
- All Cubit/Bloc state classes use `@freezed`; hand-rolled `copyWith` state classes were
  eliminated (`MiniTrackerState` was the last one).

### 2.4 Design system usage

- **No hardcoded `Color(0xFF...)`, `Colors.white/black`, or literal pixel paddings in
  `apps\`.** Use `theme.colorsPalette.*` / `theme.spacings.*`. If a token does not exist,
  add it to the style system package first (as was done with `SidebarColors` and
  `kBadgePalette`). *Why:* single-point theme changes and future dark-mode support.
- **Spacing token trap:** `theme.spacings.xs == 2` and `theme.spacings.xxs == 4` -
  `xs` is SMALLER than `xxs` in this codebase. Check before substituting literals.
- No italic text anywhere in UI - hierarchy is expressed via size/color only.
- Asset freeze for new UI: use `Placeholder()` and standard Material `Icons`, no new
  binary assets without an explicit decision.

### 2.5 Localization

- l10n infrastructure is deliberately NOT set up (backlog, section 4). Until it is:
  every new hardcoded user-visible string MUST carry `// TODO: l10n`.
  *Why:* the comments are the migration inventory for the future `app_en.arb` pass.

### 2.6 Testing

- TDD is mandatory (see `apps\worklog_studio\CLAUDE.md`): red -> green -> refactor; no
  production logic without a test. Domain/service tests in `test\core\`, bloc/state tests
  in `test\feature\`, shared fakes in `test\helpers\test_fakes.dart`.
- **`bloc_test` is NOT in the pubspec.** Assert via `bloc.add(event)` +
  `await Future<void>.delayed(Duration.zero)` (one microtask is enough for handlers and
  async ChangeNotifier `_init()` to settle), or `bloc.stream.listen`.
- Blocs with an async `_init()` (e.g. `HistoryBloc` restoring SharedPreferences) race
  with test events - always `await Future<void>.delayed(Duration.zero)` after
  construction before dispatching test events, and make "initial state" tests async with
  `await bloc.close()`.
- Prefer hand-rolled fakes over mocks for stateful collaborators; `mocktail` only for
  pure event sources.
- For `EntityResolver`-style tests, drive a REAL `TimeTrackerBloc` with fake repos and
  dispatch `TimeTrackerLoaded()` - simpler and more faithful than faking the bloc.
- Widget-test harness for drawer-class widgets: `MultiProvider` with
  `AppNavigationController` (Provider), `TimeTrackerBloc` (BlocProvider.value),
  `ProjectTaskState` (ChangeNotifierProvider.value), `EntityResolver`
  (ChangeNotifierProvider create), wrapped in
  `MaterialApp(theme: AppTheme.lightThemeData)`; set
  `tester.view.physicalSize = Size(1400, 1600+)` + `addTearDown(tester.view.reset)` to
  avoid overflow failures.
- Widget tests live under `test\feature\` (e.g. `test\feature\drawers\`), NOT a separate
  `test\widget\` root. *Why:* CI and build scripts run
  `fvm flutter test test/core/ test/feature/` - anything outside those roots silently
  never runs.

### 2.7 Tooling and process

- Always `fvm` - never bare `flutter`/`dart`. Dependency resolution ONLY via
  `fvm exec melos bootstrap` from the monorepo root; a bare `pub get` in a subdirectory
  desyncs the workspace.
- Run tests from `apps\worklog_studio\`, not the repo root.
- Never launch the app (`flutter run`) to verify - use `flutter test` and `dart analyze`.
- `dart analyze <files>` is REQUIRED after DI/import changes to `lib\` files that tests
  do not compile (e.g. `app.dart`) - a green test suite does not prove they build.
- Git hygiene: grep for imports before deleting any Dart file (even obviously dead ones);
  use `git rm`/`git mv` so changes stage cleanly; commit per completed item.
- Commit messages: no AI-attribution trailers; and never use em/en dashes in any generated
  text, code, comments, or scripts - a plain hyphen only (dash characters have corrupted
  PowerShell scripts via encoding before).

---

## 3. PITFALLS & TROUBLESHOOTING

Every entry here caused real lost time. Check this list FIRST when something looks weird.

### 3.1 build_runner is broken
`fvm flutter pub run build_runner build` fails with Dart 3.10.4 +
`native_toolchain_c 0.19.1` (build hooks). **Workaround:** hand-write `.freezed.dart`
and `service_locator.config.dart` edits (patterns in 2.3). If the SDK or
native_toolchain_c is ever upgraded, retry codegen and delete this entry.

### 3.2 Bloc created in `setUp` inside widget tests silently stalls
**Symptom:** `testWidgets` taps a button, the callback runs (flags flip), but the bloc's
event handler side effects (repo writes) are missing when `expect` runs.
**Cause:** `setUp` executes outside the `testWidgets` FakeAsync zone; a Bloc constructed
there binds its event pipeline to the real zone, and events added inside the test body
complete only after the test finishes.
**Fix:** construct the Bloc INSIDE the testWidgets body (an `initBloc()` helper called as
the first line). ChangeNotifiers tolerate setUp construction; Blocs do not.

### 3.3 Stale IDE diagnostics after style-system/package changes
After editing the style system package (new tokens, new exports), the IDE analyzer shows
`undefined_getter`/`undefined_identifier` errors in the app for a long time even after
`fvm exec melos bootstrap`. **Trust `flutter test` and `dart analyze` output, not the IDE
problem panel.** The same applies to diagnostics pinned to pre-edit line numbers and to
spurious `argument_type_not_assignable` caused by Windows drive-letter case mismatch
(`d:` vs `D:`).

### 3.4 Circular imports on class extraction
Extracting a widget that references an enum/type from its original file, then importing
the original file back, creates a cycle. **Fix:** move the shared enum/type into its own
file (`app_route.dart` pattern). For the page/list split, keep the ViewMode enum in the
list component and re-export from the page.

### 3.5 Partial block replacement corrupts widget trees
Replacing an `AnimatedSwitcher` + ternary block with a new widget while leaving any stale
fragment (`: const SizedBox.shrink(...)`, an extra `)`) produces a cascade of parse errors
far from the edit site. **Fix:** always replace the ENTIRE old expression in one edit; if
errors appear at unrelated lines after a big replacement, look for orphaned ternary tails
and closing parens near the edit before believing any other diagnostic. Never use an
`if (false)` placeholder to "preserve structure".

### 3.6 `replace_all` renames hit declarations
Renaming a private class to public via replace-all also rewrites the class declaration
inside the block you intend to delete. Rename during copy, then delete the old class body
manually, then check for a stray trailing `}`.

### 3.7 frame-scheduling draft mutations (historical)
The `WidgetsBinding.instance.addPostFrameCallback` wrapper around drawer draft updates
existed to avoid "setState during build" from Select callbacks. It is REMOVED - do not
reintroduce it. Cubit `emit()` from user callbacks is safe. If you ever see a genuine
"emitted during build" error, fix the caller (move the call to a user-action callback),
do not re-add frame deferral.

### 3.8 Dependency landmines
- `dependency_overrides: uuid: ^4.5.2` in the app pubspec is UNRESOLVED tech debt
  (deliberately skipped - see backlog). Do not remove it blindly: transitive constraints
  currently require the override to converge.
- `idb_shim` looks dead for a Windows-only app but is actively imported by the
  web-specific `session_handle_db_web.dart` - keep it.
- `http` is used by the isolated `work_log` prototype (`data_layout.dart`) - removable
  only if/when work_log is deleted.
- `firebase_core`/`firebase_ai` ARE active (`Firebase.initializeApp` in `runner.dart`,
  `FirebaseAI.googleAI()` in `plan_json.dart`) despite older notes claiming otherwise -
  do not remove.
- `firebase_options.dart` contains `///` example code that looks like commented-out dead
  code - it is legitimate generated API documentation; leave it.

### 3.9 Test-runner friction
- `flutter test <file>` triggers a workspace-level `pub get` on EVERY invocation
  (~10-20s). Batch test runs; do not loop single files needlessly.
- `pumpAndSettle` never settles if a periodic-`Timer` widget is live
  (`LiveDurationText` ticks every second). It only renders for ACTIVE/running entries -
  keep test fixtures in `stopped` status unless you explicitly manage timers.
- `SharedPreferences.setMockInitialValues({})` in `setUp` + one-microtask delay before
  events is the pattern for prefs-backed blocs.

### 3.10 Editing discipline with this toolchain
- The Edit tool fails with "String not found" if the file changed earlier in the session -
  re-read the current lines before further edits to the same file.
- `firstOrNull` needs NO `package:collection` import (Dart 3 `IterableExtensions` in
  `dart:core`) - do not add the import for it.
- Multi-window/desktop context: the mini panel is a native Win32 GDI window
  (`NativeMiniPanel`), not a second Flutter engine - Flutter engine EGL races
  (flutter/flutter#155685) are why. Do not resurrect `desktop_multi_window`.

---

## 4. FUTURE BACKLOG

Honest list of what is NOT done, with the reason it was deferred.

### 4.1 Deferred by explicit decision (do not start without a human go-ahead)
- **Item 5 - go_router migration.** Highest-complexity item; touches every screen, the
  tray IPC bridge, and `AppNavigationController`. The plan mandates its own isolated
  branch and PR. Current routing: `AppRoute` enum + switch in `AppShell`, pages recreated
  on tab change by design.
- **Item 21 - split `ProjectTaskState`** into a repository cache
  (`ProjectTaskRepository`-style ChangeNotifier) and a `TrackerSelectionState` (or fold
  selection into `TrackerPanelCubit`). Today it mixes cache + CRUD + timer draft
  selection + reload triggers; every drawer receives all of it.
- **Item 46 - EntityResolver consolidation.** Widget `build()` methods still call
  `context.watch<EntityResolver>()` and do O(n) resolution per rebuild; the target is
  resolution inside the feature BLoCs with the resolver as an injected pure service.
- **Item 4 - l10n infrastructure** (skipped by user decision). ~40+ `// TODO: l10n`
  markers are the migration inventory.
- **Item 32 - mini panel footer stats** are a hardcoded placeholder string
  (`'Today 06h 15m   |   Total 24h 30m'` in `_MiniPanelFooter`). Needs wiring to real
  computed totals from the tracker snapshot.
- **Item 38 - `dependency_overrides: uuid`** (skipped by user decision) - investigate and
  remove the override when transitive deps allow.

### 4.2 Known soft spots
- **`work_log` feature** is an isolated prototype (Option B chosen: kept, marked with
  `// PROTOTYPE: not active` comments). It pins the `http` dependency and the legacy
  `IWorkLogRawDataUsecase` naming. Decide eventually: rebuild properly or delete.
- **Widget-test coverage** exists only for the three drawers (15 tests). Pages
  (history/tasks/projects/home), `GlobalTimeTrackerPanel`, mini panel components, and the
  selector components have no widget tests.
- **`GlobalTimeTrackerPanel` selectors** duplicate ProjectSelector/TaskSelector concepts
  with cubit-specific semantics - a candidate for unification once someone designs the
  callback surface to cover the `isRunning` + `exitEditMode` behavior.
- **Deprecation drift:** `withOpacity` (use `.withValues()`), `RegExp` deprecation info
  hints - harmless today, sweep them opportunistically.
- **Dark theme** is structurally possible now (all sidebar/mini-panel/badge colors are
  tokens) but `darkColorsPalette` still duplicates the light values.
- **`time_entry_drawer.dart.saved`** stray file exists in
  `feature/history/presentation/components/` - dead artifact, delete on next touch.

### 4.3 Standing environment constraints
- Windows-only development; never crawl `macos/`, `ios/`, `android/`, `linux/`, `web/`
  target directories (but remember 3.8: web-specific *source* files exist and keep deps
  alive).
- Tests must pass before build: `build.sh`, `bump.ps1`, and CI all run
  `fvm flutter test test/core/ test/feature/`.
