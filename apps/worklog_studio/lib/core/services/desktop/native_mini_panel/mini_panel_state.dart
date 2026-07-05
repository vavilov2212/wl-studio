import 'package:flutter/foundation.dart';

/// One row in the recent-tasks list.
/// Badge colors are pre-computed by the Flutter side (via [BadgeUtils]) and
/// stored as COLORREF values (0x00BBGGRR) so the GDI painter needs no
/// Flutter imports.
@immutable
class MiniPanelEntry {
  const MiniPanelEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.projectId,
    this.taskId,
    this.comment,
    required this.badgeBg,
    required this.badgeFg,
    required this.badgeText,
  });

  final String id;
  final String title;
  final String? subtitle; // project name
  final String? projectId;
  final String? taskId;
  final String? comment;

  /// Badge background color as COLORREF (0x00BBGGRR).
  final int badgeBg;

  /// Badge foreground/text color as COLORREF.
  final int badgeFg;

  /// 1-2 character initials shown inside the badge circle.
  final String badgeText;

  @override
  bool operator ==(Object other) =>
      other is MiniPanelEntry &&
      id == other.id &&
      title == other.title &&
      subtitle == other.subtitle;

  @override
  int get hashCode => Object.hash(id, title, subtitle);
}

/// Everything [NativeMiniPanel] needs to render a frame.
///
/// Created by [WindowsDesktopService] from a [TimerSnapshot] and pushed
/// directly - no IPC round-trip, no secondary Flutter engine.
@immutable
class MiniPanelDisplayState {
  const MiniPanelDisplayState({
    this.isRunning = false,
    this.activeTitle,
    this.activeSubtitle,
    this.activeComment,
    this.timerStartAt,
    this.entries = const [],
    this.todayDuration = Duration.zero,
    this.weekDuration = Duration.zero,
  });

  final bool isRunning;
  final String? activeTitle;    // task name, or comment as fallback
  final String? activeSubtitle; // project name
  final String? activeComment;
  final DateTime? timerStartAt;
  final List<MiniPanelEntry> entries; // recent, ordered newest-first, max 10
  final Duration todayDuration;       // total tracked today (for footer)
  final Duration weekDuration;        // total tracked this week (for footer)

  static const empty = MiniPanelDisplayState();

  /// Converts a Flutter [Color] value to a Win32 COLORREF (0x00BBGGRR).
  static int colorRef(int r, int g, int b) => r | (g << 8) | (b << 16);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiniPanelDisplayState &&
          isRunning == other.isRunning &&
          activeTitle == other.activeTitle &&
          activeSubtitle == other.activeSubtitle &&
          activeComment == other.activeComment &&
          timerStartAt == other.timerStartAt &&
          todayDuration == other.todayDuration &&
          weekDuration == other.weekDuration &&
          listEquals(entries, other.entries);

  @override
  int get hashCode => Object.hash(
        isRunning,
        activeTitle,
        activeSubtitle,
        timerStartAt,
        entries.length,
        todayDuration,
        weekDuration,
      );
}
