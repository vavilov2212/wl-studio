import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/top_app_bar.dart';
import 'package:worklog_studio/feature/app/layout/app_drawer_host.dart';
import 'package:worklog_studio/feature/app/layout/app_route.dart';
import 'package:worklog_studio/feature/app/layout/sidebar_navigation.dart';
import 'package:worklog_studio/feature/history/presentation/history_page.dart';
import 'package:worklog_studio/feature/reports/presentation/reports_page.dart';
import 'package:worklog_studio/feature/home/presentation/home_page.dart';
import 'package:worklog_studio/feature/projects/presentation/projects_page.dart';
import 'package:worklog_studio/feature/settings/presentation/general_settings_screen.dart';
import 'package:worklog_studio/feature/settings/presentation/hotkey_settings_screen.dart';
import 'package:worklog_studio/feature/tasks/presentation/tasks_page.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppRoute _currentRoute = AppRoute.dashboard;
  StreamSubscription<String>? _navSub;

  @override
  void initState() {
    super.initState();
    context.read<AppNavigationController>().registerHandlers(
      openTask: _openTask,
      openProject: _openProject,
      openHistoryEntry: _openHistoryEntry,
    );
    _navSub = DesktopServiceRegistry.instance.navigationStream.listen((route) {
      if (route == 'history') {
        _onRouteSelected(AppRoute.history);
      } else if (route == 'tasks') {
        _onRouteSelected(AppRoute.tasks);
      } else if (route == 'projects') {
        _onRouteSelected(AppRoute.projects);
      }
    });
  }

  @override
  void dispose() {
    _navSub?.cancel();
    super.dispose();
  }

  /// Plain tab switch — no entity carried over, so the shared drawer closes.
  void _onRouteSelected(AppRoute route) {
    context.read<DrawerHostController>().close();
    setState(() {
      _currentRoute = route;
    });
  }

  /// Deep-link navigation — resolves the entity and opens the shared drawer
  /// *before* switching tabs, so the freshly-mounted page already sees it.
  void _openHistoryEntry(String entryId) {
    final resolved = context
        .read<EntityResolver>()
        .getResolvedTimeEntries()
        .firstWhereOrNull((e) => e.entry.id == entryId);
    if (resolved != null) {
      context.read<DrawerHostController>().openTimeEntryEdit(resolved.entry);
    }
    setState(() {
      _currentRoute = AppRoute.history;
    });
  }

  void _openHistoryCreateEntry() {
    context.read<DrawerHostController>().openTimeEntryCreate();
    setState(() {
      _currentRoute = AppRoute.history;
    });
  }

  void _openTask(String taskId) {
    final resolved = context
        .read<EntityResolver>()
        .getResolvedTasks()
        .firstWhereOrNull((t) => t.id == taskId);
    if (resolved != null) {
      context.read<DrawerHostController>().openTaskEdit(resolved.task);
    }
    setState(() {
      _currentRoute = AppRoute.tasks;
    });
  }

  void _openProject(String projectId) {
    final resolved = context
        .read<EntityResolver>()
        .getResolvedProjects()
        .firstWhereOrNull((p) => p.id == projectId);
    if (resolved != null) {
      context.read<DrawerHostController>().openProjectEdit(resolved.project);
    }
    setState(() {
      _currentRoute = AppRoute.projects;
    });
  }

  /// Builds only the active page. Replacing the previous IndexedStack means
  /// the previous page's widget leaves the tree and Flutter disposes it —
  /// this is the fix for pages staying resident in memory forever.
  Widget _buildActiveScreen() {
    switch (_currentRoute) {
      case AppRoute.dashboard:
        return HomePage(
          title: 'Dashboard',
          onViewAllHistory: () => _onRouteSelected(AppRoute.history),
          onSelectHistoryEntry: _openHistoryEntry,
          onAddTimeEntry: _openHistoryCreateEntry,
        );
      case AppRoute.history:
        return const HistoryScreen();
      case AppRoute.reports:
        return const ReportsScreen();
      case AppRoute.projects:
        return const ProjectsScreen();
      case AppRoute.tasks:
        return const TasksScreen();
      case AppRoute.settingsGeneral:
        return const GeneralSettingsScreen();
      case AppRoute.settingsHotkeys:
        return const HotkeySettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Scaffold(
      backgroundColor: palette.background.canvas,
      body: Row(
        children: [
          SidebarNavigation(
            currentRoute: _currentRoute,
            onRouteSelected: _onRouteSelected,
          ),
          Expanded(
            child: Column(
              children: [
                TopAppBar(
                  onOpenProject: _openProject,
                  onOpenTask: _openTask,
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildActiveScreen()),
                      const AppDrawerHost(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
