// PROTOTYPE: This feature is not wired into any app route and is kept for reference only.
import 'package:flutter/material.dart' hide Drawer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/work_log/bloc/work_log_raw_data/work_log_raw_data_bloc.dart';
import 'package:worklog_studio/feature/work_log/presentation/layouts/data_layout.dart';
import 'package:worklog_studio/feature/work_log/presentation/layouts/welcome_layout.dart';
import 'package:worklog_studio/feature/work_log/presentation/work_log_raw_data_scope.dart';

class WorkLogPage extends StatefulWidget {
  const WorkLogPage({super.key});

  @override
  State<WorkLogPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<WorkLogPage> {
  @override
  Widget build(BuildContext context) {
    return WorkLogRawDataScope(
      child: BlocBuilder<WorkLogRawDataBloc, WorkLogRawDataState>(
        builder: (context, state) => state.map(
          error: (_) => SizedBox.shrink(),
          idle: (_) => WelcomeLayout(),
          progress: (_) => SizedBox.shrink(),
          success: (context) => DataLayout(),
        ),
      ),
    );
  }
}
