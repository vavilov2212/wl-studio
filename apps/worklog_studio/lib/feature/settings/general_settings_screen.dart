import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:worklog_studio/core/services/backup_service.dart';
import 'package:worklog_studio/core/services/desktop/reveal_in_file_manager.dart';
import 'package:worklog_studio/core/sparkle/sparkle_bridge.dart';
import 'package:worklog_studio/data/sqlite/database_provider.dart';
import 'package:worklog_studio/domain/backup.dart';
import 'package:worklog_studio_style_system/theme/theme_extension/app_theme_extension.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  bool _isBackingUp = false;
  String? _dbDirPath;
  String? _backupsDirPath;

  @override
  void initState() {
    super.initState();
    _loadDirPaths();
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

  BackupService? get _backupService {
    try {
      return GetIt.I<BackupService>();
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
          Text('General', style: theme.commonTextStyles.displayLarge), // TODO: l10n
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
