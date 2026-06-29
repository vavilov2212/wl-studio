// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/windows_desktop_service.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
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

  group('WindowsDesktopService follower-side command forwarding', () {
    late WindowsDesktopService followerService;
    late MiniTrackerCubit followerCubit;

    setUp(() {
      followerService = WindowsDesktopService();
      followerCubit = MiniTrackerCubit();
      followerService.setFollowerCubitForTesting(followerCubit);
    });

    tearDown(() async {
      await followerCubit.close();
    });

    test('focusComment forwards to the follower cubit as a command', () async {
      final received = <MiniPanelCommand>[];
      final sub = followerCubit.commands.listen(received.add);

      await followerService.handleIncomingIpcMessageForTesting('focusComment', null);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.focusComment]);
      await sub.cancel();
    });

    test('acceptComment forwards to the follower cubit as a command', () async {
      final received = <MiniPanelCommand>[];
      final sub = followerCubit.commands.listen(received.add);

      await followerService.handleIncomingIpcMessageForTesting('acceptComment', null);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.acceptComment]);
      await sub.cancel();
    });

    test('dismissComment forwards to the follower cubit as a command', () async {
      final received = <MiniPanelCommand>[];
      final sub = followerCubit.commands.listen(received.add);

      await followerService.handleIncomingIpcMessageForTesting('dismissComment', null);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.dismissComment]);
      await sub.cancel();
    });

    test('autoDismissComment forwards to the follower cubit as a command', () async {
      final received = <MiniPanelCommand>[];
      final sub = followerCubit.commands.listen(received.add);

      await followerService.handleIncomingIpcMessageForTesting('autoDismissComment', null);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.autoDismissComment]);
      await sub.cancel();
    });
  });

  group('WindowsDesktopService leader-side window-aware routing', () {
    late WindowsDesktopService leaderService;

    setUp(() {
      leaderService = WindowsDesktopService();
      leaderService.miniPanelWindowForTesting.windowId = 101;
      leaderService.miniPanelWindowForTesting.followerReady = false;
      leaderService.activityWindowForTesting.windowId = 202;
      leaderService.activityWindowForTesting.followerReady = false;
    });

    test('miniReady from the mini panel window marks only that window ready', () async {
      await leaderService.handleIncomingIpcMessageForTesting(
        'miniReady',
        null,
        fromWindowId: 101,
      );

      expect(leaderService.miniPanelWindowForTesting.followerReady, isTrue);
      expect(leaderService.activityWindowForTesting.followerReady, isFalse);
    });

    test('miniReady from the activity window marks only that window ready', () async {
      await leaderService.handleIncomingIpcMessageForTesting(
        'miniReady',
        null,
        fromWindowId: 202,
      );

      expect(leaderService.activityWindowForTesting.followerReady, isTrue);
      expect(leaderService.miniPanelWindowForTesting.followerReady, isFalse);
    });

    test('miniClosed from a window clears only that window\'s readiness', () async {
      leaderService.miniPanelWindowForTesting.followerReady = true;
      leaderService.activityWindowForTesting.followerReady = true;

      await leaderService.handleIncomingIpcMessageForTesting(
        'miniClosed',
        null,
        fromWindowId: 101,
      );

      expect(leaderService.miniPanelWindowForTesting.followerReady, isFalse);
      expect(leaderService.activityWindowForTesting.followerReady, isTrue);
    });

    test('miniReady from an unknown window id is a harmless no-op', () async {
      await leaderService.handleIncomingIpcMessageForTesting(
        'miniReady',
        null,
        fromWindowId: 999,
      );

      expect(leaderService.miniPanelWindowForTesting.followerReady, isFalse);
      expect(leaderService.activityWindowForTesting.followerReady, isFalse);
    });
  });
}
