// PROTOTYPE: This feature is not wired into any app route and is kept for reference only.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/core/services/service_locator/service_locator.dart';
import 'package:worklog_studio/entity/session/data/repository/session_storage_repository.dart';
import 'package:worklog_studio/feature/work_log/bloc/work_log_raw_data/work_log_raw_data_bloc.dart';
import 'package:worklog_studio/feature/work_log/data/usecases/work_log_raw_data_usecase.dart';

class WorkLogRawDataScope extends StatelessWidget {
  final Widget child;
  const WorkLogRawDataScope({required this.child, super.key});

  static void load(BuildContext context) =>
      context.read<WorkLogRawDataBloc>()..add(WorkLogRawDataEvent.load());

  static void refresh(BuildContext context, {Completer<void>? completer}) =>
      context.read<WorkLogRawDataBloc>()
        ..add(WorkLogRawDataEvent.refresh(completer: completer));

  @override
  Widget build(BuildContext context) => BlocProvider<WorkLogRawDataBloc>(
    create: (_) => WorkLogRawDataBloc(
      workLogRawDataUsecase: WorkLogRawDataUsecase(
        getIt<SessionStorageRepository>(),
      ),
    ),
    // )..add(WorkLogRawDataEvent.load()),
    child: child,
  );
}
