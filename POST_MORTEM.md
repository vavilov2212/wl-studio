# POST MORTEM: Worklog Studio - Book of Law

> **Status: authoritative, living document.** This is the accumulated architectural memory
> of the codebase, distilled after every non-trivial development session. It was seeded by
> the full structural refactoring cycle (plan:
> `docs/superpowers/plans/2026-07-07-structural-refactoring.md`, ~55 items executed across
> Tiers 1-10, originally filed as `POST_MORTEM_REFACTOR.md`, renamed here to drop the
> refactor-only framing) and is extended with a new session block every time a feature,
> refactor, redesign, deploy, or debugging run produces a reusable lesson. Every rule below
> was paid for with a real bug, a failed test run, or a dead end - treat them as laws of
> this codebase, not suggestions. Session-specific detail lives in the numbered subsections
> and pitfall entries (tagged with the session date); the four top-level sections
> (Architecture, Guardrails, Pitfalls, Backlog) are the standing, cross-session index.
>
> State at last update (2026-07-12, [feature] Reports page):
> **295/295 tests green**, `flutter analyze` clean on `lib\feature\reports\` and
> `ui_kit\src\table\`, confirmed against commit `1d59469` after the Bash tool recovered
> from a mid-session safety-classifier outage (pitfall 3.23).

---

## 0. PROJECT MAP & OPERATING RULES

Standing configuration that used to live directly in the project's `CLAUDE.md`. It moved
here so `CLAUDE.md` can stay a thin pointer (see the note at the top of that file); nothing
below is a "lesson learned" like sections 1-4, it is a priori project structure and tooling
policy that this whole document assumes as background.

> Output style and tool-priority rules (verbosity, native tools -> MCP -> LSP -> Bash) live
> in the user's global `~/.claude/CLAUDE.md` and apply here too.

### 0.1 Path map
This is a Flutter monorepository managed via Melos.
- **Root directory:** workspace root containing `melos.yaml`.
- **Main application:** `apps\worklog_studio\`
  * *Entry points:* `apps\worklog_studio\lib\main.dart` and
    `apps\worklog_studio\lib\main_development.dart`.
- **UI kit & design system:** `packages\worklog_studio_style_system\`
  * *Entry point:* `packages\worklog_studio_style_system\lib\worklog_studio_style_system.dart`
    (barrel export file).
  * **UI kit reference:** `packages\worklog_studio_style_system\UI_KIT.md` - read this
    first on any UI task. Contains all components, props, tokens, and theme architecture.
    Do not crawl source files to discover what exists; consult this file instead.

### 0.2 Environment constraints (strictly Windows)
- The development environment is **Windows**. All filesystem paths must use backslashes
  (`\`).
- Completely ignore and never crawl platform-specific directories for other OS targets
  (`macos\`, `ios\`, `android\`, `linux\`, `web\`) - but see pitfall 3.8: web-specific
  *source* files can still be live dependencies even though the `web\` target itself is
  ignored.

### 0.3 Strict token optimization & file exclusions
To optimize context limits and minimize token waste, file-reading, search, or listing
tools (native `Read`/`Grep`/`Glob`, or the `filesystem` MCP server as fallback) **MUST
NEVER** access, search, or index:
- `.fvm\` (internal SDK cache)
- `.git\` (version control metadata)
- `.dart_tool\` (local transient dart files)
- `**\build\` (all build and compilation artifacts)
- `*.freezed.dart` and `*.g.dart` (all auto-generated code-gen files - but see 2.3/3.1:
  these files are still hand-edited, just never bulk-scanned)

### 0.4 Git commit conventions
- **Never** add a `Co-Authored-By: Claude` (or any AI-attribution) trailer to commit
  messages. Commits must list only the human author.
- See also 2.7 for the rest of git hygiene (grep before delete, `git mv`, commit per item,
  no em/en dashes).

### 0.5 Active project skills matrix
7 custom Project Skills are configured. Align behavior with the matching skill whenever a
prompt fits its description:
1. `codebase-navigator-pro` - code exploration, logic tracing, onboarding. Enforces
   "Grep-First" strategy.
2. `codegen-sentinel` - editing models or classes with annotations. Enforces the
   `.freezed.dart` exclusion and reminds about build_runner (broken, see 3.1).
3. `l10n-asset-stubber` - UI tasks. Enforces an asset freeze (`Placeholder()`, standard
   `Icons`) and requires hardcoded strings to carry `// TODO: l10n` (see 2.5).
4. `melos-dependency-manager` - modifying `pubspec.yaml` files, syncing versions, using
   Melos.
5. `design-system-guard` - protects the separation between app logic and the UI kit;
   prevents hardcoded colors/paddings in `apps\` (see 2.4).
6. `surgical-refactor-pro` - deep code reviews, optimizing widget trees, splitting
   widgets, cleaning memory leaks (`dispose`).
7. `windows-desktop-expert` - desktop lifecycle, shortcuts, window sizing, native Windows
   integration (see 2.8).

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

### 1.9 Reports page (session 2026-07-12, [feature])

Built via `docs/superpowers/plans/2026-07-12-reports-page.md`, executed with
subagent-driven-development (5 tasks + a post-completion fix pass), journal at
`docs/worklog/2026-07-12-reports-page.md`, commits `c7b1b11..1d59469`.

- **New feature slice `feature/reports/`** follows the canonical scaffold (1.1) with one
  deliberate deviation: `reports_aggregator.dart` (pure static aggregation logic, zero
  Flutter/BLoC imports) sits directly under `feature/reports/`, not inside a `data/`
  subfolder - it is domain-shaped but feature-local, not a repository, so it does not earn
  its own `data/` layer. Full layout:
  `reports_aggregator.dart` (models + `ReportsAggregator.aggregate()`),
  `bloc/reports_{bloc,event,state,bloc.freezed}.dart`,
  `presentation/reports_page.dart`, `presentation/components/{reports_summary_panel,
  reports_table}.dart`.
- **`ReportsBloc` is provided at `MainApp` level** in `app.dart`, after
  `BlocProvider<HistoryBloc>` - consistent with 1.3 (pages are recreated on tab change; a
  screen-level provider would lose period/range selection on every navigation).
- **New style-system widget `WsGroupedTable<G, I>`**
  (`packages\worklog_studio_style_system\lib\ui_kit\src\table\ws_grouped_table.dart`) - a
  generic two-level expandable table (groups containing items), exported from the ui_kit
  barrel and documented in `UI_KIT.md`. Expand/collapse is local `setState` (correct per
  2.2 - purely cosmetic). Defaults to **collapsed** (`initiallyExpanded: false`); the
  constructor parameter exists so a future call site can opt into expanded-by-default.
- **Content-hugging table inside a scrolling page - the pattern to reuse:** when a table
  (or any list-shaped widget) must size itself to its content instead of filling the
  remaining screen height, the table's internal list uses
  `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` with the
  containing `Column` set to `mainAxisSize: MainAxisSize.min`, and the PAGE wraps its
  scrollable content region in exactly one `Expanded(SingleChildScrollView(...))`. Do not
  nest a second `Expanded(ListView(...))` inside the table AND wrap the table itself in
  `Expanded` at the page level - that produces two competing "fill available space"
  constraints with no finite bound and the table stretches to the bottom of the window
  regardless of row count (see pitfall 3.21). This contrasts with `WsTable`'s
  full-height-filling layout used elsewhere - the two widgets solve different layout
  problems, do not merge them.
- **Row-divider visual weight is a distinct token usage from container borders:** the
  outer card border uses `palette.border.primary.withValues(alpha: 0.4)` (subtle
  container edge); the in-list row dividers between every group/item row use
  `palette.border.primary` at full opacity (deliberately more visible, per explicit
  product request) - see guardrail 2.4.
- **`DashboardPeriod` enum is reused, not redefined** - imported from
  `feature/home/dashboard_chart_aggregator.dart`. Range logic itself (week/month/custom
  boundaries) is duplicated in `ReportsAggregator` rather than calling
  `DashboardChartAggregator`, because the two features' output shapes diverge enough that
  sharing the aggregation function would need a shared intermediate type not worth
  introducing for two call sites - acceptable duplication, not an oversight.

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
  triggers a conflict lint. **Exception:** the `Consumer<T>` widget AND the `Selector<T,
  R>` widget specifically fail to resolve through the transitive export in some files -
  when you use either, add the explicit `package:provider/provider.dart` import (added
  2026-07-12: `Selector<EntityResolver, List<ResolvedTimeEntry>>` in `reports_page.dart`
  needed it, same as `Consumer` already did).
- **Never import a sub-path from another package** (e.g.
  `package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart`).
  Only import a package's barrel file. *Why:* sub-path imports couple you to internal
  file layout that can move freely; if a type you need is not exported from the barrel,
  either add it to the barrel or avoid naming the type explicitly (inline the value, use
  a ternary, or let Dart infer the local variable's type) rather than reaching around the
  barrel (pitfall 3.18).
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
- **Any `StatefulWidget` with local hover/selection state that is emitted as an item in a
  `ListView`/`Column`'s `children` MUST receive `super.key` in its constructor, and the
  call site MUST pass an explicit `key:` (a stable identity, e.g. `ValueKey`).** *Why:*
  without a key Flutter reconciles list children by position; after any list mutation
  (sort, filter, expand/collapse) hover/selection state silently bleeds onto the row that
  now occupies the old position instead of following its original row. Confirmed with
  `WsGroupedTable`'s `_GroupRow`/`_ItemRow` (2026-07-12, pitfall 3.19) - the same fix
  already applied to `WsTable`'s row widgets during the 2026-07 refactor.

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
- **Row-divider color vs. container-border color are different tokens by alpha, not by
  hue.** In-list separators between table/list rows use `palette.border.primary` at full
  opacity (visible on purpose); the outer card/container border around the same widget
  uses `palette.border.primary.withValues(alpha: 0.4)` (subtle). Do not use the subtle
  alpha for row dividers - they read as invisible (added 2026-07-12, `WsGroupedTable`).
- **Never nest a `shrinkWrap: true` list inside an `Expanded`.** The two are
  contradictory: `Expanded` says "fill all available space", `shrinkWrap: true` says
  "size to content" - combining them produces a widget that stretches to fill the parent
  regardless of content (pitfall 3.21). When a list must hug its content width the list
  belongs in, use `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())`
  with `mainAxisSize: MainAxisSize.min` on the containing `Column`, and put the single
  `Expanded` at the PAGE level around a `SingleChildScrollView`, not around the list
  itself (see 1.9 for the full pattern).
- **When aligning a footer/total row against a header row built by another widget, copy
  its exact spacer technique, not just its flex values.** `Padding(right: token)` placed
  INSIDE each `Expanded` child produces different pixel math than a standalone
  `SizedBox(token)` placed BETWEEN `Expanded` siblings, even with identical flex ratios
  (pitfall 3.22).

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
- **If the Bash tool reports a "temporarily unavailable" safety-classifier error, retry
  once or twice, then fall back to manual code inspection and say so explicitly** - do
  not report a task as fully verified when `fvm flutter analyze`/`fvm flutter test`
  could not actually be run (pitfall 3.23). Read-only tools (Read/Grep/Glob) are
  unaffected and remain reliable evidence for a manual review.

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

### 3.18 Typing a private helper with an unexported type forces a sub-path import
**Symptom:** a private helper (e.g. `Color _colorFor(...)`) needs an explicit return/param
type like `ColorsPalette`, which is not exported from the style-system barrel, so the only
way to name it is `import 'package:worklog_studio_style_system/theme/colors_palette/
colors_palette_entity.dart'` - a forbidden sub-path import (guardrail 2.1).
**Cause:** reaching for an explicit type annotation out of habit, when Dart's inference
already gives the same safety.
**Fix:** inline the expression (ternary/ternary chain) instead of a separately-typed
helper, or let the local variable's type be inferred (`final color = ...`). Confirmed in
`reports_summary_panel.dart` (2026-07-12): `_colorFor` returning `ColorsPalette` was
replaced by an inline `slice.id.isEmpty ? palette.text.muted :
BadgeUtils.getBadgeColor(slice.id).$2` ternary at each call site.

### 3.19 Missing `super.key` on a StatefulWidget rendered as a list item bleeds hover state
**Symptom:** after a list re-renders (e.g. groups reordered/filtered), the hover/highlight
visual appears on the WRONG row - the one that now occupies the position the hovered row
used to have.
**Cause:** without a `Key`, Flutter's element reconciliation matches new widgets to old
elements by TYPE + POSITION in the children list, not by logical identity. A `State`
object (and its `_isHovered` field) gets reused for whatever widget now lands in that
slot.
**Fix:** give the widget constructor `super.key` and pass a stable `key:` (e.g.
`ValueKey(id)`) at every call site that builds it inside a list. Confirmed twice in this
codebase: `WsTable` row widgets during the 2026-07 refactor, and `WsGroupedTable`'s
`_GroupRow`/`_ItemRow` on 2026-07-12 (commit `11a859d`). See guardrail 2.2.

### 3.20 A widget's "did anything meaningful change" comparison must read both widgets with their OWN builder function
**Symptom:** `didUpdateWidget`-style diffing (e.g. `_groupsUnchanged(oldGroups,
oldWidget.groupKeyBuilder, newGroups, widget.groupKeyBuilder)` in `WsGroupedTable`)
silently misbehaves if a caller ever passes a DIFFERENT `groupKeyBuilder` closure across
rebuilds (e.g. one that captures rebuilt local state) - because the comparison used
`widget.groupKeyBuilder` (the NEW widget's builder) to key BOTH the old and the new
groups, instead of `oldWidget.groupKeyBuilder` for the old side.
**Cause:** grabbing the nearest-in-scope variable (`widget.x`) instead of the
semantically correct one (`oldWidget.x`) when writing an old-vs-new comparison.
**Fix:** always pair `oldWidget.<builder>` with the OLD collection and `widget.<builder>`
with the NEW collection. Low blast radius when builders happen to be pure/stateless
functions (as they are today), but fix it anyway - it is a latent bug waiting for a
stateful builder. Fixed in commit `11a859d`.

### 3.21 A table/list stretches to fill the whole screen regardless of row count
**Symptom:** a table with 2 rows visually occupies the entire remaining vertical space
down to the bottom of the window, with a large empty area below the last row.
**Cause:** the table was wrapped in `Expanded` at the page level, AND the table's
internal row list was ALSO wrapped in `Expanded(ListView(...))` internally - two nested
"fill all available space" constraints with nothing bounding the outer one to the
content's actual height.
**Fix:** the list that should hug its content becomes
`ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` inside a
`Column(mainAxisSize: MainAxisSize.min)`; the SINGLE `Expanded` in the whole chain wraps
a `SingleChildScrollView` at the page level, not the table itself. Fixed in
`reports_page.dart` / `ws_grouped_table.dart`, 2026-07-12 (see 1.9, guardrail 2.4).

### 3.22 Footer row misaligned against header row despite identical flex values
**Symptom:** a `_TotalRow`'s "Hours" column sits ~8-10px off from the header's "Hours"
column even though both use `Expanded(flex: 1)` for that slot.
**Cause:** the header row (`WsGroupedTable._buildHeader`) puts `Padding(right: token)`
INSIDE each `Expanded` child to create inter-column gaps; `_TotalRow` instead placed
standalone `SizedBox(token)` widgets BETWEEN the `Expanded` siblings. Both approaches
produce "gaps between columns" visually, but they consume the parent `Row`'s width
differently, so equal flex ratios no longer map to equal pixel widths.
**Fix:** when a second widget must align to a row built by another widget, copy its exact
spacer placement (inside-vs-between `Expanded`), not just its flex numbers. Fixed in
commit `c590acd`.

### 3.23 Bash tool blocked mid-session by a safety-classifier outage
**Symptom:** every Bash invocation (including harmless read-only-equivalent commands like
`fvm flutter analyze`) fails with `"claude-sonnet-4-6 is temporarily unavailable, so auto
mode cannot determine the safety of Bash right now."`, while `git status`/native
Read/Grep/Glob keep working.
**Cause:** an upstream safety-classifier dependency of the Bash tool became temporarily
unavailable; unrelated to the repository or the command being run.
**Fix:** retry after a short wait; if it keeps failing, proceed with everything that does
not need Bash (file edits, manual code review, journal/doc updates) and explicitly tell
the user that `flutter analyze`/`flutter test` still need to be run manually before the
change is considered verified (guardrail 2.7). Do not claim tests "pass" when they were
only reviewed by eye. Encountered 2026-07-12 while wrapping up the Reports page
post-completion fixes; commit `1d59469` landed before analyze/test could be run, but both
were confirmed clean shortly after in the same session once Bash recovered.

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

Added in session 2026-07-12 (Reports page, [feature]):

- ~~`flutter analyze`/`flutter test` were never re-run against the final commit
  (`1d59469`)~~ **Resolved same session:** once the Bash tool recovered from the
  safety-classifier outage (pitfall 3.23), `fvm flutter analyze
  apps\worklog_studio\lib\feature\reports\
  packages\worklog_studio_style_system\lib\ui_kit\src\table\` came back clean and
  `fvm flutter test test/core/ test/feature/ --reporter expanded` passed 295/295. Left
  here as a reminder of the pattern (manual read-through is not a substitute for running
  the tools once they are available again), not as an outstanding action.
- **Reports feature has zero widget-test coverage.** `ReportsScreen`,
  `ReportsSummaryPanel`, `ReportsTable`, and `WsGroupedTable` are covered only by the
  domain test (`test\core\reports_aggregator_test.dart`) and the bloc test
  (`test\feature\reports\reports_bloc_test.dart`) - no `testWidgets` exercise the actual
  rendered table/chart/toolbar. Follow the drawer-class harness pattern (2.6) if this
  gets picked up.
- **Magic numbers pending tokenization (Reports UI):** donut chart geometry (180x180,
  `radius: 40`, `centerSpaceRadius: 45`, `sectionsSpace: 2` - fl_chart requires literal
  values), `_ProgressBar` height `6`, `WsGroupedTable` row heights `40`/`36`, legend dot
  size `8`, legend `maxWidth: 140`, icon sizes `14`/`16`/`18`, `Select` width `110`. Same
  category as the 2026-07-08 entry above - no design tokens exist yet for these; sweep
  opportunistically if/when a control-metrics token system is introduced.
- **`ReportsAggregator.aggregate(entries: const [])` is called twice per toolbar
  rebuild** (once in `_PeriodToolbar` for the non-custom range label, once again inside
  `_CustomRangeLabel`) purely to obtain `rangeLabel` from an otherwise-empty aggregation.
  Cheap (empty list) but redundant - extract a dedicated pure `rangeLabel()` function as
  a follow-up if `ReportsAggregator` grows more expensive.
- **`WsGroupedTable.initiallyExpanded`** defaults to `false` (changed from `true` during
  this session's post-completion fixes) with no current call site that opts into
  expanded-by-default - if that need never materializes, consider whether the parameter
  is still pulling its weight, or whether "always collapsed" should become the hardcoded
  behavior instead of a configurable default.

### 4.3 Standing environment constraints
- Windows-only development; never crawl `macos/`, `ios/`, `android/`, `linux/`, `web/`
  target directories (but remember 3.8: web-specific *source* files exist and keep deps
  alive).
- Tests must pass before build: `build.sh`, `bump.ps1`, and CI all run
  `fvm flutter test test/core/ test/feature/`.
