import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar.dart';
import 'package:worklog_studio/feature/app/layout/scaffold/app_scaffold.dart';
import 'package:worklog_studio/feature/work_log/presentation/work_log_raw_data_scope.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/active_timer_text.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';

class WelcomeLayout extends StatefulWidget {
  const WelcomeLayout({super.key});

  @override
  State<WelcomeLayout> createState() => WelcomeLayoutState();
}

class WelcomeLayoutState extends State<WelcomeLayout> {
  final _textController = TextEditingController();
  final popoverController = PopoverController();
  @override
  void initState() {
    final state = context.read<TimeTrackerBloc>().state;
    _textController.text = state.activeEntryOrNull?.comment ?? '';
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimeTrackerBloc, TimeTrackerBlocState>(
      listenWhen: (previous, current) =>
          previous.activeEntryOrNull?.comment !=
          current.activeEntryOrNull?.comment,
      listener: (context, state) {
        final comment = state.activeEntryOrNull?.comment ?? '';
        if (_textController.text != comment) {
          _textController.text = comment;
        }
      },
      child: BlocBuilder<TimeTrackerBloc, TimeTrackerBlocState>(
        buildWhen: (previous, current) =>
            previous.isRunning != current.isRunning ||
            previous.activeEntryOrNull != current.activeEntryOrNull ||
            !const ListEquality().equals(
              previous.allEntries,
              current.allEntries,
            ),
        builder: (context, _state) {
          final isRunning = _state.isRunning;
          final activeEntry = _state.activeEntryOrNull;
          final entries = _state.allEntries;
          final bloc = context.read<TimeTrackerBloc>();

          return AppBarProvider(
            config: AppBarConfig(
              title: Text(AppEnvironment.instance().config.flavor.appTitle),
            ),

            child: AppScaffold(
              body: Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.green),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Status
                                Text(
                                  isRunning ? 'RUNNING' : 'STOPPED',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),

                                const SizedBox(height: 16),

                                // Elapsed
                                ActiveTimerText(
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displayMedium,
                                ),

                                const SizedBox(height: 32),

                                // Controls
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      onPressed: isRunning
                                          ? null
                                          : () async {
                                              context
                                                  .read<TimeTrackerBloc>()
                                                  .add(TimeTrackerStarted());
                                            },
                                      child: const Text('Start'),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      onPressed: isRunning
                                          ? () async {
                                              context
                                                  .read<TimeTrackerBloc>()
                                                  .add(TimeTrackerStopped());
                                            }
                                          : null,
                                      child: const Text('Stop'),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 32),

                                Row(
                                  spacing: context.theme.spacings.lg,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    PopoverPrimitive(
                                      controller: popoverController,
                                      onRequestClose: popoverController.hide,
                                      width: 520,
                                      trigger: PrimaryButton(
                                        type: ButtonType.secondary,
                                        title: 'Comment',
                                        onTap: popoverController.toggle,
                                      ),
                                      contentBuilder: (context) {
                                        return PopoverSurface(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              TextArea(
                                                hintText: 'hintText',
                                                controller: _textController,
                                              ),
                                              PrimaryButton(
                                                title: 'Save',
                                                onTap: () {
                                                  bloc.add(
                                                    TimeTrackerActiveEntryUpdated(
                                                      comment:
                                                          _textController.text,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    SizedBox(
                                      width: 200,
                                      child: Consumer<ProjectTaskState>(
                                        builder: (context, projectTaskState, child) {
                                          return Select<String>(
                                            onChanged: (value) => bloc.add(
                                              TimeTrackerActiveEntryUpdated(
                                                projectId: value,
                                              ),
                                            ),
                                            searchable: true,
                                            placeholder: 'Select project',
                                            value: activeEntry?.projectId,
                                            options: projectTaskState.projects.map((
                                              p,
                                            ) {
                                              final initials =
                                                  BadgeUtils.getProjectInitials(
                                                    p.name,
                                                  );
                                              final colors =
                                                  BadgeUtils.getBadgeColor(
                                                    p.id,
                                                  );
                                              return SelectOption(
                                                value: p.id,
                                                label: p.name,
                                                leading: WsInitialBadge(
                                                  initials: initials,
                                                  backgroundColor: colors.$1,
                                                  textColor: colors.$2,
                                                  size:
                                                      WsInitialBadgeSize.small,
                                                ),
                                              );
                                            }).toList(),
                                            actionBuilder: (context, query, close) {
                                              final exactMatchExists =
                                                  projectTaskState.projects.any(
                                                    (p) =>
                                                        p.name.toLowerCase() ==
                                                        query.toLowerCase(),
                                                  );
                                              if (exactMatchExists &&
                                                  query.isNotEmpty)
                                                return const SizedBox.shrink();

                                              return SelectCreateAction(
                                                label: query.isEmpty
                                                    ? 'Create new project'
                                                    : 'Create project "$query"',
                                                onTap: () async {
                                                  final newProject =
                                                      await projectTaskState
                                                          .createProject(
                                                            query.isEmpty
                                                                ? 'New project'
                                                                : query,
                                                            '',
                                                          );
                                                  bloc.add(
                                                    TimeTrackerActiveEntryUpdated(
                                                      projectId: newProject.id,
                                                    ),
                                                  );
                                                  close();
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),

                                    SizedBox(
                                      width: 200,
                                      child: Consumer<ProjectTaskState>(
                                        builder: (context, projectTaskState, child) {
                                          return Select<String>(
                                            onChanged: (value) => bloc.add(
                                              TimeTrackerActiveEntryUpdated(
                                                taskId: value,
                                              ),
                                            ),
                                            searchable: true,
                                            placeholder: 'Select task',
                                            value: activeEntry?.taskId,
                                            options: projectTaskState.tasks.map(
                                              (t) {
                                                final project = projectTaskState
                                                    .projects
                                                    .firstWhere(
                                                      (p) =>
                                                          p.id == t.projectId,
                                                    );
                                                final initials =
                                                    BadgeUtils.getTaskInitials(
                                                      t.title,
                                                      project.name,
                                                    );
                                                final colors =
                                                    BadgeUtils.getBadgeColor(
                                                      t.id,
                                                    );
                                                return SelectOption(
                                                  value: t.id,
                                                  label: t.title,
                                                  leading: WsInitialBadge(
                                                    initials: initials,
                                                    backgroundColor: colors.$1,
                                                    textColor: colors.$2,
                                                    size: WsInitialBadgeSize
                                                        .small,
                                                  ),
                                                );
                                              },
                                            ).toList(),
                                            actionBuilder: (context, query, close) {
                                              final exactMatchExists =
                                                  projectTaskState.tasks.any(
                                                    (t) =>
                                                        t.title.toLowerCase() ==
                                                        query.toLowerCase(),
                                                  );
                                              if (exactMatchExists &&
                                                  query.isNotEmpty)
                                                return const SizedBox.shrink();

                                              return SelectCreateAction(
                                                label: query.isEmpty
                                                    ? 'Create new task'
                                                    : 'Create task "$query"',
                                                onTap: () async {
                                                  close();
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: PrimaryButton(
                                onTap: () {
                                  WorkLogRawDataScope.load(context);
                                },
                                title: 'Выбрать сессию',
                              ),
                            ),
                          ),
                          Text('entries.length ${entries.length}'),
                          Expanded(
                            child: entries.isNotEmpty
                                ? ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemBuilder: (context, index) {
                                      final entry = entries[index];
                                      return Container(
                                        decoration: BoxDecoration(
                                          border: BoxBorder.all(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(8),
                                          ),
                                          color: index != index
                                              ? Colors.red
                                              : Colors.blue,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Project: ${entry.projectId}',
                                                ),
                                                Text('Task: ${entry.taskId}'),
                                                Text(
                                                  'Started at: ${entry.startAt}',
                                                ),
                                                Text('Status: ${entry.status}'),
                                                Text(
                                                  'Comment: ${entry.comment}',
                                                ),
                                                entry.endAt != null
                                                    ? Text(
                                                        'Duration: ${_formatDuration(entry.endAt!.difference(entry.startAt!))}',
                                                      )
                                                    : SizedBox.shrink(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    separatorBuilder: (context, _) =>
                                        SizedBox(height: 12),
                                    itemCount: entries.length,
                                  )
                                : Text('Empty'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}
