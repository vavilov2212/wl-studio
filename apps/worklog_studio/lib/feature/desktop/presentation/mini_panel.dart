import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';

class MiniPanel extends StatefulWidget {
  const MiniPanel({super.key});

  @override
  State<MiniPanel> createState() => _MiniPanelState();
}

class _MiniPanelState extends State<MiniPanel> {
  static const _platform = MethodChannel('worklog_studio/ipc');
  bool _isVisible = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {});
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _buildActiveSession(
    bool isRunning,
    TimeEntry? activeEntry,
    MiniTrackerState state,
    AppThemeExtension theme,
    BuildContext context,
  ) {
    if (!isRunning || activeEntry == null) {
      return Row(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacings.md),
            child: Text(
              'No active session running.',
              style: theme.commonTextStyles.caption.copyWith(
                color: theme.colorsPalette.text.secondary,
              ),
            ),
          ),
        ],
      );
    }

    final task = activeEntry.taskId != null
        ? state.tasks.firstWhereOrNull(
            (t) =>
                t.id == activeEntry.taskId &&
                t.projectId == activeEntry.projectId,
          )
        : null;
    final project = activeEntry.projectId != null
        ? state.projects.firstWhereOrNull((p) => p.id == activeEntry.projectId)
        : null;

    final taskName = task?.title ?? activeEntry.comment ?? 'Running Task';
    final projectName = project?.name;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorsPalette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: Color(0xFFeaeffd)),
        boxShadow: [theme.shadows.sm],
      ),

      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacings.lg,
          vertical: theme.spacings.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACTIVE SESSION',
              style: theme.commonTextStyles.caption2Bold.copyWith(
                color: theme.colorsPalette.text.secondary2,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: theme.spacings.sm),
            Padding(
              padding: EdgeInsets.all(theme.spacings.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    taskName,
                    style: theme.commonTextStyles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (projectName != null) ...[
                    SizedBox(height: theme.spacings.xs),
                    Text(
                      projectName,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: theme.colorsPalette.text.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: theme.spacings.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _MiniActiveTimerTextWrapper(
                        entry: activeEntry,
                        style: theme.commonTextStyles.h2.copyWith(
                          color: theme.colorsPalette.text.primary,
                          fontWeight: FontWeight
                              .w500, // reduce visual weight slightly from default
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      PrimaryButton(
                        type: ButtonType.danger,
                        size: ButtonSize.sm,
                        leftIconWidget: const Icon(Icons.stop_sharp),
                        onTap: () {
                          context.read<MiniTrackerCubit>().stopTimer();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ActionGrid removed

  Widget _buildSectionHeader(
    String title,
    AppThemeExtension theme, {
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title.toUpperCase(),
          style: theme.commonTextStyles.caption2Bold.copyWith(
            color: theme.colorsPalette.text.secondary2,
            letterSpacing: 1.1,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  Widget _buildTaskItem(
    Task task,
    Project? project,
    AppThemeExtension theme,
    BuildContext context,
    bool isActive,
  ) {
    onTap() {
      context.read<MiniTrackerCubit>().startTimer(
        projectId: project?.id,
        taskId: task.id,
      );
      _searchController.clear();
      _searchFocusNode.unfocus();
      setState(() {
        _query = '';
      });
    }

    final initials = BadgeUtils.getTaskInitials(
      task.title,
      project?.name ?? '',
    );
    final colors = BadgeUtils.getBadgeColor(task.id);

    return _HoverableListItem(
      leading: WsInitialBadge(
        initials: initials,
        backgroundColor: colors.$1,
        textColor: colors.$2,
        size: WsInitialBadgeSize.small,
      ),
      title: task.title,
      subtitle: project?.name,
      trailing: isActive
          ? Container(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacings.md,
                vertical: theme.spacings.lg,
              ),
              child: Icon(
                Icons.radio_button_checked,
                size: 14,
                color: theme.colorsPalette.accent.danger,
              ),
            )
          : SizedBox.shrink(),
      trailingWidget: isActive
          ? (_) => SizedBox.shrink()
          : (isHovered) {
              return PrimaryButton(
                type: isHovered ? ButtonType.primary : ButtonType.ghost,
                initialAnimationDuration: Duration(milliseconds: 20),
                size: ButtonSize.sm,
                leftIcon: WorklogStudioAssets.vectors.playFilled24Svg,
                onTap: onTap,
              );
            },
      onTap: onTap,
    );
  }

  Widget _buildProjectItem(
    Project project,
    AppThemeExtension theme,
    BuildContext context,
  ) {
    onTap() {
      DesktopServiceRegistry.instance.openMainWindowFromTray(route: 'projects');
    }

    final initials = BadgeUtils.getProjectInitials(project.name);
    final colors = BadgeUtils.getBadgeColor(project.id);

    return _HoverableListItem(
      leading: WsInitialBadge(
        initials: initials,
        backgroundColor: colors.$1,
        textColor: colors.$2,
        size: WsInitialBadgeSize.small,
      ),
      title: project.name,
      trailingWidget: (isHovered) => PrimaryButton(
        type: isHovered ? ButtonType.primary : ButtonType.ghost,
        initialAnimationDuration: Duration(milliseconds: 20),
        size: ButtonSize.sm,
        leftIcon: WorklogStudioAssets.vectors.arrowSmallRight24Svg,
        onTap: onTap,
      ),
      onTap: onTap,
    );
  }

  Widget _buildEntryItem(
    TimeEntry entry,
    MiniTrackerState state,
    AppThemeExtension theme,
    BuildContext context, {
    int? count,
  }) {
    final task = entry.taskId != null
        ? state.tasks.firstWhereOrNull((t) => t.id == entry.taskId)
        : null;
    final project = entry.projectId != null
        ? state.projects.firstWhereOrNull((p) => p.id == entry.projectId)
        : null;
    final title = task?.title ?? entry.comment ?? 'No title';
    final isActive = state.isRunning && state.activeEntry?.id == entry.id;

    final hasCount = count != null && count > 1;
    final subtitleText = hasCount
        ? ((project != null ? '${project.name} • ' : '') + '$count entries')
        : project?.name;

    final initials = BadgeUtils.getTaskInitials(title, project?.name ?? '');
    final idForColor = task?.id ?? project?.id ?? entry.id;
    final colors = BadgeUtils.getBadgeColor(idForColor);

    onTap() {
      context.read<MiniTrackerCubit>().startTimer(
        projectId: project?.id,
        taskId: task?.id,
        comment: entry.comment,
      );
      _searchController.clear();
      _searchFocusNode.unfocus();
      setState(() {
        _query = '';
      });
    }

    return _HoverableListItem(
      leading: WsInitialBadge(
        initials: initials,
        backgroundColor: colors.$1,
        textColor: colors.$2,
        size: WsInitialBadgeSize.small,
      ),
      title: title,
      subtitle: subtitleText,
      trailing: isActive
          ? Container(
              padding: EdgeInsets.symmetric(
                vertical: context.theme.spacings.sm,
                horizontal: context.theme.spacings.md,
              ),
              child: Icon(
                Icons.radio_button_checked,
                size: 14,
                color: theme.colorsPalette.accent.danger,
              ),
            )
          : SizedBox.shrink(),
      trailingWidget: isActive
          ? (_) => SizedBox.shrink()
          : (isHovered) {
              return PrimaryButton(
                type: isHovered ? ButtonType.primary : ButtonType.ghost,
                initialAnimationDuration: Duration(milliseconds: 20),
                size: ButtonSize.sm,
                leftIcon: WorklogStudioAssets.vectors.playFilled24Svg,
                onTap: onTap,
              );
            },
      onTap: onTap,
    );
  }

  Widget _buildRecentActivity(MiniTrackerState state, AppThemeExtension theme) {
    final recentEntries = state.allEntries.where((e) => !e.isRunning).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));

    final Map<String, List<TimeEntry>> groupedEntries = {};
    if (state.isRunning && state.activeEntry != null) {
      final key = state.activeEntry!.taskId ?? state.activeEntry!.id;
      groupedEntries[key] = [state.activeEntry!];
    }
    for (final e in recentEntries) {
      final key = e.taskId ?? e.id;
      if (!groupedEntries.containsKey(key)) {
        groupedEntries[key] = [e];
      } else {
        groupedEntries[key]!.add(e);
      }
    }

    final recentGroups = groupedEntries.values.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorsPalette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: Color(0xFFeaeffd)),

        boxShadow: [theme.shadows.sm],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: theme.spacings.md,
          horizontal: theme.spacings.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'RECENT ACTIVITY',
              theme,
              trailing: InkWell(
                onTap: () {
                  DesktopServiceRegistry.instance.openMainWindowFromTray(route: 'history');
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacings.xxs,
                    vertical: theme.spacings.xs,
                  ),
                  child: Text(
                    'VIEW ALL',
                    style: theme.commonTextStyles.caption2.copyWith(
                      color: theme.colorsPalette.accent.primary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.spacings.sm),
            recentGroups.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(theme.spacings.md),
                    child: Text(
                      'No recent activity.',
                      style: theme.commonTextStyles.body.copyWith(
                        color: theme.colorsPalette.text.muted,
                      ),
                    ),
                  )
                : Column(
                    children: recentGroups.map((group) {
                      return _buildEntryItem(
                        group.first,
                        state,
                        theme,
                        context,
                        count: group.length,
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(MiniTrackerState state, AppThemeExtension theme) {
    final queryLower = _query.toLowerCase();

    final filteredTasks = state.tasks
        .where((t) => t.title.toLowerCase().contains(queryLower))
        .toList();

    final filteredProjects = state.projects
        .where((p) => p.name.toLowerCase().contains(queryLower))
        .toList();

    final filteredEntries = state.allEntries
        .where((e) => e.comment?.toLowerCase().contains(queryLower) ?? false)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filteredTasks.isEmpty &&
            filteredProjects.isEmpty &&
            filteredEntries.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: theme.spacings.md,
              horizontal: theme.spacings.md,
            ),
            child: Text(
              'No results',
              style: theme.commonTextStyles.body.copyWith(
                color: theme.colorsPalette.text.muted,
              ),
            ),
          )
        else ...[
          if (filteredTasks.isNotEmpty) ...[
            _buildSectionHeader('TASKS', theme),
            SizedBox(height: theme.spacings.xxs),
            Container(
              decoration: BoxDecoration(
                color: theme.colorsPalette.background.surface,
                borderRadius: theme.radiuses.md.circular,
                border: Border.all(color: Color(0xFFeaeffd)),
                boxShadow: [theme.shadows.sm],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: theme.spacings.md,
                  horizontal: theme.spacings.md,
                ),
                child: Column(
                  children: filteredTasks.map((task) {
                    final project = task.projectId != null
                        ? state.projects.firstWhereOrNull(
                            (p) => p.id == task.projectId,
                          )
                        : null;
                    final isActive =
                        state.isRunning && state.activeEntry?.taskId == task.id;
                    return _buildTaskItem(
                      task,
                      project,
                      theme,
                      context,
                      isActive,
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: theme.spacings.md),
          ],
          if (filteredProjects.isNotEmpty) ...[
            _buildSectionHeader('PROJECTS', theme),
            SizedBox(height: theme.spacings.xxs),
            Container(
              decoration: BoxDecoration(
                color: theme.colorsPalette.background.surface,
                borderRadius: theme.radiuses.md.circular,
                border: Border.all(color: Color(0xFFeaeffd)),
                boxShadow: [theme.shadows.sm],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: theme.spacings.md,
                  horizontal: theme.spacings.md,
                ),
                child: Column(
                  children: filteredProjects.map((project) {
                    return _buildProjectItem(project, theme, context);
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: theme.spacings.md),
          ],
          if (filteredEntries.isNotEmpty) ...[
            _buildSectionHeader('RECENT LOGS', theme),
            SizedBox(height: theme.spacings.xxs),
            Container(
              decoration: BoxDecoration(
                color: theme.colorsPalette.background.surface,
                borderRadius: theme.radiuses.md.circular,
                border: Border.all(color: Color(0xFFeaeffd)),
                boxShadow: [theme.shadows.sm],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: theme.spacings.md,
                  horizontal: theme.spacings.md,
                ),
                child: Column(
                  children: filteredEntries.map((entry) {
                    return _buildEntryItem(entry, state, theme, context);
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _formatDateHeader(DateTime date) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, ${date.day} $month';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    // Project and Entity state cannot be easily retrieved dynamically from the Cubit/IPC
    // currently unless we broadcast the whole lookup dictionary.
    // For now we will display the comment.

    return BlocBuilder<MiniTrackerCubit, MiniTrackerState>(
      builder: (context, state) {
        final isRunning = state.isRunning;
        final activeEntry = state.activeEntry;

        // Group entries by date
        final allEntries = state.allEntries.where((e) => !e.isRunning).toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));

        final groupedEntries = groupBy(allEntries, (TimeEntry e) {
          final local = e.startAt.toLocal();
          return DateTime(local.year, local.month, local.day);
        });
        final theme = context.theme;
        final palette = theme.colorsPalette;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isVisible ? 1.0 : 0.0,
          child: Container(
            margin: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Color(0xFFf8fafc),
              borderRadius: BorderRadius.circular(theme.spacings.md),
              boxShadow: [theme.shadows.md],
              border: Border.all(
                color: palette.border.primary.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.spacings.md),

              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,

                      border: Border.all(color: Color(0xFFebf0fd)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacings.lg,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Worklog Studio',
                            style: theme.commonTextStyles.captionSemiBold,
                          ),
                          Expanded(flex: 1, child: const SizedBox.shrink()),
                          PrimaryButton(
                            type: ButtonType.ghost,
                            size: ButtonSize.sm,
                            leftIcon: WorklogStudioAssets.vectors.plus24Svg,
                            onTap: () {},
                          ),
                          SizedBox(width: theme.spacings.xxs),
                          PrimaryButton(
                            type: ButtonType.ghost,
                            size: ButtonSize.sm,
                            leftIconWidget: const Icon(
                              Icons.desktop_windows,
                              size: 16,
                            ),
                            onTap: () {
                              DesktopServiceRegistry.instance.openMainWindowFromTray();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: theme.spacings.lg),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacings.lg,
                    ),
                    child: PrimaryInput(
                      label: null,
                      focusNode: _searchFocusNode,
                      controller: _searchController,
                      hintText: 'Search or start a task…',
                      autofocus: true,
                      suffixWidget:
                          (_searchFocusNode.hasFocus || _query.isNotEmpty)
                          ? MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: theme.colorsPalette.text.secondary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.search,
                              size: 16,
                              color: theme.colorsPalette.text.muted,
                            ),
                      onChanged: (value) {
                        setState(() {
                          _query = value.trim();
                        });
                      },
                    ),
                  ),
                  SizedBox(height: theme.spacings.lg),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: Color(0xFFf8fafc)),
                      child: _query.isEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.spacings.lg,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildActiveSession(
                                    isRunning,
                                    activeEntry,
                                    state,
                                    theme,
                                    context,
                                  ),
                                  SizedBox(height: theme.spacings.lg),
                                  _buildRecentActivity(state, theme),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacings.lg,
                                ),
                                child: _buildSearchResults(state, theme),
                              ),
                            ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorsPalette.accent.primaryMuted,
                      border: Border.all(color: Color(0xFFeaeffd)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacings.lg,
                        vertical: theme.spacings.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Today 06h 15m   |   Total 24h 30m',
                            style: theme.commonTextStyles.caption.copyWith(
                              color: theme.colorsPalette.text.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniActiveTimerTextWrapper extends StatefulWidget {
  final TimeEntry? entry;
  final TextStyle? style;

  const _MiniActiveTimerTextWrapper({required this.entry, this.style});

  @override
  State<_MiniActiveTimerTextWrapper> createState() =>
      _MiniActiveTimerTextWrapperState();
}

class _MiniActiveTimerTextWrapperState
    extends State<_MiniActiveTimerTextWrapper> {
  late Stream<int> _timerStream;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _recalc();
    _timerStream = Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  void _recalc() {
    if (widget.entry != null) {
      final now = DateTime.now();
      _seconds = now.difference(widget.entry!.startAt).inSeconds;
    } else {
      _seconds = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _MiniActiveTimerTextWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recalc();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entry == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: _timerStream,
      builder: (context, snapshot) {
        _recalc(); // Recalc each second
        final duration = Duration(seconds: _seconds);
        String twoDigits(int n) => n.toString().padLeft(2, "0");
        String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
        String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
        final formatted =
            "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";

        return Text(
          formatted,
          style:
              widget.style ??
              context.theme.commonTextStyles.captionBold.copyWith(
                color: context.theme.colorsPalette.text.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        );
      },
    );
  }
}

class _HoverableListItem extends StatefulWidget {
  final Widget? leading;
  final Widget Function(bool isHovered)? leadingWidget;
  final String title;
  final String? subtitle;
  final Widget Function(bool isHovered)? trailingWidget;
  final Widget? trailing;
  final VoidCallback onTap;

  const _HoverableListItem({
    super.key,
    this.leading,
    this.leadingWidget,
    required this.title,
    this.subtitle,
    this.trailingWidget,
    this.trailing,
    required this.onTap,
  });

  @override
  State<_HoverableListItem> createState() => _HoverableListItemState();
}

class _HoverableListItemState extends State<_HoverableListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: theme.spacings.sm,
            horizontal: theme.spacings.md,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorsPalette.accent.primaryMuted
                : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.radiuses.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              widget.leading ?? SizedBox.shrink(),
              widget.leadingWidget?.call(_isHovered) ?? SizedBox.shrink(),
              (widget.leading == null && widget.leadingWidget == null)
                  ? SizedBox.shrink()
                  : SizedBox(width: theme.spacings.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.commonTextStyles.body.copyWith(
                        color: theme.colorsPalette.text.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null) ...[
                      SizedBox(height: theme.spacings.xs),
                      Text(
                        widget.subtitle!,
                        style: theme.commonTextStyles.caption.copyWith(
                          color: theme.colorsPalette.text.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: theme.spacings.sm),
              widget.trailing ?? SizedBox.shrink(),
              widget.trailingWidget?.call(_isHovered) ?? SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
