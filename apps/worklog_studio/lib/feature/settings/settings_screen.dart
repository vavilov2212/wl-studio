import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:worklog_studio/core/services/backup_service.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_service.dart';
import 'package:worklog_studio/core/services/desktop/reveal_in_file_manager.dart';
import 'package:worklog_studio/core/services/reminder_service.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';
import 'package:worklog_studio/core/sparkle/sparkle_bridge.dart';
import 'package:worklog_studio/data/sqlite/database_provider.dart';
import 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart';
import 'package:worklog_studio/domain/backup.dart';
import 'package:worklog_studio_style_system/theme/theme_extension/app_theme_extension.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBackingUp = false;
  String? _dbDirPath;
  String? _backupsDirPath;
  final _settingsRepository = SqliteSettingsRepository();
  int? _reminderIntervalMinutes;

  @override
  void initState() {
    super.initState();
    _loadDirPaths();
    _loadReminderInterval();
  }

  Future<void> _loadDirPaths() async {
    final dbFile = await DatabaseProvider.getDbFile();
    final backupsDir = await DatabaseProvider.getBackupsDir();
    if (!mounted) return;
    setState(() {
      _dbDirPath = dbFile.parent.path;
      _backupsDirPath = backupsDir.path;
    });
  }

  Future<void> _loadReminderInterval() async {
    final minutes = await _settingsRepository.getInt(SettingsKeys.reminderIntervalMinutes);
    if (!mounted) return;
    setState(() => _reminderIntervalMinutes = minutes);
  }

  Future<void> _setReminderInterval(int? minutes) async {
    if (minutes == null) {
      await _settingsRepository.setString(SettingsKeys.reminderIntervalMinutes, '0');
    } else {
      await _settingsRepository.setInt(SettingsKeys.reminderIntervalMinutes, minutes);
    }
    if (!mounted) return;
    setState(() => _reminderIntervalMinutes = minutes);
    await _reminderService?.reloadInterval();
  }

  BackupService? get _backupService {
    try {
      return GetIt.I<BackupService>();
    } catch (_) {
      return null;
    }
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

  Future<void> _backupNow() async {
    final service = _backupService;
    if (service == null) return;

    setState(() => _isBackingUp = true);
    try {
      await service.createBackupNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup created')), // TODO: l10n
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')), // TODO: l10n
      );
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreFromBackup() async {
    final service = _backupService;
    if (service == null) return;

    final backups = await service.listBackups();
    if (!mounted) return;

    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No backups available')), // TODO: l10n
      );
      return;
    }

    final selected = await showDialog<BackupInfo>(
      context: context,
      builder: (dialogContext) {
        final theme = dialogContext.theme;
        return AlertDialog(
          title: const Text('Restore from backup'), // TODO: l10n
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormat.yMMMd().add_Hms().format(backup.createdAt),
                    style: theme.commonTextStyles.body,
                  ),
                  onTap: () => Navigator.of(dialogContext).pop(backup),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'), // TODO: l10n
            ),
          ],
        );
      },
    );

    if (selected == null || !mounted) return;

    // Release the OS-level file lock before overwriting the live DB file —
    // required on Windows, harmless on macOS/Linux.
    await DatabaseProvider.close();
    await service.restore(selected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Restored. Please restart the app for changes to take effect.', // TODO: l10n
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: theme.commonTextStyles.displayLarge),
          SizedBox(height: theme.spacings.x2l),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await SparkleBridge.checkForUpdates();
                },
                icon: const Icon(Icons.update),
                label: const Text("Check for updates"), // TODO: l10n
              ),
            ],
          ),
          SizedBox(height: theme.spacings.x2l),
          Text('Backup', style: theme.commonTextStyles.title), // TODO: l10n
          SizedBox(height: theme.spacings.md),
          if (_dbDirPath != null)
            _DirectoryPathRow(
              label: 'Database folder', // TODO: l10n
              path: _dbDirPath!,
            ),
          if (_backupsDirPath != null) ...[
            SizedBox(height: theme.spacings.xs),
            _DirectoryPathRow(
              label: 'Backups folder', // TODO: l10n
              path: _backupsDirPath!,
            ),
          ],
          SizedBox(height: theme.spacings.md),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isBackingUp ? null : _backupNow,
                icon: const Icon(Icons.backup),
                label: const Text("Backup now"), // TODO: l10n
              ),
              SizedBox(width: theme.spacings.md),
              OutlinedButton.icon(
                onPressed: _restoreFromBackup,
                icon: const Icon(Icons.restore),
                label: const Text("Restore from backup"), // TODO: l10n
              ),
            ],
          ),
          SizedBox(height: theme.spacings.x2l),
          Text('Floating comment tracker', style: theme.commonTextStyles.title), // TODO: l10n
          SizedBox(height: theme.spacings.md),
          Row(
            children: [
              Text('Reminder interval: ', style: theme.commonTextStyles.body), // TODO: l10n
              SizedBox(width: theme.spacings.sm),
              DropdownButton<int?>(
                value: _reminderIntervalMinutes == 0 ? null : _reminderIntervalMinutes,
                hint: const Text('Off'), // TODO: l10n
                items: const [
                  DropdownMenuItem(value: null, child: Text('Off')), // TODO: l10n
                  DropdownMenuItem(value: 1, child: Text('1 minute')), // TODO: l10n
                  DropdownMenuItem(value: 2, child: Text('2 minutes')), // TODO: l10n
                  DropdownMenuItem(value: 5, child: Text('5 minutes')), // TODO: l10n
                  DropdownMenuItem(value: 10, child: Text('10 minutes')), // TODO: l10n
                  DropdownMenuItem(value: 30, child: Text('30 minutes')), // TODO: l10n
                ],
                onChanged: _setReminderInterval,
              ),
            ],
          ),
          SizedBox(height: theme.spacings.md),
          _HotkeyRecorderRow(
            label: 'Toggle popover', // TODO: l10n
            settingKey: SettingsKeys.toggleHotkey,
            repository: _settingsRepository,
            hotkeyService: _hotkeyService,
          ),
          SizedBox(height: theme.spacings.sm),
          _HotkeyRecorderRow(
            label: 'Accept comment', // TODO: l10n
            settingKey: SettingsKeys.acceptHotkey,
            repository: _settingsRepository,
            hotkeyService: _hotkeyService,
          ),
          SizedBox(height: theme.spacings.sm),
          _HotkeyRecorderRow(
            label: 'Dismiss comment', // TODO: l10n
            settingKey: SettingsKeys.dismissHotkey,
            repository: _settingsRepository,
            hotkeyService: _hotkeyService,
          ),
        ],
      ),
    );
  }
}

/// A label + folder path that opens the path in the OS file manager
/// (Explorer/Finder) when tapped — pure convenience, no error feedback since
/// failures are silently swallowed by [revealInFileManager].
class _DirectoryPathRow extends StatelessWidget {
  final String label;
  final String path;

  const _DirectoryPathRow({required this.label, required this.path});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return InkWell(
      onTap: () => revealInFileManager(path),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: theme.spacings.lg,
            color: theme.colorsPalette.accent.primary,
          ),
          SizedBox(width: theme.spacings.xs),
          Text('$label: ', style: theme.commonTextStyles.caption),
          Text(
            path,
            style: theme.commonTextStyles.captionBold.copyWith(
              color: theme.colorsPalette.accent.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label + `HotKeyRecorder` that persists the recorded combo through
/// [HotkeyService.saveHotkey] (which re-registers all three hotkeys
/// immediately) and falls back to writing straight through [repository]
/// when the service isn't available (e.g. running on a non-Windows target).
class _HotkeyRecorderRow extends StatefulWidget {
  final String label;
  final String settingKey;
  final SqliteSettingsRepository repository;
  final HotkeyService? hotkeyService;

  const _HotkeyRecorderRow({
    required this.label,
    required this.settingKey,
    required this.repository,
    required this.hotkeyService,
  });

  @override
  State<_HotkeyRecorderRow> createState() => _HotkeyRecorderRowState();
}

class _HotkeyRecorderRowState extends State<_HotkeyRecorderRow> {
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
        SizedBox(
          width: 220,
          child: HotKeyRecorder(onHotKeyRecorded: _onRecorded),
        ),
      ],
    );
  }
}
