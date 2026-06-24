import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_drawer.dart';
import 'package:worklog_studio/feature/projects/presentation/components/project_drawer.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/tasks_drawer.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';

/// Single drawer instance shared by History/Tasks/Projects, driven by
/// [DrawerHostController] instead of each page owning its own drawer.
/// Mounted once at the AppShell level so it survives page disposal.
class AppDrawerHost extends StatelessWidget {
  const AppDrawerHost({super.key});

  @override
  Widget build(BuildContext context) {
    final drawer = context.watch<DrawerHostController>();

    switch (drawer.kind) {
      case DrawerEntityKind.timeEntry:
        final entry = drawer.timeEntry;
        final resolvedEntry = entry == null
            ? null
            : context
                .watch<EntityResolver>()
                .getResolvedTimeEntries()
                .firstWhereOrNull((e) => e.entry.id == entry.id);
        return TimeEntryDrawer(
          resolvedEntry: resolvedEntry,
          isOpen: drawer.isOpen,
          onClose: drawer.close,
        );
      case DrawerEntityKind.task:
        return TaskDrawer(
          task: drawer.task,
          isOpen: drawer.isOpen,
          onClose: drawer.close,
        );
      case DrawerEntityKind.project:
        return ProjectDrawer(
          project: drawer.project,
          isOpen: drawer.isOpen,
          onClose: drawer.close,
        );
      case DrawerEntityKind.none:
        return const SizedBox.shrink();
    }
  }
}
