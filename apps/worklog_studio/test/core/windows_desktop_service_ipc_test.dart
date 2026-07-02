// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/windows_desktop_service.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';

import '../helpers/test_fakes.dart';

void main() {
  group('WindowsDesktopService IPC message handling', () {
    late FakeClock clock;
    late FakeTimeEntryRepository repo;
    late TimeTrackerBloc bloc;
    late WindowsDesktopService service;

    setUp(() {
      clock = FakeClock(DateTime(2025, 1, 1, 9));
      repo = FakeTimeEntryRepository();
      bloc = TimeTrackerBloc(
        service: TimeTrackerService(repository: repo, clock: clock),
      );
      service = WindowsDesktopService();
      service.setLeaderBlocForTesting(bloc);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('dispatchAction(start) starts tracking on the leader bloc', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'start',
        'projectId': 'p1',
        'taskId': 't1',
        'comment': 'hello',
      });

      await bloc.stream.firstWhere((s) => s.isRunning);

      expect(bloc.state.isRunning, isTrue);
      expect(bloc.state.activeEntryOrNull?.projectId, 'p1');
      expect(bloc.state.activeEntryOrNull?.taskId, 't1');
      expect(bloc.state.activeEntryOrNull?.comment, 'hello');
    });

    test('dispatchAction(start) while running stops old entry and starts new one', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'start',
        'projectId': 'p1',
        'taskId': 't1',
        'comment': 'old',
      });
      await bloc.stream.firstWhere((s) => s.isRunning);

      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'start',
        'projectId': 'p1',
        'taskId': 't1',
        'comment': 'new',
      });
      await bloc.stream.firstWhere(
        (s) => s.isRunning && s.activeEntryOrNull?.comment == 'new',
      );

      expect(bloc.state.isRunning, isTrue);
      expect(bloc.state.activeEntryOrNull?.comment, 'new');
    });

    test('dispatchAction(stop) stops a running entry', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'start',
        'projectId': 'p1',
        'taskId': 't1',
        'comment': null,
      });
      await bloc.stream.firstWhere((s) => s.isRunning);

      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'stop',
      });
      await bloc.stream.firstWhere((s) => !s.isRunning);

      expect(bloc.state.isRunning, isFalse);
    });

    test('dispatchAction(stop) is a no-op when nothing is running', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'stop',
      });

      // No event was added, so the bloc should still be in its initial idle
      // state - give the event loop a tick to prove no transition happened.
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isRunning, isFalse);
    });

    test('dispatchAction(updateComment) updates the running entry comment', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'start',
        'projectId': 'p1',
        'taskId': 't1',
        'comment': 'original',
      });
      await bloc.stream.firstWhere((s) => s.isRunning);

      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'updateComment',
        'comment': 'updated comment',
      });
      await bloc.stream.firstWhere(
        (s) => s.activeEntryOrNull?.comment == 'updated comment',
      );

      expect(bloc.state.activeEntryOrNull?.comment, 'updated comment');
      expect(bloc.state.isRunning, isTrue);
    });

    test('dispatchAction(updateComment) is a no-op when nothing is running', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'updateComment',
        'comment': 'ignored',
      });

      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isRunning, isFalse);
    });
  });

  group('WindowsDesktopService leader-side window-aware routing', () {
    late WindowsDesktopService leaderService;

    setUp(() {
      leaderService = WindowsDesktopService();
      leaderService.miniPanelWindowForTesting.windowId = '101';
      leaderService.miniPanelWindowForTesting.followerReady = false;
    });

    test('miniReady from the mini panel window marks it ready', () async {
      await leaderService.handleIncomingIpcMessageForTesting(
        'miniReady',
        {'fromWindowId': '101'},
      );

      expect(leaderService.miniPanelWindowForTesting.followerReady, isTrue);
    });

    test('miniClosed from the mini panel clears its readiness', () async {
      leaderService.miniPanelWindowForTesting.followerReady = true;

      await leaderService.handleIncomingIpcMessageForTesting(
        'miniClosed',
        {'fromWindowId': '101'},
      );

      expect(leaderService.miniPanelWindowForTesting.followerReady, isFalse);
    });

    test('miniReady from an unknown window id is a harmless no-op', () async {
      await leaderService.handleIncomingIpcMessageForTesting(
        'miniReady',
        {'fromWindowId': '999'},
      );

      expect(leaderService.miniPanelWindowForTesting.followerReady, isFalse);
    });
  });
}
