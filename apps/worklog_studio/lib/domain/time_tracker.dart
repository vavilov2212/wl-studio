import 'package:worklog_studio/domain/time_entry.dart';

abstract class TimeEntryRepository {
  Future<TimeEntry?> getActive();
  Future<List<TimeEntry>> getAll();
  Future<void> insert(TimeEntry entry);
  Future<void> update(TimeEntry entry);
  Future<void> delete(String id);
}

abstract class Clock {
  DateTime now();
}
