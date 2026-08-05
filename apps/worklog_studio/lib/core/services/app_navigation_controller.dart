/// Lets any widget request the app switch to an entity's own page and open
/// its existing edit drawer, without needing a direct reference to AppShell.
/// AppShell registers the real handlers once, at startup, via
/// [registerHandlers].
class AppNavigationController {
  void Function(String taskId)? _openTaskHandler;
  void Function(String projectId)? _openProjectHandler;
  void Function(String entryId)? _openHistoryEntryHandler;
  void Function()? _openReportsHandler;

  void registerHandlers({
    required void Function(String taskId) openTask,
    required void Function(String projectId) openProject,
    required void Function(String entryId) openHistoryEntry,
    required void Function() openReports,
  }) {
    _openTaskHandler = openTask;
    _openProjectHandler = openProject;
    _openHistoryEntryHandler = openHistoryEntry;
    _openReportsHandler = openReports;
  }

  void openTask(String taskId) => _openTaskHandler?.call(taskId);

  void openProject(String projectId) => _openProjectHandler?.call(projectId);

  void openHistoryEntry(String entryId) =>
      _openHistoryEntryHandler?.call(entryId);

  void openReports() => _openReportsHandler?.call();
}
