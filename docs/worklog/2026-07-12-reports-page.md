# Reports Page - Work Journal

**Plan:** `docs/superpowers/plans/2026-07-12-reports-page.md`
**Date:** 2026-07-12
**Branch:** dev

---

## Task 1: ReportsAggregator

**Commits:** ec72a02..93f41c2 (2 commits: implementation + fix)

### Verified Facts
- Created `apps/worklog_studio/lib/feature/reports/reports_aggregator.dart` with data models (`ReportSlice`, `ReportsTaskRow`, `ReportsProjectGroup`, `ReportsData`) and `ReportsAggregator.aggregate`.
- Created `apps/worklog_studio/test/core/reports_aggregator_test.dart` with 7 tests.
- TDD order confirmed: stub with `UnimplementedError` -> tests red (7/7 fail) -> implementation -> tests green (7/7 pass).
- `fvm flutter analyze lib/feature/reports/` - no issues.
- Fix commit added `// TODO: l10n` to `_monthNames` and all `_label()` returns; corrected separator to `→` (U+2192).

### What Worked
- Pure-Dart aggregator (no Flutter imports) is trivially testable - no widget test scaffolding needed.
- Using empty-string sentinel (`''`) for "no project / no task" projectId makes the sort-to-bottom logic a single comparator check.
- `_dateOnly(DateTime)` helper strips time component cleanly; all range comparisons use date-only values.

### Distilled Rules
- All user-visible strings (including `_monthNames` and label format strings) require `// TODO: l10n` comment - even if "the code is internal".
- Range separator must be `→` (U+2192), NOT ` - ` or `—`. Match the spec literally.
- Custom range: `customRangeEnd` is user-inclusive; internally end = `customRangeEnd + 1 day` (exclusive upper bound).
- "No Project" group (`projectId == ''`) must always sort last - explicit `if (a.projectId.isEmpty) return 1` before duration compare.
- `e.task?.title ?? 'Unassigned'` (NOT `e.taskTitle` which returns `'Unassigned Task'`).
- `DashboardPeriod` is imported from `feature/home/dashboard_chart_aggregator.dart` - not re-defined.

### Pitfalls and What to Avoid
- `_monthNames` static const was written without `// TODO: l10n` initially - caught by reviewer. Always annotate month/weekday name arrays.
- Implementer used ` - ` (plain hyphen with spaces) as range separator instead of `→`. Always copy character literals verbatim from the plan.

### What's Next
**Task 2: ReportsBloc** (no blocking prerequisites - `DashboardPeriod` already exists, aggregator types are ready).
Files: `bloc/reports_bloc.dart`, `bloc/reports_event.dart`, `bloc/reports_state.dart`, `bloc/reports_bloc.freezed.dart` (hand-written), `test/feature/reports/reports_bloc_test.dart`.

---

## Task 2: ReportsBloc

**Commits:** 93f41c2..415fec7 (1 commit)

### Verified Facts
- Created `bloc/reports_event.dart`, `bloc/reports_state.dart`, `bloc/reports_bloc.dart`, `bloc/reports_bloc.freezed.dart` (hand-written Freezed v3).
- Created `test/feature/reports/reports_bloc_test.dart` with 9 tests.
- 9/9 tests pass; `fvm flutter analyze lib/feature/reports/bloc/` - no issues.
- `canStepForward` is public static (accessible from UI widget).
- Initial state: `DashboardPeriod.week`, `anchorDate` = date-only truncation of `clock.now()`.

### What Worked
- Reading `dashboard_charts_bloc.freezed.dart` directly before writing the hand-written file produced a correct result on the first try - the existing file is the authoritative template.
- `null` sentinel for non-nullable fields, `freezed` sentinel for nullable fields in `copyWith` impls.

### Distilled Rules
- Hand-written `.freezed.dart` must contain all 7 constructs in order: `mixin _$X`, `abstract mixin class $XCopyWith`, `_$XCopyWithImpl`, `extension XPatterns`, `_X` concrete class, `abstract mixin class _$XCopyWith`, `__$XCopyWithImpl`.
- `canStepForward` is PUBLIC (not private `_canStepForward`) - UI calls it directly on the BLoC class.
- `DashboardPeriod.custom` stepping: `_stepAnchor` returns anchor unchanged; canStepForward already blocks direction > 0 for custom. Stepping left on custom is undefined UX but safe.

### Pitfalls and What to Avoid
- Minor: `Future<void>.delayed(Duration.zero)` queue drain in tests is fragile vs `bloc_test` patterns - acceptable for this codebase style, not a blocker.
- Minor: No explicit guard for `direction < 0` on `custom` period in `_stepAnchor` - but UI never allows it so effectively a no-op.

### What's Next
**Task 3: WsGroupedTable** (independent of Tasks 1-2 - pure style system widget).
Files: `packages/worklog_studio_style_system/lib/ui_kit/src/table/ws_grouped_table.dart`, barrel export, UI_KIT.md update.

---

## Task 3: WsGroupedTable

**Commits:** 415fec7..11a859d (2 commits: implementation + fix)

### Verified Facts
- Created `packages/worklog_studio_style_system/lib/ui_kit/src/table/ws_grouped_table.dart`.
- Export added to `ui_kit/ui_kit.dart` after `ws_table.dart`, before `table_toolbar.dart`.
- `UI_KIT.md` updated with `### WsGroupedTable` section before `### TableToolbar`.
- `fvm flutter analyze lib/` - 0 issues in new file (5 pre-existing unrelated warnings in sidebar_item.dart and select.dart).
- Fix: added `super.key` to `_GroupRow` + key at call site; fixed `_groupsUnchanged` to use `oldWidget.groupKeyBuilder` for old groups.

### What Worked
- Reading `ws_table.dart` first and mirroring its hover pattern (transparent InkWell + manual `_isHovered` color) produced correct hover behavior.
- Using `ListView(children: rows)` inside `Expanded` for body scrolling matches the spec and avoids layout complexity of `CustomScrollView`.
- `Row([chevron, SizedBox, Expanded(content)])` in the first cell of group rows (no Align wrapper) correctly allows bounded width for `Expanded`.

### Distilled Rules
- Any `StatefulWidget` with local hover/selection state that appears in a `ListView` MUST have `super.key` and receive a key at the call site - otherwise Flutter reconciles by position and hover state bleeds between rows after list mutations.
- `_groupsUnchanged` comparison must use `oldWidget.builder` for old items and `widget.builder` for new items - not `widget.builder` for both.
- `InkWell(onTap: null, onHover: ...)` correctly fires hover events without a tap action - no need for `MouseRegion` when inside a `Material` ancestor.
- Group row first cell: never wrap the `[icon + Expanded(content)]` Row in an `Align` - `Align` passes unbounded width to its child, breaking `Expanded`.

### Pitfalls and What to Avoid
- Missing `super.key` on stateful list items is a subtle bug: the app compiles fine, hover state just bleeds. Always key stateful rows.
- `_groupsUnchanged` using the wrong widget's `groupKeyBuilder` is semantically wrong even if low-risk in practice (most builders are pure functions). Fix it anyway.
- `Icon(size: 16)` - no design system token exists for icon sizes in this project; hardcoded 16 is acceptable.

### What's Next
**Task 4: Navigation wiring + stub ReportsScreen** (depends on Task 2 ReportsBloc being complete - it is).
Files: `app_route.dart`, `sidebar_navigation.dart`, `app_shell.dart`, `app.dart`, stub `reports_page.dart`.

---

## Task 4: Navigation Wiring

**Commits:** 11a859d..30440bd (1 commit)

### Verified Facts
- `AppRoute.reports` added between `history` and `projects`.
- Sidebar: `_navItem(AppRoute.reports, 'Reports', Icons.bar_chart_rounded)` with `// TODO: l10n`, placed after History, before "Manage" label.
- AppShell: `case AppRoute.reports: return const ReportsScreen();` added; all 7 enum values handled.
- `BlocProvider<ReportsBloc>` added after `BlocProvider<HistoryBloc>` in app.dart.
- Stub `ReportsScreen` returns `const Placeholder()`.
- `fvm flutter analyze lib/feature/app/` - No issues found.
- IDE emitted stale diagnostics (unused imports) during commit; analyzer ran clean after.

### What Worked
- Reading existing sidebar structure before editing made placement unambiguous.
- The subagent correctly identified all exhaustive switch statements on `AppRoute`.

### Distilled Rules
- IDE diagnostics shown during or immediately after a commit can be stale - always re-run `fvm flutter analyze` to confirm before acting on them.
- All exhaustive `switch` statements on an enum must be audited when adding a new enum value - not just the most obvious one.
- `BlocProvider` order in `MultiProvider` matters for readability - follow the existing ordering convention (features in feature-list order, not random).

### Pitfalls and What to Avoid
- Stale IDE diagnostics after a commit caused a false alarm. Confirmed clean with `fvm flutter analyze`.

### What's Next
**Task 5: ReportsSummaryPanel + ReportsTable + full ReportsPage** (depends on Tasks 1-4 all complete - they are).
Files: `reports_summary_panel.dart`, `reports_table.dart`, replace stub `reports_page.dart`.

---

## Task 5: ReportsSummaryPanel + ReportsTable + Full ReportsPage

**Commits:** 30440bd..768f63a (2 commits: implementation + fix)

### Verified Facts
- Created `reports_summary_panel.dart`: `ReportsSummaryPanel` with total-hours, `PieChart` (donut), legend, `_BreakdownBar`.
- Created `reports_table.dart`: `ReportsTable` wrapping `WsGroupedTable<ReportsProjectGroup, ReportsTaskRow>` with Name/Hours/Progress columns, `_ProjectCell`, `_ProgressBar`, `_TotalRow`.
- Replaced stub `reports_page.dart`: full `ReportsScreen` with `BlocBuilder` + `Selector<EntityResolver>`, `_PeriodToolbar`, `_CustomRangeLabel`, `_StepperButton`, `_pickCustomRange` top-level function, empty-state path.
- 295/295 tests pass; `fvm flutter analyze lib/feature/reports/` - no issues.
- Fix: removed sub-path import `colors_palette_entity.dart`; inlined `_colorFor` as a ternary.

### What Worked
- `Selector<EntityResolver, List<ResolvedTimeEntry>>` with `ListEquality.shouldRebuild` correctly avoids redundant rebuilds.
- Calling `ReportsAggregator.aggregate(entries: const [])` purely for `rangeLabel` is a clean approach even if slightly redundant - it's a pure, cheap call on an empty list.
- `_BreakdownBar` with `Flexible(flex: (percent*1000).round().clamp(1,1000))` gives proportional widths without needing `LayoutBuilder`.

### Distilled Rules
- NEVER import sub-paths from other packages (e.g., `package:pkg/theme/colors_palette/entity.dart`). Only import from the package's barrel (`package:pkg/pkg.dart`). If a type isn't exported, either add it to the barrel or avoid using the type name explicitly (use `var`/`final`/inference).
- `package:provider/provider.dart` must be imported EXPLICITLY alongside `package:flutter_bloc/flutter_bloc.dart` when using `Selector<EntityResolver, ...>` - flutter_bloc does not re-export provider.
- `withValues(alpha:)` is correct; `withOpacity()` is deprecated in this Flutter version.
- `BadgeUtils.getBadgeColor(id).$2` for non-empty project ids; `palette.text.muted` for empty id (the "No Project" sentinel).

### Pitfalls and What to Avoid
- Typing a private helper with `ColorsPalette` forces an internal sub-path import. Prefer inlining or using Dart's type inference.
- Minor findings from review (hardcoded `height: 6`, `height: 40`, dot sizes, legend `maxWidth: 140`) are acceptable because no equivalent design tokens exist - noted for future token system expansion.
- `Colors.black.withValues(alpha: 0.2)` for dialog barrier is acceptable (named constant, not hex literal).

### What's Next
All 5 tasks complete. Proceed with final whole-branch code review and `finishing-a-development-branch`.

---

## Final Whole-Branch Review

**Range:** ec72a02..c590acd (9 commits total)
**Verdict:** Ready to merge

### Findings fixed
- [Important] `_TotalRow` column alignment bug: `SizedBox(md)` spacers between `Expanded` children caused ~8-10px drift on the Hours total. Fixed by using `Padding(right: md)` inside each `Expanded` to match `WsGroupedTable._buildHeader`.

### Minor findings (no fix needed, tracked here)
- `ReportsAggregator.aggregate(entries: const [])` called twice per toolbar build (once for non-custom label, once in `_CustomRangeLabel`) - extractable to a `rangeLabel()` static as follow-up.
- `Colors.black.withValues(alpha: 0.2)` for dialog barrier - no design token for scrims, accepted exception.
- Breakdown bar height `12` hardcoded - no token equivalent.
- Donut chart magic numbers (180x180, radius 40, centerSpaceRadius 45, sectionsSpace 2) - fl_chart API requires literal values.
- Icon sizes 18px, 14px, 16px (chevron) hardcoded - no icon-size token system.
- `Select` width `110px` hardcoded - control-specific visual value, no token.

### Architecture invariants verified
- `ReportsAggregator.aggregate()` is pure static, no BLoC imports.
- `DashboardPeriod` reused from `feature/home/` - not re-defined.
- `ReportsBloc` has zero imports from `reports_aggregator.dart` (correct separation).
- `WsGroupedTable` is package-agnostic - only imports flutter + style system barrel.
- `Selector<EntityResolver>` used (not `context.watch`).
- `canStepForward` is public static.

### All tests
295/295 passing. `fvm flutter analyze lib/feature/reports/` - 0 issues.

---

## Post-Completion Fixes (Session 2)

**Files modified (uncommitted):** `reports_summary_panel.dart`, `ws_grouped_table.dart`, `reports_page.dart`

### Changes Made

1. **Delete breakdown bar** - Removed `_BreakdownBar` class and its invocation from `ReportsSummaryPanel.build()`. The outer `Column` now has only one child (the `Row` with total hours, donut, legend). No imports became orphaned because `BadgeUtils` is still used for the donut chart colors.

2. **Visible row dividers in WsGroupedTable** - Added `rowDividerColor = palette.border.primary` (full opacity, not `withValues(alpha: 0.4)` which is used for the container border). Inserted `Divider(height: 1, thickness: 1, color: rowDividerColor)` before each item row (inside the `if (isExpanded)` loop) and between consecutive group rows (after each group except the last, or always if `totalRowBuilder != null`).

3. **Table height fix** - Root cause: `ReportsTable` was inside `Expanded`, and `WsGroupedTable` used `Expanded(ListView)` internally, creating two competing expand-to-fill widgets with no finite bound on height. Fix: changed `WsGroupedTable` body to `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` + outer `Column(mainAxisSize: MainAxisSize.min, ...)`. In `ReportsPage`, replaced the unconstrained layout with `Expanded(SingleChildScrollView(...))` wrapping the content column, and removed `Expanded` from `ReportsTable`. Empty state is now `SizedBox(height: 200, Center(...))` inside the scroll view.

4. **initiallyExpanded: false as default** - Changed the `initiallyExpanded` default from `true` to `false` in `WsGroupedTable`.

### Distilled Rules

- `palette.border.primary` (full opacity) for visible row dividers; `palette.border.primary.withValues(alpha: 0.4)` only for subtle container borders.
- `shrinkWrap: true` + `NeverScrollableScrollPhysics()` is the correct pattern for a `ListView` inside a `SingleChildScrollView` - the outer scroll view drives scrolling, the inner list just sizes to its content.
- Never put a `shrinkWrap: true` list inside an `Expanded` - that creates a contradiction (expand to fill vs. shrink to content). Use `mainAxisSize: MainAxisSize.min` on the Column containing the list instead.
- When removing a private helper class, verify all imports of the containing file are still needed - removal can orphan imports even if the class name itself doesn't appear in an import statement.

### Pitfalls

- `fvm flutter analyze` / `fvm flutter test` blocked by classifier ("claude-sonnet-4-6 temporarily unavailable") during this session. Code was verified by manual inspection. Both commands must be run manually before merging.

---
