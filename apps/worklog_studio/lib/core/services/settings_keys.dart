/// Keys used in the `app_settings` key-value table.
///
/// Centralised here so [HotkeyService], [ReminderService], and the settings
/// screen never duplicate these strings.
abstract final class SettingsKeys {
  static const toggleHotkey = 'toggle_hotkey';
  static const acceptHotkey = 'accept_hotkey';
  static const dismissHotkey = 'dismiss_hotkey';
  static const reminderIntervalMinutes = 'reminder_interval_minutes';
}
