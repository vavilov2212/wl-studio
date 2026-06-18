import 'package:intl/intl.dart';

class DateFormatUtils {
  /// Format rules:
  /// Case A — Same Day: 17:59 → 20:14
  /// Case B — Different Days: Aug 12, 17:59 → Aug 14, 14:43
  static String formatTimeRangeWithDate(DateTime start, DateTime? end) {
    if (end == null) {
      return '${DateFormat('HH:mm:ss').format(start)} → ...';
    }

    final isSameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (isSameDay) {
      return '${DateFormat('HH:mm:ss').format(start)} → ${DateFormat('HH:mm:ss').format(end)}';
    }

    // Different days
    final startFormat = DateFormat('MMM d, HH:mm:ss').format(start);
    final endFormat = DateFormat('MMM d, HH:mm:ss').format(end);

    return '$startFormat → $endFormat';
  }
}
