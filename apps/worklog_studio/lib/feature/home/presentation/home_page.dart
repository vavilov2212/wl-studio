import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/tasks_card.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_card.dart';

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardHeader(),
          SizedBox(height: theme.spacings.x2l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: const _DailyFocusCard()),
              SizedBox(width: theme.spacings.xl),
              Expanded(child: const _WeeklyEarningsCard()),
            ],
          ),
          SizedBox(height: theme.spacings.x2l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: const _TopTasksSection()),
              SizedBox(width: theme.spacings.xl),
              Expanded(flex: 4, child: const _RecentActivitySection()),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard', style: theme.commonTextStyles.displayLarge),
            SizedBox(height: theme.spacings.xxs),
            Text(
              'Welcome back. Here\'s your workflow for today.',
              style: theme.commonTextStyles.body.copyWith(
                color: palette.text.secondary,
              ),
            ),
          ],
        ),
        PrimaryButton(
          title: 'Add Time Entry',
          onTap: () {
            context.read<TimeTrackerBloc>().add(TimeTrackerStarted());
          },
        ),
      ],
    );
  }
}

class _DailyFocusCard extends StatelessWidget {
  const _DailyFocusCard();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    // Use granular selectors to minimize rebuilds
    final allEntries = context.select(
      (TimeTrackerBloc bloc) => bloc.state.allEntries,
    );
    final isRunning = context.select(
      (TimeTrackerBloc bloc) => bloc.state.isRunning,
    );

    // Calculate total time for today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayEntries = allEntries.where((e) {
      final start = DateTime(e.startAt.year, e.startAt.month, e.startAt.day);
      return start == today;
    });

    final totalDuration = todayEntries.fold<Duration>(
      Duration.zero,
      (prev, entry) => prev + entry.duration(now),
    );

    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final timeString = '${hours}h ${minutes}m';

    return Container(
      padding: EdgeInsets.all(theme.spacings.xl),
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.lg.circular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily Focus', style: theme.commonTextStyles.title),
              if (isRunning)
                const StatusBadge(
                  status: BadgeStatus.inProgress,
                  label: 'ACTIVE',
                ),
            ],
          ),
          SizedBox(height: theme.spacings.x2l),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timeString, style: theme.commonTextStyles.h2),
                  Text(
                    'LOGGED TODAY',
                    style: theme.commonTextStyles.caption3Bold.copyWith(
                      color: palette.text.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyEarningsCard extends StatelessWidget {
  const _WeeklyEarningsCard();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      padding: EdgeInsets.all(theme.spacings.xl),
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.lg.circular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Earnings', style: theme.commonTextStyles.title),
                  Text(
                    'Coming Soon',
                    style: theme.commonTextStyles.body2.copyWith(
                      color: palette.text.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: theme.spacings.x2l),
          Text(
            'Financial tracking features will be available in a future update.',
            style: theme.commonTextStyles.body.copyWith(
              color: palette.text.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTasksSection extends StatelessWidget {
  const _TopTasksSection();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Selector<EntityResolver, List<ResolvedTask>>(
      selector: (context, resolver) => resolver.getResolvedTasks(),
      shouldRebuild: (prev, next) => !const ListEquality().equals(prev, next),
      builder: (context, topTasks, child) {
        final now = DateTime.now();

        // Sort tasks by duration and take top 5
        final sortedTasks = List.of(topTasks)
          ..sort((a, b) {
            return b.duration(now).compareTo(a.duration(now));
          });

        final displayTasks = sortedTasks.take(5).toList();

        return Container(
          padding: EdgeInsets.all(theme.spacings.xl),
          decoration: BoxDecoration(
            color: palette.background.surfaceMuted,
            borderRadius: theme.radiuses.lg.circular,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Top Tasks', style: theme.commonTextStyles.h3),
                  Text(
                    'View All',
                    style: theme.commonTextStyles.bodyBold.copyWith(
                      color: palette.accent.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacings.xl),
              if (displayTasks.isEmpty)
                Text(
                  'No tasks tracked yet.',
                  style: theme.commonTextStyles.body.copyWith(
                    color: palette.text.muted,
                  ),
                )
              else
                Column(
                  spacing: theme.spacings.lg,
                  children: displayTasks.map((resolvedTask) {
                    return TaskCard(
                      task: resolvedTask,
                      isSelected: false,
                      onTap: () {},
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Selector<EntityResolver, List<ResolvedTimeEntry>>(
      selector: (context, resolver) => resolver.getResolvedTimeEntries(),
      shouldRebuild: (prev, next) => !const ListEquality().equals(prev, next),
      builder: (context, resolvedEntries, child) {
        final sortedEntries = List.of(resolvedEntries)
          ..sort((a, b) {
            if (a.isRunning && !b.isRunning) return -1;
            if (!a.isRunning && b.isRunning) return 1;
            return b.startAt.compareTo(a.startAt);
          });

        final recentEntries = sortedEntries.take(5).toList();

        return Container(
          padding: EdgeInsets.all(theme.spacings.xl),
          decoration: BoxDecoration(
            color: palette.background.surface,
            borderRadius: theme.radiuses.lg.circular,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent Activity', style: theme.commonTextStyles.h3),
              SizedBox(height: theme.spacings.xl),
              if (recentEntries.isEmpty)
                Text(
                  'No recent activity.',
                  style: theme.commonTextStyles.body.copyWith(
                    color: palette.text.muted,
                  ),
                )
              else
                Column(
                  spacing: theme.spacings.md,
                  children: recentEntries.map((resolvedEntry) {
                    return TimeEntryCard(
                      resolvedEntry: resolvedEntry,
                      isSelected: false,
                      onTap: () {},
                    );
                  }).toList(),
                ),
              SizedBox(height: theme.spacings.lg),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  title: 'View All History',
                  type: ButtonType.ghost,
                  onTap: () {},
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
