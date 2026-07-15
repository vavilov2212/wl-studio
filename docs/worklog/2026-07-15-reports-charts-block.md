# Work Journal: Reports Charts Block (2026-07-15)

Plan: `docs/superpowers/plans/2026-07-15-reports-charts-block.md`
Spec: `docs/superpowers/specs/2026-07-15-reports-charts-block-design.md`
Protocol: Run -> Log -> Distill -> Repeat; one task per step, user approval between tasks.

---

## Task 1: Move DashboardChartView enum to dashboard_chart_aggregator.dart

1. **[Verified Facts]** Task 1 done, commit `deff358`. Changed:
   `lib\feature\home\dashboard_chart_aggregator.dart` (enum added after
   `DashboardPeriod`), `lib\feature\home\bloc\dashboard_charts_bloc.dart` (enum
   removed). Grep confirms exactly one `enum DashboardChartView` declaration in
   `lib\`. `fvm flutter analyze lib\feature\home` - No issues found.
   `fvm flutter test test/feature/home/ --reporter expanded` - 20/20 passed.
2. **[What Worked]** Zero-import-change move: every consumer (bloc part-files,
   charts section, home tests) already imported `dashboard_chart_aggregator.dart`
   for `DashboardPeriod`, exactly as predicted during planning by checking imports
   before editing.
3. **[Distilled Rules]** `DashboardChartView` is now importable ONLY from
   `package:worklog_studio/feature/home/dashboard_chart_aggregator.dart`; Tasks 5
   and 6 must import it from there, never from the bloc file. Bash tool working
   dir persists between calls: after `cd apps/worklog_studio` stay put or use
   absolute paths.
4. **[Pitfalls & What to Avoid]** A `test/feature/home/dashboard_charts_section_test.dart`
   widget test EXISTS (plan/POST_MORTEM claimed reports/home widget coverage was
   absent for the section - it is present for the dashboard section). It passed
   untouched, but Task 6/7 conventions can mirror its harness if reports widget
   tests are ever added. Also: second `cd apps/worklog_studio` in a new Bash call
   failed (already inside); use absolute paths.
5. **[What's Next]** Task 2: extract `chartScale` into
   `lib\feature\common\utils\chart_scale.dart` (TDD: failing test
   `test\core\chart_scale_test.dart` first). No prerequisites; independent of
   Task 1.

---

## Task 2: Extract chartScale into feature/common/utils/chart_scale.dart

1. **[Verified Facts]** Task 2 done, commit `833b739`. Created
   `lib\feature\common\utils\chart_scale.dart` (public `chartScale`, verbatim
   move) and `test\core\chart_scale_test.dart` (4 tests);
   `dashboard_charts_section.dart` now imports the util, private `_chartScale`
   deleted. Red state evidenced by IDE missing-URI errors on the test; green run
   4/4; `fvm flutter analyze lib\feature\home lib\feature\common\utils` - No
   issues found; full suite `test/core/ test/feature/` - 299/299 passed
   (295 pre-existing + 4 new).
2. **[What Worked]** Verbatim function move + import + call rename in three
   parallel edits; record-type equality (`(interval: ..., maxY: ...)`) asserts
   both fields in one `expect`.
3. **[Distilled Rules]** Run tests from `apps\worklog_studio\` - the Bash tool
   cwd resets between calls, so every test/analyze command starts with
   `cd /d/work/wl_studio/apps/worklog_studio &&`. Tasks 6/7 must import
   `package:worklog_studio/feature/common/utils/chart_scale.dart`.
4. **[Pitfalls & What to Avoid]** Post-edit IDE diagnostics arrive PER EDIT, so
   they show broken intermediate states of multi-edit batches (unused import,
   undefined `_chartScale`) - trust `fvm flutter analyze` (pitfall 3.3), which
   came back clean. A first `fvm flutter test` run from the repo root failed with
   "Does not exist" because the shell cwd had reset to root - re-run from the app
   dir.
5. **[What's Next]** Task 3: `byTask` slices in `ReportsAggregator` (TDD: extend
   `test\core\reports_aggregator_test.dart`). No prerequisites.

---

## Task 3: byTask slices in ReportsAggregator

1. **[Verified Facts]** Task 3 done, commit `8e664a5`. Changed
   `lib\feature\reports\reports_aggregator.dart` (`ReportsData.byTask` +
   required ctor param; flat accumulators in the entry loop; sorted slice build)
   and `test\core\reports_aggregator_test.dart` (+2 tests). Red state evidenced
   by `undefined_getter byTask` diagnostics; green run: 9/9 in the aggregator
   test file.
2. **[What Worked]** Reusing the single entry loop for the flat accumulators
   (no second pass); the byProject sentinel-last sort comparator copied verbatim
   for byTask.
3. **[Distilled Rules]** `ReportsData` construction sites are ONLY inside
   `aggregate()` - adding a required field needs exactly one call-site update.
   Task 4 adds `bars` the same way and passes `byProject` into the bucket
   builder for segment ordering.
4. **[Pitfalls & What to Avoid]** None; per-edit intermediate diagnostics
   (missing required arg, unused locals) again resolved after the full batch.
5. **[What's Next]** Task 4: stacked `bars` in `ReportsAggregator` (requires
   Task 3, done). TDD: 4 new tests (week/today/month/custom).

---

## Task 4: Stacked per-project bar buckets in ReportsAggregator

1. **[Verified Facts]** Task 4 done, commit `b9c74fa`. Changed
   `reports_aggregator.dart` (models `ReportsBarSegment`/`ReportsBar`,
   `ReportsData.bars`, `_buildBars` + `_barsFromBuckets` generic +
   `_hourlyBars`/`_dailyBars`/`_weeklyBars`, `_weekdayLabels` const) and
   `reports_aggregator_test.dart` (+4 tests). Red: `undefined_getter bars`;
   green: 13/13 in the aggregator test file.
2. **[What Worked]** One generic `_barsFromBuckets(bucketCount, labelOf,
   bucketIndexOf, ...)` instead of three copies of the dashboard's separate
   bucket loops - passing `byProject` in gives stable segment ordering for free
   via `.where().map()` over the already-sorted slices.
3. **[Distilled Rules]** Segment order in every bar == `byProject` order
   (duration desc, No Project last); zero-duration segments are omitted, so
   `bar.segments.isEmpty` is the "nothing logged in this bucket" signal Task 7
   uses to suppress the overlay. Bucketing math is intentionally identical to
   `DashboardChartAggregator._buildBuckets` (same deliberate duplication as the
   range logic, POST_MORTEM 1.9).
4. **[Pitfalls & What to Avoid]** None new; the `_weekdayLabels`-unused warning
   mid-batch disappeared once `_dailyBars` landed in the same batch.
5. **[What's Next]** Task 5: `view` field in `ReportsBloc` + `ReportsViewChanged`
   event + hand-edit of `reports_bloc.freezed.dart` (requires Task 1, done).

---

## Task 5: Chart view state in ReportsBloc (hand-edited freezed)

1. **[Verified Facts]** Task 5 done, commit `5489f65`. Changed
   `reports_state.dart` (`@Default(DashboardChartView.donut) view`),
   `reports_event.dart` (`ReportsViewChanged`), `reports_bloc.dart`
   (handler `_onViewChanged`), `reports_bloc.freezed.dart` (11 hand edits),
   `reports_bloc_test.dart` (+3 tests). Red: `undefined_getter view` /
   `undefined_function ReportsViewChanged`; green: 12/12 bloc tests;
   `fvm flutter analyze lib\feature\reports` - No issues found.
2. **[What Worked]** Threading a field through a hand-written freezed file via
   `replace_all: true` on shared substrings: ==/hashCode/toString/copyWith
   signatures/copyWith param lists/copyWith bodies/patterns-extension signatures
   and call args are TEXTUALLY IDENTICAL between the mixin and `_ReportsState`
   (and between both CopyWithImpls), so 8 of 11 edits hit both places at once.
   Only the getters line, the `_ReportsState` constructor, and the field
   declaration needed unique single edits.
3. **[Distilled Rules]** For `@Default` fields the freezed pattern is:
   constructor `this.view = DashboardChartView.donut`, field declared
   `@override@JsonKey() final  DashboardChartView view;` (with `@JsonKey()`),
   copyWith uses `Object? view = null` + `null == view` (non-nullable field
   style), and `view` slots between `anchorDate` and `customRangeStart`
   everywhere - copied from `dashboard_charts_bloc.freezed.dart`.
4. **[Pitfalls & What to Avoid]** Per-edit IDE diagnostics during the batch
   looked alarming (invalid_override, missing concrete getter) but described
   intermediate states only; final `flutter analyze` is the arbiter
   (pitfall 3.3).
5. **[What's Next]** Task 6: rewrite `reports_summary_panel.dart` (BaseCard,
   toggle, total column, two donuts, static stacked bar) + page wiring
   (requires Tasks 1-5, all done).

---

## Task 6: Charts card UI (donuts, toggle, static stacked bar, page wiring)

1. **[Verified Facts]** Task 6 done, commit `d87bb55`. Rewrote
   `reports_summary_panel.dart` (BaseCard root; `_TotalColumn`; `_DonutContent`
   with Project + Task donuts; `_BarContent`; static `_ReportsStackedBarChart`
   via `rodStackItems`; SegmentedToggle top-right, hidden + donut forced when
   `period == custom`) and wired `reports_page.dart` (passes
   `view`/`period`/`onViewChanged` dispatching `ReportsViewChanged`).
   `fvm flutter analyze lib\feature\reports` - No issues found; full suite
   308/308 passed. UI-only task, no unit tests per TDD exemption.
2. **[What Worked]** Stacked rods: accumulate `from`/`to` per segment into
   `BarChartRodStackItem`s and set the rod's `toY` to the final `from` (the
   running total) - no separate total-to-hours computation needed. Panel kept
   dumb (props + callback), page owns the bloc dispatch.
3. **[Distilled Rules]** Donut/legend geometry literals (180/40/45/2, dot 8,
   label maxWidth 140) intentionally mirror the Dashboard and are the accepted
   token exception (POST_MORTEM 4.2). Colors ONLY via inline ternary
   `id.isEmpty ? palette.text.muted : BadgeUtils.getBadgeColor(id).$2`
   (pitfall 3.18 - no ColorsPalette-typed helpers).
4. **[Pitfalls & What to Avoid]** The page-level diagnostics fired
   `missing_required_argument` for the panel between the Write (panel) and Edit
   (page) - batch-order artifact, resolved by the wiring edit; analyze is clean.
5. **[What's Next]** Task 7: replace `_ReportsStackedBarChart` with the stateful
   hover version + `_BarLegendOverlay` (requires Task 6, done).

---

## Task 7: Hover legend overlay for the stacked bar chart

1. **[Verified Facts]** Task 7 done, commit `500459c`. Replaced
   `_ReportsStackedBarChart` (now StatefulWidget: MouseRegion hover index,
   Stack + Positioned overlay, `backDrawRodData` highlight, bold accent bottom
   label on hover) and added `_BarLegendOverlay` (bucket label + bold total +
   per-project rows) plus `_kLeftReservedSize` const. `fvm flutter analyze
   lib\feature\reports` - No issues found; full suite 308/308 passed.
2. **[What Worked]** Whole-class replacement in ONE edit (pitfall 3.5 - no
   orphaned fragments); hover math copied from Dashboard `_BarChart` (zone =
   chartAreaWidth / n, offset by the reserved Y-axis width); overlay wrapped in
   `IgnorePointer` so it never flickers its own hover; `segments.isEmpty` guard
   suppresses the overlay on empty buckets.
3. **[Distilled Rules]** Overlay positioning: prefer barCenterX + 24, flip left
   near the right edge, clamp to [0, width - overlayWidth]; overlay width is a
   fixed 200 to keep the math simple. `_kLeftReservedSize` must equal
   `SideTitles.reservedSize` (36) or hover zones drift.
4. **[Pitfalls & What to Avoid]** Adding the shared const BEFORE the widget
   that uses it produces a transient `unused_element` warning - harmless within
   one task, but the two edits must land in the same task/commit.
5. **[What's Next]** Task 8: final verification (analyze all touched paths +
   full suite) and POST_MORTEM session entry (requires Tasks 1-7, done).

---

## Task 8: Final verification and POST_MORTEM entry

1. **[Verified Facts]** Task 8 done. `fvm flutter analyze lib\feature\reports
   lib\feature\home lib\feature\common\utils` - No issues found;
   `fvm flutter test test/core/ test/feature/ --reporter expanded` - 308/308
   passed (295 pre-existing + 4 chart_scale + 6 aggregator + 3 bloc).
   POST_MORTEM.md updated: header state line, new section 1.10 (enum location,
   chartScale util, aggregator additions, dumb-panel contract, hover overlay
   pattern, freezed hand-edit recipe), 4.2 session block (widget-test gap,
   new magic numbers, view not persisted).
2. **[What Worked]** The whole plan executed without a single failed
   verification: every red state was a compile error exactly where the plan
   predicted, every green run passed on the first try after implementation.
3. **[Distilled Rules]** All standing rules from this session are now in
   POST_MORTEM 1.10/4.2 - this journal is session history only.
4. **[Pitfalls & What to Avoid]** None on this task.
5. **[What's Next]** Plan complete (8/8 tasks). No follow-up tasks pending.
