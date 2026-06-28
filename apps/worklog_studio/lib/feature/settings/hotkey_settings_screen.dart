import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_service.dart';
import 'package:worklog_studio/core/services/reminder_service.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';
import 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// Sentinel stored/displayed when the reminder is turned off, matching the
/// `'0'` convention [ReminderService] already uses to mean "no interval".
const _reminderOff = 0;

class HotkeySettingsScreen extends StatefulWidget {
  const HotkeySettingsScreen({super.key});

  @override
  State<HotkeySettingsScreen> createState() => _HotkeySettingsScreenState();
}

class _HotkeySettingsScreenState extends State<HotkeySettingsScreen> {
  final _settingsRepository = SqliteSettingsRepository();
  int _reminderIntervalMinutes = _reminderOff;

  /// At most one hotkey recorder listens for a keypress at a time - without
  /// this, `hotkey_manager`'s `HotKeyRecorder` would capture the same
  /// keystroke into every recorder mounted on the page simultaneously, since
  /// its listener is global rather than focus-scoped.
  String? _activeRecordingKey;

  @override
  void initState() {
    super.initState();
    _loadReminderInterval();
  }

  Future<void> _loadReminderInterval() async {
    final minutes = await _settingsRepository.getInt(SettingsKeys.reminderIntervalMinutes);
    if (!mounted) return;
    setState(() => _reminderIntervalMinutes = minutes ?? _reminderOff);
  }

  Future<void> _setReminderInterval(int? minutes) async {
    if (minutes == null) return;
    await _settingsRepository.setInt(SettingsKeys.reminderIntervalMinutes, minutes);
    if (!mounted) return;
    setState(() => _reminderIntervalMinutes = minutes);
    final service = _reminderService;
    debugPrint(
      'HotkeySettingsScreen: set reminder interval to $minutes, '
      'ReminderService resolved=${service != null}',
    );
    await service?.reloadInterval();
  }

  HotkeyService? get _hotkeyService {
    try {
      return GetIt.I<HotkeyService>();
    } catch (_) {
      return null;
    }
  }

  ReminderService? get _reminderService {
    try {
      return GetIt.I<ReminderService>();
    } catch (_) {
      return null;
    }
  }

  void _startRecording(String settingKey) {
    setState(() => _activeRecordingKey = settingKey);
  }

  void _stopRecording() {
    setState(() => _activeRecordingKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hotkeys', style: theme.commonTextStyles.displayLarge), // TODO: l10n
          SizedBox(height: theme.spacings.x2l),
          Text('Floating comment tracker', style: theme.commonTextStyles.title), // TODO: l10n
          SizedBox(height: theme.spacings.md),
          Row(
            children: [
              Text('Reminder interval: ', style: theme.commonTextStyles.body), // TODO: l10n
              SizedBox(width: theme.spacings.sm),
              SizedBox(
                width: 160,
                child: Select<int>(
                  value: _reminderIntervalMinutes,
                  minWidth: 160,
                  options: const [
                    SelectOption(value: _reminderOff, label: 'Off'), // TODO: l10n
                    SelectOption(value: 1, label: '1 minute'), // TODO: l10n
                    SelectOption(value: 2, label: '2 minutes'), // TODO: l10n
                    SelectOption(value: 5, label: '5 minutes'), // TODO: l10n
                    SelectOption(value: 10, label: '10 minutes'), // TODO: l10n
                    SelectOption(value: 30, label: '30 minutes'), // TODO: l10n
                  ],
                  onChanged: _setReminderInterval,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacings.md),
          _HotkeyRecorderRow(
            label: 'Toggle popover', // TODO: l10n
            settingKey: SettingsKeys.toggleHotkey,
            repository: _settingsRepository,
            hotkeyService: _hotkeyService,
            isRecording: _activeRecordingKey == SettingsKeys.toggleHotkey,
            onStartRecording: () => _startRecording(SettingsKeys.toggleHotkey),
            onStopRecording: _stopRecording,
          ),
          SizedBox(height: theme.spacings.sm),
          _HotkeyRecorderRow(
            label: 'Accept comment', // TODO: l10n
            settingKey: SettingsKeys.acceptHotkey,
            repository: _settingsRepository,
            hotkeyService: _hotkeyService,
            isRecording: _activeRecordingKey == SettingsKeys.acceptHotkey,
            onStartRecording: () => _startRecording(SettingsKeys.acceptHotkey),
            onStopRecording: _stopRecording,
          ),
          SizedBox(height: theme.spacings.sm),
          _HotkeyRecorderRow(
            label: 'Dismiss comment', // TODO: l10n
            settingKey: SettingsKeys.dismissHotkey,
            repository: _settingsRepository,
            hotkeyService: _hotkeyService,
            isRecording: _activeRecordingKey == SettingsKeys.dismissHotkey,
            onStartRecording: () => _startRecording(SettingsKeys.dismissHotkey),
            onStopRecording: _stopRecording,
          ),
        ],
      ),
    );
  }
}

/// A label, a readable display of the bound combo (e.g. "Ctrl + Shift + M"),
/// and a Record button.
///
/// `hotkey_manager`'s `HotKeyRecorder` listens for the next keypress
/// globally the moment it's mounted - not scoped to focus - so it is only
/// mounted while [isRecording] is true (armed by the parent, which ensures
/// at most one recorder listens at a time). The rest of the time this shows
/// a static label built from the persisted hotkey, or [HotkeyService]'s
/// documented default when nothing has been saved yet.
///
/// Persists a freshly recorded combo through [HotkeyService.saveHotkey]
/// (which re-registers all three hotkeys immediately) and falls back to
/// writing straight through [repository] when the service isn't available
/// (e.g. running on a non-Windows target).
class _HotkeyRecorderRow extends StatefulWidget {
  final String label;
  final String settingKey;
  final SqliteSettingsRepository repository;
  final HotkeyService? hotkeyService;
  final bool isRecording;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const _HotkeyRecorderRow({
    required this.label,
    required this.settingKey,
    required this.repository,
    required this.hotkeyService,
    required this.isRecording,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  @override
  State<_HotkeyRecorderRow> createState() => _HotkeyRecorderRowState();
}

class _HotkeyRecorderRowState extends State<_HotkeyRecorderRow> {
  HotKey? _displayedHotKey;

  @override
  void initState() {
    super.initState();
    _loadDisplayedHotKey();
  }

  Future<void> _loadDisplayedHotKey() async {
    final stored = await widget.repository.getString(widget.settingKey);
    if (!mounted) return;
    setState(() {
      _displayedHotKey = stored != null
          ? HotKey.fromJson(jsonDecode(stored) as Map<String, dynamic>)
          : HotkeyService.defaultHotKeyFor(widget.settingKey);
    });
  }

  Future<void> _onRecorded(HotKey hotKey) async {
    final service = widget.hotkeyService;
    if (service != null) {
      await service.saveHotkey(widget.settingKey, hotKey);
    } else {
      await widget.repository.setString(
        widget.settingKey,
        jsonEncode(hotKey.toJson()),
      );
    }
    if (!mounted) return;
    setState(() => _displayedHotKey = hotKey);
    widget.onStopRecording();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(widget.label, style: theme.commonTextStyles.body),
        ),
        SizedBox(width: theme.spacings.sm),
        if (widget.isRecording) ...[
          Expanded(
            child: Text(
              'Press a key combo...', // TODO: l10n
              style: theme.commonTextStyles.body.copyWith(
                color: theme.colorsPalette.text.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Invisible while armed - HotKeyRecorder renders nothing itself,
          // it just listens for the next keypress and reports it.
          HotKeyRecorder(onHotKeyRecorded: _onRecorded),
          PrimaryButton(
            type: ButtonType.ghost,
            size: ButtonSize.sm,
            leftIconWidget: const Icon(Icons.close, size: 16),
            onTap: widget.onStopRecording,
          ),
        ] else ...[
          Expanded(
            child: Text(
              _displayedHotKey?.debugName ?? '...',
              style: theme.commonTextStyles.body,
            ),
          ),
          PrimaryButton(
            type: ButtonType.ghost,
            size: ButtonSize.sm,
            leftIconWidget: const Icon(Icons.edit_outlined, size: 16),
            onTap: widget.onStartRecording,
          ),
        ],
      ],
    );
  }
}
