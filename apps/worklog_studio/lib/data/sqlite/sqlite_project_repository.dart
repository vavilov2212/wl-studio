import 'package:worklog_studio/domain/project.dart';
import 'sqlite_repository_base.dart';

class SqliteProjectRepository extends SqliteRepositoryBase<Project>
    implements ProjectRepository {
  @override
  String get tableName => 'projects';

  @override
  Project fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      archivedAt: map['archived_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['archived_at'] as int)
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap(Project project) {
    return {
      'id': project.id,
      'name': project.name,
      'description': project.description,
      'created_at': project.createdAt.millisecondsSinceEpoch,
      'archived_at': project.archivedAt?.millisecondsSinceEpoch,
    };
  }
}
