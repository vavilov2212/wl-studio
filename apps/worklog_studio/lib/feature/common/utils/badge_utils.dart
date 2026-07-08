import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class BadgeUtils {
  static String getProjectInitials(String name) {
    if (name.trim().isEmpty) return '--';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      final word = words[0];
      if (word.length >= 2) return word.substring(0, 2).toUpperCase();
      return word.padRight(2, word).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  static String getTaskInitials(String taskName, String projectName) {
    final t = taskName.trim().isNotEmpty ? taskName.trim()[0] : '-';
    final p = projectName.trim().isNotEmpty ? projectName.trim()[0] : '-';
    return (t + p).toUpperCase();
  }

  static int _stringHash(String s) {
    var hash = 0;
    for (var i = 0; i < s.length; i++) {
      hash = s.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return hash.abs();
  }

  static (Color, Color) getBadgeColor(String id) {
    final index = _stringHash(id) % kBadgePalette.length;
    return kBadgePalette[index];
  }
}
