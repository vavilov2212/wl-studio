import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/feature/work_log/bloc/work_log_raw_data/work_log_raw_data_bloc.dart';
import 'package:worklog_studio/feature/work_log/data/usecases/work_log_raw_data_usecase.dart';

// ── Fake ─────────────────────────────────────────────────────────────────────

class _FakeUsecase implements IWorkLogRawDataUsecase {
  final bool shouldThrow;
  int attachCalls = 0;

  _FakeUsecase({this.shouldThrow = false});

  @override
  Future<void> attachSession() async {
    attachCalls++;
    if (shouldThrow) throw Exception('network error');
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('WorkLogRawDataBloc - initial state', () {
    test('starts in idle state', () {
      final bloc = WorkLogRawDataBloc(workLogRawDataUsecase: _FakeUsecase());
      expect(bloc.state, const WorkLogRawDataState.idle());
      bloc.close();
    });
  });

  group('WorkLogRawDataBloc - load event', () {
    test('emits progress then success on successful load', () async {
      final bloc = WorkLogRawDataBloc(workLogRawDataUsecase: _FakeUsecase());
      final states = <WorkLogRawDataState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const WorkLogRawDataEvent.load());
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        const WorkLogRawDataState.progress(),
        const WorkLogRawDataState.success(),
      ]);
      await sub.cancel();
      await bloc.close();
    });

    test('emits progress then error when usecase throws', () async {
      final bloc = WorkLogRawDataBloc(
        workLogRawDataUsecase: _FakeUsecase(shouldThrow: true),
      );
      final states = <WorkLogRawDataState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const WorkLogRawDataEvent.load());
      await Future<void>.delayed(Duration.zero);

      expect(states, hasLength(2));
      expect(states.first, const WorkLogRawDataState.progress());
      expect(
        states.last.maybeWhen(error: (_) => true, orElse: () => false),
        isTrue,
      );
      await sub.cancel();
      await bloc.close();
    });

    test('calls attachSession once per load', () async {
      final usecase = _FakeUsecase();
      final bloc = WorkLogRawDataBloc(workLogRawDataUsecase: usecase);

      bloc.add(const WorkLogRawDataEvent.load());
      await Future<void>.delayed(Duration.zero);
      await bloc.close();

      expect(usecase.attachCalls, 1);
    });
  });

  group('WorkLogRawDataBloc - refresh event', () {
    test('emits progress then success on successful refresh', () async {
      final bloc = WorkLogRawDataBloc(workLogRawDataUsecase: _FakeUsecase());
      final states = <WorkLogRawDataState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const WorkLogRawDataEvent.refresh());
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        const WorkLogRawDataState.progress(),
        const WorkLogRawDataState.success(),
      ]);
      await sub.cancel();
      await bloc.close();
    });

    test('completes the completer after a successful refresh', () async {
      final usecase = _FakeUsecase();
      final bloc = WorkLogRawDataBloc(workLogRawDataUsecase: usecase);
      final completer = Completer<void>();

      bloc.add(WorkLogRawDataEvent.refresh(completer: completer));
      await completer.future.timeout(const Duration(seconds: 2));
      await bloc.close();

      expect(completer.isCompleted, isTrue);
    });
  });
}
