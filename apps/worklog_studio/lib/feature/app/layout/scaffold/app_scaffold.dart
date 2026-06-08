import 'package:flutter/material.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_scope.dart';
import 'package:worklog_studio_style_system/ui_kit/src/drawer/drawer_local_host.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final config = AppBarScope.of(context);

    return Scaffold(
      appBar: config.visible
          ? AppBar(
              title: config.title,
              actions: config.actions,
              actionsPadding: EdgeInsets.symmetric(
                horizontal: context.theme.spacings.lg,
              ),
            )
          : null,
      body: LocalDrawerHost(child: body),
    );
  }
}
