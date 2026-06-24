import 'package:flutter/foundation.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/drawer_controller_state.dart';

enum DrawerEntityKind { none, timeEntry, task, project }

/// Single app-level drawer state, replacing the three independent
/// per-page `DrawerControllerState<T>` instances. Only one entity (or none)
/// can be open at a time, in one of the three DrawerState modes
/// (closed/create/edit) the existing drawer widgets already understand.
class DrawerHostController extends ChangeNotifier {
  DrawerEntityKind _kind = DrawerEntityKind.none;
  DrawerState _mode = DrawerState.closed;
  Object? _entity;

  DrawerEntityKind get kind => _kind;
  bool get isOpen => _mode != DrawerState.closed;

  TimeEntry? get timeEntry =>
      _kind == DrawerEntityKind.timeEntry ? _entity as TimeEntry? : null;
  Task? get task => _kind == DrawerEntityKind.task ? _entity as Task? : null;
  Project? get project =>
      _kind == DrawerEntityKind.project ? _entity as Project? : null;

  void openTimeEntryEdit(TimeEntry entry) {
    _kind = DrawerEntityKind.timeEntry;
    _mode = DrawerState.edit;
    _entity = entry;
    notifyListeners();
  }

  void openTimeEntryCreate() {
    _kind = DrawerEntityKind.timeEntry;
    _mode = DrawerState.create;
    _entity = null;
    notifyListeners();
  }

  void openTaskEdit(Task task) {
    _kind = DrawerEntityKind.task;
    _mode = DrawerState.edit;
    _entity = task;
    notifyListeners();
  }

  void openTaskCreate() {
    _kind = DrawerEntityKind.task;
    _mode = DrawerState.create;
    _entity = null;
    notifyListeners();
  }

  void openProjectEdit(Project project) {
    _kind = DrawerEntityKind.project;
    _mode = DrawerState.edit;
    _entity = project;
    notifyListeners();
  }

  void openProjectCreate() {
    _kind = DrawerEntityKind.project;
    _mode = DrawerState.create;
    _entity = null;
    notifyListeners();
  }

  void close() {
    _kind = DrawerEntityKind.none;
    _mode = DrawerState.closed;
    _entity = null;
    notifyListeners();
  }
}
