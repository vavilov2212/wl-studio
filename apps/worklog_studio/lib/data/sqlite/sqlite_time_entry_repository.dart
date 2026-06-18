import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'sqlite_repository_base.dart';
import 'time_entry_mapper.dart';

class SqliteTimeEntryRepository extends SqliteRepositoryBase<TimeEntry>
    implements TimeEntryRepository {
  @override
  String get tableName => 'time_entries';

  @override
  TimeEntry fromMap(Map<String, dynamic> map) => TimeEntryMapper.fromMap(map);

  @override
  Map<String, dynamic> toMap(TimeEntry entry) => TimeEntryMapper.toMap(entry);

  // ── TimeEntry-specific queries ─────────────────────────────────────────────

  @override
  Future<List<TimeEntry>> getAll({String orderBy = 'start_at DESC'}) =>
      super.getAll(orderBy: orderBy);

  @override
  Future<TimeEntry?> getActive() async {
    final d = await db;
    final rows = await d.query(
      tableName,
      where: 'status = ?',
      whereArgs: [TimeEntryStatus.running.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return fromMap(rows.first);
  }
}
