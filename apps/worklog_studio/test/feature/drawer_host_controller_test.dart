// apps/worklog_studio/test/feature/drawer_host_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';

void main() {
  final entry = TimeEntry(
    id: 'e1',
    projectId: 'p1',
    taskId: 't1',
    startAt: DateTime(2026, 1, 1, 9),
    endAt: DateTime(2026, 1, 1, 10),
    status: TimeEntryStatus.stopped,
  );
  final task = Task(
    id: 't1',
    projectId: 'p1',
    title: 'Task 1',
    description: '',
    status: TaskStatus.open,
    createdAt: DateTime(2026, 1, 1),
  );
  final project = Project(
    id: 'p1',
    name: 'Project 1',
    description: '',
    createdAt: DateTime(2026, 1, 1),
    status: ProjectStatus.open,
  );

  group('DrawerHostController', () {
    test('starts closed with no entity', () {
      final controller = DrawerHostController();

      expect(controller.kind, DrawerEntityKind.none);
      expect(controller.isOpen, isFalse);
      expect(controller.timeEntry, isNull);
      expect(controller.task, isNull);
      expect(controller.project, isNull);
    });

    test('openTimeEntryEdit opens with the given entry and notifies', () {
      final controller = DrawerHostController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.openTimeEntryEdit(entry);

      expect(controller.kind, DrawerEntityKind.timeEntry);
      expect(controller.isOpen, isTrue);
      expect(controller.timeEntry, entry);
      expect(controller.task, isNull);
      expect(controller.project, isNull);
      expect(notified, isTrue);
    });

    test('openTimeEntryCreate opens with no entity', () {
      final controller = DrawerHostController();

      controller.openTimeEntryCreate();

      expect(controller.kind, DrawerEntityKind.timeEntry);
      expect(controller.isOpen, isTrue);
      expect(controller.timeEntry, isNull);
    });

    test('openTaskEdit opens with the given task', () {
      final controller = DrawerHostController();

      controller.openTaskEdit(task);

      expect(controller.kind, DrawerEntityKind.task);
      expect(controller.isOpen, isTrue);
      expect(controller.task, task);
      expect(controller.timeEntry, isNull);
    });

    test('openTaskCreate opens with no entity', () {
      final controller = DrawerHostController();

      controller.openTaskCreate();

      expect(controller.kind, DrawerEntityKind.task);
      expect(controller.isOpen, isTrue);
      expect(controller.task, isNull);
    });

    test('openProjectEdit opens with the given project', () {
      final controller = DrawerHostController();

      controller.openProjectEdit(project);

      expect(controller.kind, DrawerEntityKind.project);
      expect(controller.isOpen, isTrue);
      expect(controller.project, project);
      expect(controller.task, isNull);
    });

    test('openProjectCreate opens with no entity', () {
      final controller = DrawerHostController();

      controller.openProjectCreate();

      expect(controller.kind, DrawerEntityKind.project);
      expect(controller.isOpen, isTrue);
      expect(controller.project, isNull);
    });

    test('opening a different kind clears the previous kind entity', () {
      final controller = DrawerHostController();

      controller.openTimeEntryEdit(entry);
      controller.openTaskEdit(task);

      expect(controller.kind, DrawerEntityKind.task);
      expect(controller.timeEntry, isNull);
      expect(controller.task, task);
    });

    test('close resets to none/closed and notifies', () {
      final controller = DrawerHostController();
      controller.openProjectEdit(project);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.close();

      expect(controller.kind, DrawerEntityKind.none);
      expect(controller.isOpen, isFalse);
      expect(controller.project, isNull);
      expect(notified, isTrue);
    });
  });
}
