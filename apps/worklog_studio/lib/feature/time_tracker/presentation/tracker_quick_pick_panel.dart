import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/tracker_panel_cubit.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

// ---------------------------------------------------------------------------
// Domain helpers
// ---------------------------------------------------------------------------

sealed class _ListItem {}

class _SectionHeader extends _ListItem {
  final String label;
  _SectionHeader(this.label);
}

class _ResultItem extends _ListItem {
  final Project project;
  final Task? task;
  final String? comment;
  _ResultItem({required this.project, this.task, this.comment});
}

String _comboKey(Project project, Task? task) => '${project.id}__${task?.id}';

bool _matchesQuery(_ResultItem item, String q) {
  return item.project.name.toLowerCase().contains(q) ||
      (item.task?.title.toLowerCase().contains(q) ?? false);
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class TrackerQuickPickPanel extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenTask;

  const TrackerQuickPickPanel({
    super.key,
    required this.onClose,
    required this.onOpenProject,
    required this.onOpenTask,
  });

  @override
  State<TrackerQuickPickPanel> createState() => _TrackerQuickPickPanelState();
}

class _TrackerQuickPickPanelState extends State<TrackerQuickPickPanel> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late final FocusNode _focusNode;
  int _selectedIndex = -1; // index into selectables only (not headers)

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKey);
    _searchController.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() => _selectedIndex = -1);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }

    final items = _buildItems();
    final selectables = items.whereType<_ResultItem>().toList();

    if (key == LogicalKeyboardKey.arrowDown) {
      if (selectables.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1).clamp(0, selectables.length - 1);
        });
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (selectables.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1).clamp(-1, selectables.length - 1);
        });
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < selectables.length) {
        _activateResult(selectables[_selectedIndex]);
      } else {
        _activateAsComment();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------------
  // Data building
  // -------------------------------------------------------------------------

  List<_ListItem> _buildItems() {
    final projectState = context.read<ProjectTaskState>();
    final projects = projectState.projects;
    final tasks = projectState.tasks;
    final entries = context.read<TimeTrackerBloc>().state.allEntries;
    final q = _searchController.text.toLowerCase().trim();

    if (q.isEmpty) {
      final recent = _buildRecent(entries, projects, tasks);
      final recentKeys = recent.map((r) => _comboKey(r.project, r.task)).toSet();
      final all = _buildAll(projects, tasks, excludeKeys: recentKeys);
      return [
        if (recent.isNotEmpty) ...[
          _SectionHeader('RECENTLY USED'), // TODO: l10n
          ...recent,
        ],
        if (all.isNotEmpty) ...[
          _SectionHeader('TASKS'), // TODO: l10n
          ...all,
        ],
      ];
    }

    final results = _buildAll(projects, tasks)
        .where((r) => _matchesQuery(r, q))
        .toList();
    return [
      if (results.isNotEmpty) _SectionHeader('RESULTS'), // TODO: l10n
      ...results,
    ];
  }

  List<_ResultItem> _buildRecent(
    List<TimeEntry> entries,
    List<Project> projects,
    List<Task> tasks,
  ) {
    final sorted = List.of(entries)
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    final seen = <String>{};
    final result = <_ResultItem>[];
    for (final entry in sorted) {
      if (result.length >= 5) break;
      final project =
          projects.firstWhereOrNull((p) => p.id == entry.projectId);
      if (project == null) continue;
      final task = tasks.firstWhereOrNull((t) => t.id == entry.taskId);
      final key = _comboKey(project, task);
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(_ResultItem(
        project: project,
        task: task,
        comment: (entry.comment?.isNotEmpty ?? false) ? entry.comment : null,
      ));
    }
    return result;
  }

  List<_ResultItem> _buildAll(
    List<Project> projects,
    List<Task> tasks, {
    Set<String> excludeKeys = const {},
  }) {
    final result = <_ResultItem>[];
    for (final task in tasks) {
      final project =
          projects.firstWhereOrNull((p) => p.id == task.projectId);
      if (project == null) continue;
      final key = _comboKey(project, task);
      if (excludeKeys.contains(key)) continue;
      result.add(_ResultItem(project: project, task: task));
    }
    return result;
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _activateResult(_ResultItem item) {
    final cubit = context.read<TrackerPanelCubit>();
    final isRunning = context.read<TimeTrackerBloc>().state.isRunning;
    cubit.updateProject(item.project.id, isRunning: isRunning);
    if (item.task != null) {
      cubit.updateTask(item.task!.id, isRunning: isRunning);
    }
    if (item.comment != null) {
      cubit.updateComment(item.comment!, isRunning: isRunning);
    }
    cubit.startTimer();
    widget.onClose();
  }

  void _activateAsComment() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final cubit = context.read<TrackerPanelCubit>();
    final isRunning = context.read<TimeTrackerBloc>().state.isRunning;
    cubit.updateComment(query, isRunning: isRunning);
    if (!isRunning) cubit.startTimer();
    widget.onClose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final items = _buildItems();
    final selectables = items.whereType<_ResultItem>().toList();
    final query = _searchController.text.trim();
    final hasCommentHint = query.isNotEmpty && _selectedIndex < 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.background.surface,
        border: Border(bottom: BorderSide(color: palette.border.primary)),
        boxShadow: [theme.shadows.md],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search input
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacings.x2l,
              vertical: theme.spacings.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 16, color: palette.text.muted),
                SizedBox(width: theme.spacings.sm),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search projects, tasks...', // TODO: l10n
                      hintStyle: theme.commonTextStyles.body.copyWith(
                        color: palette.text.muted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.commonTextStyles.body.copyWith(
                      color: palette.text.primary,
                    ),
                  ),
                ),
                if (query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _focusNode.requestFocus();
                    },
                    child: Icon(Icons.close, size: 14, color: palette.text.muted),
                  ),
              ],
            ),
          ),

          // Results list
          if (items.isNotEmpty) ...[
            Divider(height: 1, color: palette.border.primary),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: theme.spacings.xxs),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  if (item is _SectionHeader) {
                    return _buildHeader(item, theme, palette);
                  }
                  final result = item as _ResultItem;
                  final selectableIdx = selectables.indexOf(result);
                  final isSelected = selectableIdx == _selectedIndex;
                  return _buildResultRow(
                    result,
                    isSelected,
                    theme,
                    palette,
                  );
                },
              ),
            ),
          ],

          // Comment hint footer
          if (hasCommentHint) ...[
            Divider(height: 1, color: palette.border.primary),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacings.x2l,
                vertical: theme.spacings.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 12,
                    color: palette.text.muted,
                  ),
                  SizedBox(width: theme.spacings.xxs),
                  Text(
                    'Press Enter to start with "$query" as comment', // TODO: l10n
                    style: theme.commonTextStyles.caption.copyWith(
                      color: palette.text.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    _SectionHeader header,
    AppThemeExtension theme,
    ColorsPalette palette,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacings.x2l,
        theme.spacings.md,
        theme.spacings.x2l,
        theme.spacings.xxs,
      ),
      child: Text(
        header.label,
        style: theme.commonTextStyles.overline.copyWith(
          color: palette.text.muted,
        ),
      ),
    );
  }

  Widget _buildResultRow(
    _ResultItem result,
    bool isSelected,
    AppThemeExtension theme,
    ColorsPalette palette,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _activateResult(result),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          color: isSelected ? palette.accent.primaryMuted : Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacings.x2l,
            vertical: theme.spacings.sm,
          ),
          child: Row(
            children: [
              WsInitialBadge(
                initials: BadgeUtils.getProjectInitials(result.project.name),
                backgroundColor: BadgeUtils.getBadgeColor(result.project.id).$1,
                textColor: BadgeUtils.getBadgeColor(result.project.id).$2,
                size: WsInitialBadgeSize.small,
              ),
              SizedBox(width: theme.spacings.sm),
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: result.project.name,
                        style: theme.commonTextStyles.body2.copyWith(
                          color: palette.text.secondary,
                        ),
                      ),
                      if (result.task != null) ...[
                        TextSpan(
                          text: '  /  ',
                          style: theme.commonTextStyles.body2.copyWith(
                            color: palette.text.muted,
                          ),
                        ),
                        TextSpan(
                          text: result.task!.title,
                          style: theme.commonTextStyles.body2Bold.copyWith(
                            color: palette.text.primary,
                          ),
                        ),
                      ],
                      if (result.comment != null) ...[
                        TextSpan(
                          text: '   ·   ',
                          style: theme.commonTextStyles.body2.copyWith(
                            color: palette.text.muted,
                          ),
                        ),
                        TextSpan(
                          text: result.comment,
                          style: theme.commonTextStyles.caption.copyWith(
                            color: palette.text.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
