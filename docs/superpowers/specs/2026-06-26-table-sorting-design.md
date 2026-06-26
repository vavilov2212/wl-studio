# Table Sorting Design

## Problem

History, Tasks, and Projects tables have no interactive sorting. History and the Home "recent activity" widget apply a hardcoded sort (latest-first by `startAt`, running entries pinned to top); Tasks and Projects apply no sort at all (provider order). The shared `TableToolbar` widget (`packages\worklog_studio_style_system\lib\ui_kit\src\table\table_toolbar.dart`) already has a sort icon button, but it's wired `enabled: false` (a placeholder).

## Scope

Add interactive sorting to:
- History (`apps\worklog_studio\lib\feature\history\presentation\history_page.dart`)
- Tasks (`apps\worklog_studio\lib\feature\tasks\presentation\tasks_page.dart`)
- Projects (`apps\worklog_studio\lib\feature\projects\presentation\projects_page.dart`)

Home's "recent activity" widget is explicitly out of scope (top-10 recent list, not worth sorting controls).

## Domain model

Per page, a sort field enum and a shared direction enum:

```dart
enum SortDirection { asc, desc }

enum HistorySortField { date, duration, taskProjectName }
enum TasksSortField { name, timeTracked }
enum ProjectsSortField { name, timeTracked }
```

Each page gets a pure `applyXSort(List<ResolvedX> items, XSortField field, SortDirection direction) -> List<ResolvedX>`, following the existing `applyXFilters` pattern (e.g. `applyHistoryFilters` in `domain/history_filters.dart`). These are pure functions and must have unit tests in `apps\worklog_studio\test\core\` per the TDD rule in `apps\worklog_studio\CLAUDE.md`.

## State (`PageUiPreferences`)

Session-scoped only (in-memory, lost on restart — matches the existing doc comment on the class). Add per page, mirroring the existing filter-expanded-override pattern:

```dart
HistorySortField _historySortField = HistorySortField.date;
SortDirection _historySortDirection = SortDirection.desc;
bool? _historySortExpandedOverride;
// + matching getters and setX setters, notifyListeners() on each

TasksSortField _tasksSortField = TasksSortField.name;
SortDirection _tasksSortDirection = SortDirection.asc;
bool? _tasksSortExpandedOverride;

ProjectsSortField _projectsSortField = ProjectsSortField.name;
SortDirection _projectsSortDirection = SortDirection.asc;
bool? _projectsSortExpandedOverride;
```

## UI

### TableToolbar

Enable the existing disabled sort icon (`table_toolbar.dart:32`). Add `isSortExpanded` and `onSortTap` props, mirroring the existing `isFilterExpanded`/`onFilterTap`. The icon becomes an active/inactive toggle button identical in style to the filter icon.

### Per-page sort bar

Each page gets an `XSortBar` widget (e.g. `HistorySortBar`) next to the existing `XFilterBar` component, shown inline below the toolbar when expanded (same expand/collapse mechanics as the filter bar — not a popover). Contents: one selectable chip per sortable field, plus a single asc/desc direction toggle button. Tapping a field chip makes it active; tapping the direction toggle (or the active chip again) flips direction. Reuses existing pill/chip components from the style system.

Sortable fields:
- History: Date (default, desc), Duration, Task & Project name
- Tasks: Name (default, asc), Time tracked
- Projects: Name (default, asc), Time tracked

### History-specific behavior

History currently groups entries under per-date headers, sorted desc, with running entries pinned to the top of the whole list (`history_page.dart:131-156`).

- When sort field = Date: keep current behavior exactly. The asc/desc toggle flips the order of the date groups (and the order of entries within a day). Running entries stay pinned to the top of the list.
- When sort field = Duration or Task & Project name: drop date-group headers entirely; render one flat sorted list. Running entries are NOT specially pinned in this mode — they sort by their current value like any other row.

Tasks and Projects have no existing grouping, so their sort just reorders the flat list directly.

## Defaults

| Page | Default field | Default direction |
|---|---|---|
| History | Date | desc (latest first — preserves current behavior) |
| Tasks | Name | asc |
| Projects | Name | asc |

Sort bar expand/collapse state resets each session, same as the filter bar.

## Out of scope

- Persisting sort choice across app restarts.
- Sorting on the Home "recent activity" widget.
- Clickable column headers (the existing single sort-icon-button UX is kept, not replaced).
