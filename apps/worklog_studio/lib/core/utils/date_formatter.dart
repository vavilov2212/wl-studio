import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  /// `HH:mm:ss` — live timers and per-entry duration display.
  static String formatDurationHms(Duration duration) {
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(duration.inHours)}:${dd(duration.inMinutes.remainder(60))}:${dd(duration.inSeconds.remainder(60))}';
  }

  /// `Xh Ym` — grouped / summary durations in history and charts.
  static String formatDurationHm(Duration duration) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  /// "Today · Jan 7", "Yesterday · Jan 7", or bare "Jan 7".
  static String formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${months[date.month - 1]} ${date.day}';
    if (target == today) return 'Today · $dateStr';
    if (target == yesterday) return 'Yesterday · $dateStr';
    return dateStr;
  }

  /// `12:00 AM` / `01:30 PM` — 12-hour clock with leading zero and AM/PM suffix.
  static String formatTime12h(DateTime time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// `HH:mm` — 24-hour clock without seconds, used in task entry time ranges.
  static String formatTimeHhMm(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Same-day: `HH:mm:ss → HH:mm:ss`. Cross-day: `MMM d, HH:mm:ss → MMM d, HH:mm:ss`.
  /// Running entry (end is null): `HH:mm:ss → ...`.
  static String formatTimeRange(DateTime start, DateTime? end) {
    if (end == null) {
      return '${DateFormat('HH:mm:ss').format(start)} → ...';
    }
    final isSameDay = start.year == end.year && start.month == end.month && start.day == end.day;
    if (isSameDay) {
      return '${DateFormat('HH:mm:ss').format(start)} → ${DateFormat('HH:mm:ss').format(end)}';
    }
    return '${DateFormat('MMM d, HH:mm:ss').format(start)} → ${DateFormat('MMM d, HH:mm:ss').format(end)}';
  }
}
