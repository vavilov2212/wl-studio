import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/project.dart';

class TimerSnapshot {
  final bool isRunning;
  final TimeEntry? activeEntry;
  final List<TimeEntry> entries;
  final List<Task> tasks;
  final List<Project> projects;
  final int timestamp; // Added to prevent out-of-order snapshots

  TimerSnapshot({
    required this.isRunning,
    this.activeEntry,
    required this.entries,
    required this.tasks,
    required this.projects,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'isRunning': isRunning,
      'activeEntry': _timeEntryToJson(activeEntry),
      'entries': entries.map((e) => _timeEntryToJson(e)).toList(),
      'tasks': tasks.map((t) => _taskToJson(t)).toList(),
      'projects': projects.map((p) => _projectToJson(p)).toList(),
      'timestamp': timestamp,
    };
  }

  static TimerSnapshot fromJson(Map<String, dynamic> json) {
    return TimerSnapshot(
      isRunning: json['isRunning'] ?? false,
      activeEntry: _timeEntryFromJson(json['activeEntry']),
      entries:
          (json['entries'] as List?)
              ?.map((e) => _timeEntryFromJson(e))
              .whereType<TimeEntry>()
              .toList() ??
          [],
      tasks:
          (json['tasks'] as List?)
              ?.map((t) => _taskFromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      projects:
          (json['projects'] as List?)
              ?.map((p) => _projectFromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      timestamp: json['timestamp'] ?? 0,
    );
  }

  static Map<String, dynamic>? _timeEntryToJson(TimeEntry? entry) {
    if (entry == null) return null;
    return {
      'id': entry.id,
      'projectId': entry.projectId,
      'taskId': entry.taskId,
      'comment': entry.comment,
      'startAt': entry.startAt.toIso8601String(),
      'endAt': entry.endAt?.toIso8601String(),
      'status': entry.status == TimeEntryStatus.running ? 'running' : 'stopped',
    };
  }

  static TimeEntry? _timeEntryFromJson(dynamic json) {
    if (json == null) return null;
    return TimeEntry(
      id: json['id'],
      projectId: json['projectId'],
      taskId: json['taskId'],
      comment: json['comment'],
      startAt: DateTime.parse(json['startAt']),
      endAt: json['endAt'] != null ? DateTime.parse(json['endAt']) : null,
      status: json['status'] == 'running'
          ? TimeEntryStatus.running
          : TimeEntryStatus.stopped,
    );
  }

  static Map<String, dynamic> _taskToJson(Task task) {
    return {
      'id': task.id,
      'projectId': task.projectId,
      'title': task.title,
      'description': task.description,
      'status': task.status.name,
      'createdAt': task.createdAt.toIso8601String(),
      'completedAt': task.completedAt?.toIso8601String(),
    };
  }

  static Task _taskFromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      projectId: json['projectId'],
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.open,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }

  static Map<String, dynamic> _projectToJson(Project p) {
    return {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'createdAt': p.createdAt.toIso8601String(),
      'archivedAt': p.archivedAt?.toIso8601String(),
      'status': p.status.name,
    };
  }

  static Project _projectFromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'] ?? 'Untitled',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      archivedAt: json['archivedAt'] != null
          ? DateTime.parse(json['archivedAt'])
          : null,
      status: ProjectStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ProjectStatus.open,
      ),
    );
  }
}

enum ActivityPromptSource { reminder, manual }

enum TimerActionType { start, stop, updateComment }

class TimerAction {
  final TimerActionType type;
  final String? projectId;
  final String? taskId;
  final String? comment;

  TimerAction({required this.type, this.projectId, this.taskId, this.comment});

  Map<String, dynamic> toJson() {
    return {
      'type': switch (type) {
        TimerActionType.start => 'start',
        TimerActionType.stop => 'stop',
        TimerActionType.updateComment => 'updateComment',
      },
      'projectId': projectId,
      'taskId': taskId,
      'comment': comment,
    };
  }

  static TimerAction fromJson(Map<String, dynamic> json) {
    return TimerAction(
      type: switch (json['type']) {
        'start' => TimerActionType.start,
        'updateComment' => TimerActionType.updateComment,
        _ => TimerActionType.stop,
      },
      projectId: json['projectId'],
      taskId: json['taskId'],
      comment: json['comment'],
    );
  }
}
