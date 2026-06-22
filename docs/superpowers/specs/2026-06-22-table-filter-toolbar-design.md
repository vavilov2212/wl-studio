# Notion-like filter toolbar for table pages

## Goal

History, Projects, and Tasks pages each render data through the shared
`WsTable<T>` component but have no way to filter rows. Add a Notion-style
toolbar (filter / sort / settings) above each table, with sort and settings
disabled for now, and working filters scoped per page.

## Scope

- History page (`feature/history/presentation/history_page.dart`)
- Tasks page (`feature/tasks/presentation/tasks_page.dart`)
- Projects page (`feature/projects/presentation/projects_page.dart`)
- New reusable ui-kit primitives in `packages/worklog_studio_style_system`
- Pure, unit-tested filter-predicate functions per page

Out of scope: sort functionality, table view-mode settings (grouped vs flat),
server-side/persisted filter state, filtering on the cards view (filters
apply only to data shown, regardless of cards/table toggle — both view modes
read from the same filtered list).

## Per-page filter sets

Each page declares a fixed, page-relevant filter set (no generic "add filter"
flow, since fields are fixed per page):

| Page     | Filters                                   | Matched field(s) |
|----------|--------------------------------------------|-------------------|
| History  | Task, Project, Date range                  | `task.id`, `project.id`, `entry.startAt` |
| Tasks    | Project, Status, Date range                | `task.projectId`, `task.status`, `task.createdAt` |
| Projects | Status, Date range                         | `project.status`, `project.createdAt` |

Status options reuse the existing `TaskStatus`/`ProjectStatus` enums
(open/done/archived). Task/Project options are derived from the currently
resolved entities (via `EntityResolver`), not a separate fetch.

## Architecture

### New ui-kit primitives (`packages/worklog_studio_style_system/lib/ui_kit/src/`)

**`MultiSelect<T>`** — new widget, sibling to the existing `Select<T>`
(`select/select.dart`). The existing `Select` widget declares a
`SelectMode.multi` enum value but never implements it — selection is single,
and the popover closes immediately on pick. Rather than retrofitting `Select`
(risking existing single-select usages elsewhere in the app), add a parallel
`MultiSelect<T>`:

- Controlled `List<T> value` / `ValueChanged<List<T>> onChanged`.
- Reuses `SelectOption<T>` for option data, `Combobox` + `PopoverPrimitive`
  for positioning/overlay behavior (already generic, no changes needed).
- Content list renders checkbox-style rows; tapping a row toggles membership
  in `value` and keeps the popover open (unlike `Select`, which closes after
  one pick).
- Trigger shows placeholder when empty, otherwise a compact summary (e.g.
  "2 selected"); exact trigger rendering is overridable via `triggerBuilder`
  like `Select`.
- This becomes the shared multi-select primitive for Task/Project/Status
  filtering, and is intended for reuse elsewhere in the app beyond this
  feature.

**`DateRangeButton`** — new widget. Pill-style trigger + popover containing:
- Preset rows: Today, This week, This month, All time.
- A "Custom range" row that opens Flutter's built-in `showDateRangePicker`.
- Controlled `DateTimeRange? value` / `ValueChanged<DateTimeRange?> onChanged`.
- `onChanged(null)` represents "All time" / cleared.

**Toolbar icon row** — no new widget required. `PrimaryButton` already
supports icon-only rendering (`title: null`, `leftIconWidget`) and a disabled
state (`isDisabled` / `onTap: null`), so Filter/Sort/Settings icons are three
`PrimaryButton(type: ButtonType.ghost, ...)` instances. Filter is the only
one wired to a callback; Sort and Settings render permanently disabled.

### Per-page filter bars (not shared — filter sets differ per page)

New small components, one per page, in that page's existing `components/`
folder:
- `feature/history/presentation/components/history_filter_bar.dart`
- `feature/tasks/presentation/components/tasks_filter_bar.dart`
- `feature/projects/presentation/components/projects_filter_bar.dart`

Each renders the page's fixed set of pills using `MultiSelect`/
`DateRangeButton`, and is a plain stateless widget driven by
controlled value + onChanged callbacks (no internal filter state).

### Filter value classes + pure predicate functions

For each page, an immutable filter-state class and a pure filter function,
colocated with that page's domain logic concerns and unit-tested under
`apps/worklog_studio/test/core/`:

```dart
// History
class HistoryFilters {
  final Set<String> taskIds;
  final Set<String> projectIds;
  final DateTimeRange? dateRange;
  const HistoryFilters({
    this.taskIds = const {},
    this.projectIds = const {},
    this.dateRange,
  });
  bool get isActive => taskIds.isNotEmpty || projectIds.isNotEmpty || dateRange != null;
  int get activeCount => (taskIds.isNotEmpty ? 1 : 0) + (projectIds.isNotEmpty ? 1 : 0) + (dateRange != null ? 1 : 0);
}

List<ResolvedTimeEntry> applyHistoryFilters(
  List<ResolvedTimeEntry> entries,
  HistoryFilters filters,
) { ... }
```

Equivalent `TasksFilters`/`applyTasksFilters` and
`ProjectsFilters`/`applyProjectsFilters` follow the same shape. Per the
mandatory TDD workflow in `apps/worklog_studio/CLAUDE.md`, each predicate
function is written test-first (failing test → minimal implementation →
refactor under green) before being wired into the page widget.

`activeCount` drives the badge shown on the toolbar's Filter icon.

## UX / state behavior

**Layout per page** — the toolbar gets its own row, directly above the
table, separate from the existing title row:

- History: Title row → KPI strip → **toolbar row** (+ pill row when
  expanded) → table
- Tasks / Projects: Title row → **toolbar row** (+ pill row when expanded)
  → table

**Toggling:** Clicking the Filter icon toggles visibility of the pill row
beneath the toolbar. Collapsed by default. The Filter icon shows a small
active-count badge whenever `filters.activeCount > 0`, regardless of whether
the pill row is currently expanded or collapsed, so active filters are never
silently hidden.

**Pills:** All of a page's filters render as pills at once when the row is
expanded — no "add filter" step, since the set is fixed per page. Each pill:
- Shows its field name as a muted placeholder when empty ("Task", "Project",
  "Date").
- Shows a compact summary when set ("2 tasks", "Mar 1 – Mar 14").
- Has an inline "×" to clear just that pill.

A "Reset all" affordance appears in the row when `activeCount > 0`.

**Filtering scope:** Filtering is pure client-side over the already-resolved
in-memory lists (`resolvedEntries` / `resolvedTasks` / `resolvedProjects`).
No data-layer or repository changes. Filtered lists feed both the cards view
and the table view identically — the cards/table `SegmentedToggle` only
changes presentation, not the underlying filtered data.

**State ownership:** Each page's existing `StatefulWidget`
(`_HistoryScreenState`, `_TasksScreenState`, `_ProjectsScreenState`) gains a
`_filters` field of that page's filter-state class, alongside the existing
`_viewMode`/`_drawerState`. The filter bar is a controlled child — it
receives `filters` and an `onChanged` callback, with no internal filter
state of its own.

**Sort / Settings:** Rendered disabled (no `onTap`, muted icon styling).
Pure placeholders — no behavior wired, per current request. Settings is
intended to later host view-mode configuration (e.g. grouped-by-date vs.
flat table), but that is explicitly out of scope here.

**Empty state:** If a filter combination produces zero rows, the existing
empty-state pattern for that page's list is reused (whichever the page
already shows for "no data"), with the toolbar and expanded pill row still
visible so the user can adjust filters without losing context.

## Testing

- Pure filter-predicate functions (`applyHistoryFilters`,
  `applyTasksFilters`, `applyProjectsFilters`) get unit tests in
  `apps/worklog_studio/test/core/`, written test-first per the TDD mandate:
  empty filters return all rows; each filter dimension in isolation; multiple
  filters combined (AND across dimensions, OR within a multi-select
  dimension); date range boundaries (inclusive start/end).
- `MultiSelect<T>` and `DateRangeButton` are UI-only ui-kit components —
  exempt from the mandatory unit-test rule per the TDD policy, but should be
  manually verified in the running app (open/close, multi-pick retains
  popover open, preset selection, custom range round-trip).
- Manual verification in the running app: toggle filter row, set/clear each
  pill type per page, confirm table and cards both reflect the filtered set,
  confirm badge count matches active filters, confirm Sort/Settings remain
  inert.
