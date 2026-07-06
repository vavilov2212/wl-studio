# Worklog Studio UI Kit Reference

Read this file first on any UI task. It covers every public component, all design tokens, and the theme architecture so you do not need to crawl the source files to answer "does this component exist?" or "what props does it take?".

---

## Theme Architecture

The style system exposes two entry points:

- `AppTheme.lightThemeData` / `AppTheme.darkThemeData` - hand to `MaterialApp.theme`.
- `AppThemeExtension` - the custom `ThemeExtension` that carries all design tokens. Access it anywhere via the `BuildContextExtension`:

```dart
context.theme              // AppThemeExtension
context.theme.colorsPalette
context.theme.spacings
context.theme.radiuses
context.theme.commonTextStyles
context.theme.shadows
context.theme.gradients
context.theme.controlSize(ControlSize.sm)
```

Font family: `Inter` (body), `NunitoSans` (headings).

---

## Design Tokens

### Colors - `context.theme.colorsPalette`

| Group | Token | Purpose |
|-------|-------|---------|
| `background.canvas` | `#F5F4F1` | Page/app background |
| `background.surface` | `#FFFFFF` | Card, input, popover background |
| `background.surfaceMuted` | `#EEECEE` | Subtle fill, disabled bg |
| `border.primary` | `#E2E0DB` | Default border |
| `border.hover` | `#BBCADE` | Hover border |
| `border.focus` | `#2563EB` | Focus ring |
| `text.primary` | `#1C1E21` | Main text |
| `text.secondary` | `#4B5563` | Supporting text |
| `text.secondary2` | `#5E6774` | Tertiary text |
| `text.muted` | `#9CA3AF` | Placeholder, disabled text |
| `accent.primary` | `#185FA5` | Brand blue, CTA |
| `accent.primaryMuted` | `#E6F1FB` | Blue tinted fill |
| `accent.danger` | `#DC2626` | Error/destructive |
| `accent.success` | `#16A34A` | Success |
| `accent.warning` | `#F59E0B` | Warning |
| `accent.nav` | `#0C447C` | Sidebar/nav dark blue |
| `base.transparent` | transparent | Explicit transparent |

> Dark theme tokens are defined but currently share the same values as light (dark mode not fully implemented yet).

### Spacing - `context.theme.spacings`

| Token | Value |
|-------|-------|
| `xs` | 2 |
| `xxs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 24 |
| `x2l` | 32 |
| `x3l` | 40 |
| `x4l` | 48 |
| `x5l` | 64 |
| `x6l` | 80 |

### Border Radius - `context.theme.radiuses`

| Token | Value | Use |
|-------|-------|-----|
| `sm` | 6 | Buttons, badges, small chips |
| `md` | 10 | Inputs, cards, popovers |
| `lg` | 16 | Large containers |
| `pill` | 999 | Pill-shaped elements |

Helper extension: `someDouble.circular` returns `BorderRadius.circular(someDouble)`.

### Shadows - `context.theme.shadows`

| Token | Description |
|-------|-------------|
| `none` | Transparent, zero blur |
| `sm` | Subtle: `0 1 2 rgba(0,0,0,0.03)` |
| `md` | Elevated: `0 4 12 rgba(0,0,0,0.07)` |

### Gradients - `context.theme.gradients`

| Token | Direction | Colors |
|-------|-----------|--------|
| `primaryHorizontal` | left to right | `#7A38FF` to `#3471FE` |
| `primaryVertical` | top to bottom | same |
| `primaryVerticalReverse` | bottom to top | same |

### Typography - `context.theme.commonTextStyles`

| Token | Font | Size | Weight | Use |
|-------|------|------|--------|-----|
| `displayLarge` | NunitoSans | 32 | 700 | Hero numbers |
| `h1` | NunitoSans | 25 | 700 | Page titles |
| `h2` | NunitoSans | 23 | 800 | Section headings |
| `h3` | NunitoSans | 20 | 700 | Sub-headings |
| `title` | NunitoSans | 20 | 600 | Panel titles |
| `subtitle` | NunitoSans | 18 | 600 | Card headers |
| `body` | Inter | 16 | 400 | Default body |
| `body2` | Inter | 14 | 400 | Dense body |
| `bodyBold` | Inter | 16 | 700 | Emphasized body |
| `body2Bold` | Inter | 14 | 700 | Emphasized dense |
| `caption` | Inter | 13 | 400 | Labels, hints |
| `captionBold` | Inter | 13 | 700 | |
| `captionSemiBold` | Inter | 13 | 600 | |
| `caption2` | Inter | 10 | 400 | Micro text |
| `caption2Bold` | Inter | 10 | 700 | Badge labels |
| `caption3` | Inter | 8 | 400 | Tiny labels |
| `caption3Bold` | Inter | 8 | 700 | |
| `overline` | Inter | 11 | 700 | Uppercase section labels (2.64 tracking) |
| `labelMedium` | Inter | 13 | 500 | |
| `labelSmall` | Inter | 11 | 500 | Table headers |
| `buttonL` | Inter | 18 | 600 | Large button |
| `buttonM` | Inter | 16 | 600 | Medium button |
| `buttonS` | Inter | 14 | 600 | Small button |

### Control Sizes - `ControlSize` enum + `context.theme.controlSize(size)`

`ControlSize` is shared by inputs, selects, buttons. Values: `xs`, `sm` (default for most controls), `md`, `lg`.

`context.theme.controlSize(size)` returns `ControlSizeTokens` with: `height`, `horizontalPadding`, `verticalPadding`, `allPadding`, `textStyle`, `iconSize`, `isDense`, `contentPadding`.

| Size | Height | Use |
|------|--------|-----|
| `xs` | 32 | Compact inline controls |
| `sm` | 40 | Standard form controls |
| `md` | 48 | Prominent controls |
| `lg` | 52 | Hero CTAs |

---

## Components

### PrimaryButton

Interactive button with hover/active/loading states.

```dart
PrimaryButton(
  onTap: () {},
  title: 'Save',
  type: ButtonType.primary,  // primary | secondary | danger | success | warning | ghost
  size: ButtonSize.md,       // xs | sm | md | lg
  isLoading: false,
  isDisabled: false,
  leftIcon: 'assets/...',    // SVG asset path (optional)
  leftIconWidget: Icon(...), // Widget alternative (optional)
  rightIcon: ...,
  rightIconWidget: ...,
  backgroundColor: ...,      // override
  foregroundColor: ...,      // override
)
```

- `primary`: blue fill, gradient, sm shadow, white text.
- `secondary`: muted fill, border, blue text.
- `ghost`: transparent, darkens on hover.
- `danger`/`success`/`warning`: semantic fill colors.
- Shows a rotating spinner when `isLoading: true`.

---

### PrimaryInput

Single-line text input with label, hint, prefix/suffix slots, and state variants.

```dart
PrimaryInput(
  label: 'Name',
  hintText: 'Enter name...',
  controller: _controller,
  focusNode: ...,            // optional
  description: 'Help text', // optional, shown below
  prefixWidget: Icon(...),   // optional
  suffixWidget: ...,         // optional
  state: InputState.enabled, // enabled | warning | error | disabled
  variant: InputVariant.outline, // outline | ghost
  size: ControlSize.sm,
  keyboardType: TextInputType.text,
  maxLength: 100,
  showCounter: false,
  onChanged: (v) {},
  onSubmitted: (v) {},
)
```

---

### TextArea

Vertically resizable multi-line input. User can drag bottom edge to resize.

```dart
TextArea(
  hintText: 'Description...',
  controller: _controller,
  label: 'Notes',          // optional
  maxLines: 5,             // display rows; expands freely
  maxLength: 3000,
  showCounter: false,
  hasError: false,
  size: ControlSize.sm,
  onChanged: (v) {},
  focusNode: ...,
)
```

---

### Select

Dropdown select, controlled or uncontrolled, with optional search.

```dart
Select<String>(
  options: [SelectOption(value: 'a', label: 'Option A')],
  value: _value,           // controlled; omit for uncontrolled
  defaultValue: 'a',       // uncontrolled initial value
  onChanged: (v) {},
  placeholder: 'Select...',
  searchable: false,
  enabled: true,
  size: ControlSize.sm,
  variant: SelectVariant.outline, // outline (only variant currently)
  matchTriggerWidth: true,
  minWidth: 240,
  triggerBuilder: ...,     // custom trigger widget (optional)
  actionBuilder: ...,      // custom action row at list top (optional)
  emptyBuilder: ...,       // custom empty state (optional)
  autoOpen: false,
  onOpenChange: (isOpen) {},
  controller: ...,         // external ComboboxController (optional)
  tapRegionGroupId: ...,
)
```

`SelectOption<T>`: `SelectOption(value: T, label: String)`.

---

### MultiSelect

Same API as `Select` but holds `List<T>` and shows checkboxes.

```dart
MultiSelect<String>(
  options: [...],
  value: _selectedList,
  onChanged: (list) {},
  placeholder: 'Select options...',
  searchable: false,
  size: ControlSize.sm,
  matchTriggerWidth: true,
  minWidth: 240,
  triggerBuilder: ...,
  controller: ...,
  tapRegionGroupId: ...,
)
```

---

### DateRangeButton

Preset date-range picker (Today / This week / This month / All time / Custom range). Opens a `CalendarPicker` for custom ranges.

```dart
DateRangeButton(
  value: _range,           // DateTimeRange? — null = "All time"
  onChanged: (range) {},   // DateTimeRange?
  placeholder: 'Date',
  size: ControlSize.sm,
)
```

---

### CalendarPicker

Standalone range calendar. Allows picking start+end dates.

```dart
CalendarPicker(
  selectedRange: _range,    // DateTimeRange?
  onRangeSelected: (range) {},
)
```

---

### Combobox

Low-level primitive that powers `Select`, `MultiSelect`, and `DateRangeButton`. Use it directly only when you need a fully custom trigger+content pair.

```dart
Combobox(
  controller: ...,           // ComboboxController (optional)
  triggerBuilder: (context, open, isOpen) => MyTrigger(),
  contentBuilder: (context, close) => MyContent(),
  enabled: true,
  offset: Offset(0, 4),
  matchTriggerWidth: false,
  minWidth: 240,
  tapRegionGroupId: ...,
)
```

`ComboboxController`: `open()`, `close()`, `toggle()`, `isOpen`.

---

### BaseCard

Generic surface container with border, shadow, and rounded corners.

```dart
BaseCard(
  child: ...,
  backgroundColor: ...,   // defaults to surface
  borderColor: ...,        // defaults to border.primary @40%
  boxShadow: [...],        // defaults to shadows.sm
  padding: ...,            // defaults to spacings.lg all sides
  borderRadius: ...,       // defaults to radiuses.md
)
```

---

### MasterListCard

Row-style list item card with title, optional metadata line, and optional trailing widget. Tappable.

```dart
MasterListCard(
  title: 'Project Alpha',
  metadata: '3 tasks',    // optional subtitle
  trailing: StatusBadge(...), // optional
  accentColor: Colors.blue,   // optional left border accent
  onTap: () {},
)
```

---

### MetricCard

KPI/stat tile with a label, value widget, optional icon, and optional accent (blue) variant.

```dart
MetricCard(
  label: 'Total hours',
  value: Text('42h'),
  icon: Icons.timer,   // optional
  accent: false,       // true = blue tinted background
)
```

---

### StatusBadge

Pill badge with semantic status color. Collapses to a dot when space is too narrow.

```dart
StatusBadge(
  status: BadgeStatus.inProgress,  // ready | inProgress | needsReview | done | urgent | logged | active
  label: 'In Progress',
  size: BadgeSize.md,              // sm | md
)
```

---

### InfoBar

Horizontal alert/notification bar with leading icon, title, optional description, and optional action widget.

```dart
InfoBar(
  variant: InfoBarVariant.info,    // info | success | warning | danger
  style: InfoBarStyle.filled,      // filled | outline
  leading: Icon(Icons.info),       // optional
  title: Text('Message'),
  description: Text('Details'),    // optional
  actions: TextLink(...),          // optional
)
```

---

### LabeledDivider

Pill label followed by a horizontal rule. Used as a section separator.

```dart
LabeledDivider(label: 'Today')
```

---

### SidebarItem

Navigation row for the sidebar. Supports expanded and icon-only collapsed modes.

```dart
SidebarItem(
  label: 'Projects',
  iconPath: WorklogStudioAssets.vectors.someIcon, // SVG path (optional)
  icon: Icons.folder,                              // IconData alternative
  isActive: false,
  collapsed: false,          // icon-only mode with tooltip
  indent: 0,                 // extra left indent for nested items
  variant: SidebarItemVariant.standard, // standard | nested
  trailing: ChevronIcon(),   // optional, expanded mode only
  onTap: () {},
)
```

Always renders on a dark navigation background (`accent.nav`). Active item uses `accent.primary` fill in standard mode.

---

### SegmentedToggle

Icon-only segmented control for switching between view modes.

```dart
SegmentedToggle<ViewMode>(
  options: [
    SegmentedToggleOption(value: ViewMode.list, icon: Icons.list),
    SegmentedToggleOption(value: ViewMode.grid, icon: Icons.grid_view),
  ],
  value: _mode,
  onChanged: (v) {},
)
```

---

### WsTable

Data table with typed columns, hover/select states, and header row.

```dart
WsTable<Project>(
  columns: [
    WsTableColumn(
      title: 'Name',
      builder: (ctx, item, isHovered) => Text(item.name),
      flex: 2,
      fixedWidth: null,      // optional fixed px width
      alignment: Alignment.centerLeft,
    ),
  ],
  data: _projects,
  showHeader: true,
  selectedItem: _selected,
  onRowTap: (item) {},
  isSelected: (item, sel) => item.id == sel?.id, // custom equality (optional)
  rowKeyBuilder: (item) => ValueKey(item.id),    // optional
)
```

---

### TableToolbar

Filter + sort + settings icon row, typically placed above a `WsTable`.

```dart
TableToolbar(
  isFilterExpanded: _filterOpen,
  onFilterTap: () {},
  activeFilterCount: 2,        // badge on filter icon
  isSortExpanded: _sortOpen,
  onSortTap: () {},            // null disables sort button
  mainAxisAlignment: MainAxisAlignment.end,
)
```

---

### ClearableFilterPill

Wraps any filter control (e.g., `Select`, `DateRangeButton`) and overlays a close button when active.

```dart
ClearableFilterPill(
  isActive: _hasFilter,
  onClear: () {},
  child: Select(...),
)
```

---

### TextLink

Inline hyperlink-style text that darkens on hover.

```dart
TextLink(
  label: 'View details',
  onTap: () {},
  style: ...,       // optional TextStyle override; defaults to bodyBold
  color: ...,       // optional color override; defaults to accent.primary
  maxLines: 1,
)
```

---

### Popover primitives

Use these only when building custom overlay controls outside of `Combobox`.

- `PopoverController`: `show()`, `hide()`, `isVisible`.
- `PopoverPrimitive`: low-level overlay anchor. Takes `trigger`, `contentBuilder`, `controller`, `offset`, `matchTriggerWidth`, `minWidth`, `tapRegionGroupId`.
- `PopoverSurface`: styled popover container (white bg, border, md shadow, md radius).

---

### Drawer system

Slide-in panel anchored to the right edge of a layout.

Key classes:
- `DrawerService`: singleton service. Call `DrawerService.open(context, builder)` / `DrawerService.close(context)`.
- `DrawerLayer`: place this in the widget tree (above the content that should be overlaid) to host drawers.
- `DrawerConstraints`: `maxWidth`, `minWidth` for the drawer panel.
- `BaseDrawer`: the styled drawer shell - header, scrollable content, optional footer. Pass your content as `child`.

---

## Assets

Access generated asset paths via `WorklogStudioAssets` (exported from barrel):

```dart
WorklogStudioAssets.vectors.someIcon  // SVG path string
WorklogStudioAssets.images.somePng    // image path
```

SVG rendering uses the `vector_svg` package. Extension method on `String`:
```dart
'path/to/icon.svg'.vector(width: 20, height: 20, colorFilter: myColor.filter)
```

`Color.filter` is an extension that converts a `Color` to a `ColorFilter` for tinting SVGs.
