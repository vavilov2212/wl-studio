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

### 1.6 History page scroll compaction (session 2026-07-08)

The history page header compacts when the entry list is scrolled past 50px. Architecture
decisions worth reusing on other pages:

- **Cosmetic scroll state stays in the widget.** `_isScrolled` is a `ValueNotifier<bool>`
  in `_HistoryScreenState`, fed by the existing `NotificationListener<ScrollNotification>`
  and consumed via one `ValueListenableBuilder` wrapping the page body. It never touches
  `HistoryBloc` - it is pure presentation state per guardrail 2.2. The KPI strip's
  hide-on-scroll shares the same bool (one threshold, one source of truth).
- **Compaction is two discrete states animated with implicit widgets** (`AnimatedPadding`,
  `AnimatedSize`, `AnimatedDefaultTextStyle`, `AnimatedOpacity`, `AnimatedContainer`),
  all sharing `_compactDuration` (200ms, same as the KPI strip's `AnimatedSwitcher`) and
  `_compactCurve` (easeOutCubic). No explicit AnimationControllers.
- **Only vertical paddings compact.** Horizontal page padding stays constant so the
  table does not reflow horizontally during the transition.
- **`ScrollController` is owned by the page** and passed into `TimeEntryList`; the
  go-to-top button and the stats-toggle's scroll-to-top both drive it.
- **`inline` mode pattern for composable bars:** `HistorySortBar` and `HistoryFilterBar`
  expose `inline: true` which returns the bare controls `Row` (no Align, no padding, no
  scrollbar). The caller (`_CompactToolbarRow` in `time_entry_list.dart`) composes them
  into one right-aligned, horizontally scrollable row with a vertical divider. The
  stacked (non-inline) layout is untouched. Reuse this pattern instead of duplicating
  bar internals when a layout wants to recompose existing toolbars.
- **Page-wide mouse-wheel scrolling:** a `Listener(behavior: HitTestBehavior.translucent)`
  over the page routes `PointerScrollEvent`s into the list through
  `GestureBinding.instance.pointerSignalResolver.register(...)` (see pitfall 3.14).

### 1.7 Style-system component changes (session 2026-07-08)

- `SegmentedToggle` gained `compact: bool` and explicit heights (36px normal / 28px
  compact) that mirror `PrimaryButton`'s hardcoded height constants; segments stretch
  vertically inside a fixed-height track. Styling inverted to muted track
  (`surfaceMuted` + full `border.primary`) with a white selected thumb so the whole box
  reads as the control (see pitfall 3.15).
- `ClearableFilterPill.overlap` (10.0) is now a public static const - the space the pill
  always reserves above/right of its child for the clear badge. Sibling rows without a
  pill pad themselves by this constant to stay aligned (see pitfall 3.13).
- Both are documented in `UI_KIT.md`.

### 1.8 Native activity window + hotkeys (session 2026-07-08)

- `NativeActivityWindow.hide()` uses `ShowWindow(SW_HIDE)`, NOT `DWMWA_CLOAK`. The cloak
  trick exists only to protect Flutter-engine-backed windows from `WM_SHOWWINDOW`
  suspend crashes; this window is pure Win32 (no engine), and cloaking left a ghost
  taskbar entry (see pitfall 3.12). `show()` first recovers from a shell-minimized
  state via `IsIconic` -> `SW_SHOWNOACTIVATE`, then applies the frame, then shows if
  Win32-hidden.
- Default global hotkeys are Ctrl+Alt+M / Ctrl+Alt+A / Ctrl+Alt+X (`HotkeyService`).
  Both Ctrl+Shift and Alt+Shift are Windows' built-in input-language switch gestures
  and can silently swallow the chord - never default to either pair.

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
- **Never pass an explicit `size:` to an `Icon` used as `leftIconWidget`/`rightIconWidget`
  of `PrimaryButton`.** The button wraps icons in a `SizedBox(iconDimension)` (xs: 12,
  sm: 14, md: 18, lg: 22) and sizes them via `IconTheme`; a larger explicit size paints
  past that box and the icon looks shifted toward the bottom-right (pitfall 3.11).
- **`AnimatedDefaultTextStyle` must receive a style with an explicit `color`.** It
  REPLACES the ambient `DefaultTextStyle` instead of merging like `Text(style:)` does;
  a token style without color renders white (pitfall 3.16).
- **Control-height source of truth:** `PrimaryButton` heights are hardcoded (xs 28,
  sm 36, md 40, lg 44) and do NOT match the `ControlSize` token table (32/40/48/52).
  Any new inline control that must align with buttons (toggles, pills) aligns to the
  BUTTON constants. `SegmentedToggle` does this explicitly.
- **Anything placed on the same row as `ClearableFilterPill`-wrapped controls must
  compensate for `ClearableFilterPill.overlap`** (10px always reserved on top/right,
  even when inactive - by design, to keep the widget tree shape stable). Either
  bottom-align the row (`CrossAxisAlignment.end`) or pad by the constant.
- Purely visual scroll-reaction state (compact headers, hide-on-scroll strips) lives in
  a `ValueNotifier` inside the screen State, consumed via `ValueListenableBuilder` -
  never in the feature BLoC.

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

### 2.8 Windows native windows and global hotkeys

- **Pure Win32 windows (no Flutter engine) hide with `ShowWindow(SW_HIDE)`.**
  `DWMWA_CLOAK` is reserved exclusively for Flutter-engine-backed HWNDs (it exists to
  avoid `WM_SHOWWINDOW` suspend crashes). Cloaking a plain window leaves `WS_VISIBLE`
  set: the taskbar button, Alt-Tab entry, and thumbnail survive as an unclickable ghost,
  and the shell can activate/minimize the invisible window (pitfall 3.12).
- **Every native `show()` path must handle the minimized state first:**
  `IsWindowVisible` returns TRUE for minimized windows, so a plain
  "if not visible then ShowWindow" check silently leaves an iconic window minimized.
  Check `IsIconic` and restore with `SW_SHOWNOACTIVATE` (or `SW_RESTORE` when focus is
  wanted) before applying frames.
- **Never default global hotkeys to Ctrl+Shift+X or Alt+Shift+X on Windows** - both
  chords are OS input-language switch gestures with 2+ keyboard layouts installed and
  can swallow the combo before the third key lands. Current defaults: Ctrl+Alt+M/A/X.
- Changing hotkey DEFAULTS does not affect users with previously saved bindings -
  `HotkeyService` stored settings override `defaultHotKeyFor`. A default change needs
  either a settings migration or a release-notes instruction to re-save.

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

### 3.11 Icons inside PrimaryButton paint outside their box when given an explicit size
**Symptom:** an icon-only button's glyph looks shifted toward the bottom-right corner,
with excess space on the left/top.
**Cause:** `PrimaryButton._wrapIcon` puts the icon in a `SizedBox(iconDimension)` where
iconDimension is 12 (xs) / 14 (sm). An `Icon(..., size: 16)` overrides the `IconTheme`
and overflows the 12-14px box; the overflow paints down-right.
**Fix:** pass `Icon(iconData)` with NO size and let the button's `IconTheme` size it.

### 3.12 DWMWA_CLOAK on a plain Win32 window creates an unkillable taskbar ghost
**Symptom:** after "hiding" the native activity window it stays in the taskbar/Alt-Tab
with a thumbnail; clicking it does nothing; later programmatic `show()` calls appear
dead; closing via the X button "fixes" everything.
**Cause chain:** cloak only hides the DWM visual - `WS_VISIBLE` stays set, so the
taskbar entry survives; the user clicks it; the shell activates/minimizes the invisible
window; `show()` checked `IsWindowVisible` (TRUE for minimized windows) and skipped
`ShowWindow`, and uncloaking does not un-minimize - the window stays iconic forever.
The X button worked because `DestroyWindow` forces a clean re-create.
**Fix:** `SW_HIDE` on hide; `IsIconic` -> `SW_SHOWNOACTIVATE` at the top of show.
See guardrail 2.8.

### 3.13 ClearableFilterPill silently misaligns sibling rows by 10px
**Symptom:** a select next to pill-wrapped selects sits ~10px higher and its right edge
overhangs the pill-wrapped column.
**Cause:** the pill ALWAYS pads its child `top/right` by `ClearableFilterPill.overlap`
(10px) to reserve clear-badge space - deliberately even when inactive, because toggling
the padding would change layout and recreate the child's State.
**Fix:** bottom-align mixed rows (`CrossAxisAlignment.end`) and/or pad the pill-less
sibling by the now-public `ClearableFilterPill.overlap` constant. Do NOT "fix" the pill
by making the padding conditional - the stable-tree-shape comment in the widget explains
why that breaks open Combobox state.

### 3.14 Page-wide wheel scrolling without double-scroll: PointerSignalResolver
To make the mouse wheel scroll a list even when the cursor is over headers/blank space,
wrap the page in `Listener(behavior: HitTestBehavior.translucent, onPointerSignal: ...)`
and inside the handler call
`GestureBinding.instance.pointerSignalResolver.register(event, callback)` - never apply
the scroll directly. The resolver keeps only the FIRST registered callback, and dispatch
runs leaf-up, so when the cursor is over the real `Scrollable` the Scrollable wins and
the page handler is ignored; over dead space the page handler wins. Direct handling
(without the resolver) double-scrolls whenever the cursor is over the list. Guard with
`_scrollController.hasClients` and clamp to `min/maxScrollExtent` before `jumpTo`.

### 3.15 "Component looks the wrong size" disputes: measure, do not eyeball
When a widget "looks smaller/larger" than a neighbor, write a throwaway `testWidgets`
probe that pumps both widgets and prints `tester.getSize(...)` before changing any code
(run it from `test\probe\`, delete after). This session the SegmentedToggle "height bug"
turned out to be 36px == 36px exactly; the real problem was styling (white track on the
near-white canvas made only the inner 30px thumb read as the control). Geometry fixes
and perception fixes are different fixes - identify which one you need first.

### 3.16 AnimatedDefaultTextStyle renders text white when the style has no color
`Text(style: s)` MERGES `s` with the ambient `DefaultTextStyle`, so token styles without
an explicit color inherit the theme color. `AnimatedDefaultTextStyle(style: s)` REPLACES
the ambient style; a color-less token style then paints with the render default (white).
Always `copyWith(color: palette.text.*)` when moving a text into
`AnimatedDefaultTextStyle`.

### 3.17 Buttons whose visible effect lives off-screen feel broken
The KPI-strip toggle "did nothing" when the page was scrolled because the strip renders
only at the top of the page. When a control's effect is not in the viewport, pair the
state change with navigation to where the effect appears (the toggle now scrolls to top
when turning the strip on). Audit any toggle that shows/hides an anchored region.

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

Added in session 2026-07-08:

- **History compaction has no widget tests.** The compact/normal header states,
  go-to-top visibility, stats-toggle scroll-to-top, and the `_CompactToolbarRow`
  composition were verified only by hand and by the deleted size-probe test. Widget
  tests belong in `test\feature\history\` (see 2.6 for the harness pattern).
- **Magic numbers pending tokenization:** the compact title `fontSize: 15` in
  `history_page.dart` (no NunitoSans small-heading token exists); the 50px scroll
  threshold (duplicated conceptually with the KPI strip logic, now one bool but the
  constant is inline); `SegmentedToggle`'s 36/28 heights mirror `PrimaryButton`'s
  private height constants by copy - a shared button-height token in the style system
  would remove the coupling. Also note the `ControlSize` table (32/40/48/52) does not
  match actual `PrimaryButton` heights (28/36/40/44) - unify someday.
- **`NativeActivityWindow` still has zero automated coverage** (pure Win32 FFI, no test
  seam). The hide/show/IsIconic logic is verified only behaviorally. If it regresses
  again, consider extracting a testable state machine around the Win32 calls.
- **Hotkey default change is silent for existing users:** stored bindings from older
  builds override the new Ctrl+Alt defaults until re-saved in Settings. No migration
  was written (deliberate - low impact); revisit if users report "wrong" defaults.
- **Commit c571665 mixed concerns:** it bundled this session's history/hotkey/window
  work with unrelated working-tree edits (ws_table, time_entry_card/drawer, app icon)
  that were already dirty. Nothing to fix, but bisecting through it later will be
  noisier than usual.

### 4.3 Standing environment constraints
- Windows-only development; never crawl `macos/`, `ios/`, `android/`, `linux/`, `web/`
  target directories (but remember 3.8: web-specific *source* files exist and keep deps
  alive).
- Tests must pass before build: `build.sh`, `bump.ps1`, and CI all run
  `fvm flutter test test/core/ test/feature/`.
