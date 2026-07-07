import 'package:injectable/injectable.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/data/sqlite/sqlite_repository_base.dart';

@LazySingleton(as: TaskRepository)
class SqliteTaskRepository extends SqliteRepositoryBase<Task>
    implements TaskRepository {
  @override
  String get tableName => 'tasks';

  @override
  Task fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      status: TaskStatus.values.firstWhere((e) => e.name == map['status']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap(Task task) {
    return {
      'id': task.id,
      'project_id': task.projectId,
      'title': task.title,
      'description': task.description,
      'status': task.status.name,
      'created_at': task.createdAt.millisecondsSinceEpoch,
      'completed_at': task.completedAt?.millisecondsSinceEpoch,
    };
  }

  // ── Task-specific queries ──────────────────────────────────────────────────

  @override
  Future<List<Task>> getByProjectId(String projectId) async {
    final d = await db;
    final rows = await d.query(
      tableName,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return rows.map(fromMap).toList();
  }
}
