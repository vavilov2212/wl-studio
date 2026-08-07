import 'package:worklog_studio/domain/resolved_time_entry.dart';

/// A group of one or more consecutive [ResolvedTimeEntry]s that share the
/// same taskId and projectId.  When [entries.length == 1] this is a plain
/// entry; when > 1 it is a collapsible "stack".
class TimeEntryStack {
  final List<ResolvedTimeEntry> entries;

  const TimeEntryStack(this.entries)
      : assert(entries.length > 0, 'Stack must have at least one entry');

  bool get isSingle => entries.length == 1;
  bool get isStack => entries.length > 1;
  int get count => entries.length;

  /// First entry in the list - used as the representative for display.
  ResolvedTimeEntry get representative => entries.first;

  /// Stable identity for the group (join of all entry ids).
  String get id => entries.map((e) => e.id).join('-');

  bool get isRunning => entries.any((e) => e.isRunning);

  Duration totalDuration(DateTime now) =>
      entries.fold(Duration.zero, (d, e) => d + e.duration(now));

  /// Earliest start time across all entries.
  DateTime get startAt =>
      entries.map((e) => e.startAt).reduce((a, b) => a.isBefore(b) ? a : b);

  /// Latest end time, or null if any entry is still running.
  DateTime? get endAt {
    if (entries.any((e) => e.endAt == null)) return null;
    return entries
        .map((e) => e.endAt!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

/// Collapses consecutive entries that share the same taskId + projectId into
/// [TimeEntryStack] groups.  The order of [entries] is preserved - only
/// adjacent identical-identity entries are merged.
List<TimeEntryStack> groupConsecutiveEntries(List<ResolvedTimeEntry> entries) {
  if (entries.isEmpty) return const [];

  final groups = <TimeEntryStack>[];
  final current = <ResolvedTimeEntry>[entries.first];

  for (var i = 1; i < entries.length; i++) {
    final prev = current.last;
    final curr = entries[i];

    if (prev.taskId == curr.taskId && prev.projectId == curr.projectId) {
      current.add(curr);
    } else {
      groups.add(TimeEntryStack(List.unmodifiable(current)));
      current
        ..clear()
        ..add(curr);
    }
  }
  groups.add(TimeEntryStack(List.unmodifiable(current)));

  return groups;
}
