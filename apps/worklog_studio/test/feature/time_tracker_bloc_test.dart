// ignore_for_file: depend_on_referenced_packages

/// Unit tests for [TimeTrackerBloc] — the presentation-layer state machine
/// that wires [TimeTrackerService] events to UI-consumable states.
///
/// Strategy
/// ────────
/// All tests use [FakeClock] and [FakeTimeEntryRepository] from
/// test/helpers/test_fakes.dart so that no real database or platform code runs.
/// [IdleMonitor] is mocked via [MockIdleMonitor] (mocktail) because it is a
/// pure event-source with no interesting state of its own.
///
/// Instead of bloc_test (incompatible with this project's transitive dependency
/// graph), every test drives the bloc by calling [bloc.add(event)] and then
/// awaiting one microtask turn ([Future<void>.delayed(Duration.zero)]) — long
/// enough for the bloc's async handlers to complete before assertions run.
/// The shared [pump()] helper encapsulates this pattern.
///
/// Test groups:
///   1. initial state          – verifies the bloc boots into idle with no data.
///   2. State helper getters   – unit-tests the [isRunning], [activeEntryOrNull],
///                               and [allEntries] getters in isolation across all
///                               state variants (no async, no bloc).
///   3. TimeTrackerLoaded      – verifies the load event transitions correctly
///                               based on repository content.
///   4. TimeTrackerStarted     – start-timer contract at the bloc level (state
///                               transition, entry fields, no-op guard).
///   5. TimeTrackerStopped     – stop-timer contract (transition, no-op guard,
///                               endAt, active-null, duration).
///   6. IdleMonitor integration – verifies the subscription that auto-stops the
///                                timer on inactivity.
///   7. Error handling         – verifies that a service-level throw is caught
///                               and surfaced as the error state variant.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_event.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';

import '../helpers/test_fakes.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

/// Mocktail mock for [IdleMonitor].
/// We use a mock (not a fake) because [IdleMonitor] is a pure event source with
/// no meaningful state: all tests only need to control the stream it exposes and
/// verify that start()/stop() are called at the right times.
class MockIdleMonitor extends Mock implements IdleMonitor {}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// Minimal running [TimeEntry] fixture used to pre-populate the repository or
/// seed a running bloc state.  The default id 'run-1' is deliberately explicit
/// so tests that delete or look up the entry can refer to it by name.
TimeEntry _runningEntry({String id = 'run-1'}) => TimeEntry(
      id: id,
      startAt: DateTime(2025, 1, 1, 9),
      status: TimeEntryStatus.running,
    );

/// Minimal stopped [TimeEntry] fixture used wherever a history entry is needed.
/// The 1-hour duration (09:00–10:00) is arbitrary but deterministic.
TimeEntry _stoppedEntry({String id = 'stop-1'}) => TimeEntry(
      id: id,
      startAt: DateTime(2025, 1, 1, 9),
      endAt: DateTime(2025, 1, 1, 10),
      status: TimeEntryStatus.stopped,
    );

// ---------------------------------------------------------------------------
// pump() helper
// ---------------------------------------------------------------------------

/// Dispatches [event] to [bloc] and waits one microtask turn for the bloc's
/// async handler to complete.
///
/// [TimeTrackerBloc] handlers are all `async`: they `await` repository calls
/// and then emit new states.  [Future<void>.delayed(Duration.zero)] yields
/// control to the event loop once — enough for the entire handler to finish —
/// without introducing real wall-clock waiting.
///
/// Returns the bloc's state after the handler has settled, enabling
/// single-line "act + inspect" patterns in tests:
///   ```dart
///   final state = await pump(bloc, const TimeTrackerEvent.started());
///   expect(state.isRunning, isTrue);
///   ```
Future<TimeTrackerBlocState> pump(
  TimeTrackerBloc bloc,
  TimeTrackerEvent event,
) async {
  bloc.add(event);
  await Future<void>.delayed(Duration.zero);
  return bloc.state;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeClock clock;
  late FakeTimeEntryRepository repo;
  late TimeTrackerService service;

  /// Fixed starting time shared by all tests for deterministic assertions.
  final kStart = DateTime(2025, 1, 1, 9, 0, 0);

  /// Rebuild all collaborators from scratch before every test so that
  /// repository contents, clock position, and service state do not leak
  /// between tests.
  setUp(() {
    clock = FakeClock(kStart);
    repo = FakeTimeEntryRepository();
    service = TimeTrackerService(repository: repo, clock: clock);
  });

  /// Factory that creates a fresh [TimeTrackerBloc] wired to the test-scoped
  /// [service].  Accepts an optional [idleMonitor] so tests that exercise the
  /// idle-auto-stop path can inject a mock without affecting other tests.
  TimeTrackerBloc makeBloc({IdleMonitor? idleMonitor}) =>
      TimeTrackerBloc(service: service, idleMonitor: idleMonitor);

  // ── 1. Initial state ──────────────────────────────────────────────────────

  group('initial state', () {
    /// Verifies that a newly-constructed [TimeTrackerBloc] starts in the
    /// [TimeTrackerBlocState.idle()] variant — the "nothing has happened yet"
    /// state.  The bloc must not perform any I/O on construction; data loading
    /// is deferred until [TimeTrackerEvent.loaded] is explicitly dispatched.
    test('is idle', () {
      final bloc = makeBloc();
      expect(bloc.state, const TimeTrackerBlocState.idle());
      addTearDown(bloc.close);
    });

    /// Verifies that [TimeTrackerBlocState.isRunning] returns false in the
    /// idle state.  Components that conditionally render a "Stop" button check
    /// this getter, so it must be false before any timer has been started.
    test('isRunning is false', () {
      final bloc = makeBloc();
      expect(bloc.state.isRunning, isFalse);
      addTearDown(bloc.close);
    });

    /// Verifies that [TimeTrackerBlocState.allEntries] returns an empty list
    /// in the idle state.  No entries have been loaded from the repository yet,
    /// so the history list must be empty rather than null or throwing.
    test('allEntries is empty', () {
      final bloc = makeBloc();
      expect(bloc.state.allEntries, isEmpty);
      addTearDown(bloc.close);
    });

    /// Verifies that [TimeTrackerBlocState.activeEntryOrNull] returns null in
    /// the idle state.  No timer is running yet, so there is no active entry
    /// to expose to the UI.
    test('activeEntryOrNull is null', () {
      final bloc = makeBloc();
      expect(bloc.state.activeEntryOrNull, isNull);
      addTearDown(bloc.close);
    });
  });

  // ── 2. State helper getters ───────────────────────────────────────────────

  group('TimeTrackerBlocState getters', () {
    /// Verifies that [isRunning] is true *only* for the running state variant
    /// and false for every other variant (idle, loading, loaded, error).
    /// The getter is a safety-critical discriminator: incorrect results cause
    /// the UI to show a "Stop" button when no timer is running (or hide it
    /// when one is).  Testing all five variants in one test ensures no variant
    /// is accidentally left returning the wrong value.
    test('isRunning is true only for running state', () {
      expect(const TimeTrackerBlocState.idle().isRunning, isFalse);
      expect(const TimeTrackerBlocState.loading().isRunning, isFalse);
      expect(const TimeTrackerBlocState.loaded().isRunning, isFalse);
      expect(
        TimeTrackerBlocState.running(entries: [], activeEntry: _runningEntry()).isRunning,
        isTrue,
      );
      expect(
        TimeTrackerBlocState.error(errorHandler: Exception('e')).isRunning,
        isFalse,
      );
    });

    /// Verifies that [activeEntryOrNull] returns null for the three state
    /// variants that carry no active entry: idle, loading, and a bare error
    /// (an error with no activeEntry context provided).
    /// UI components read this getter to populate the "currently tracking"
    /// display; null must result in the empty/idle UI rather than a crash.
    test('activeEntryOrNull returns null for idle, loading, bare error', () {
      expect(const TimeTrackerBlocState.idle().activeEntryOrNull, isNull);
      expect(const TimeTrackerBlocState.loading().activeEntryOrNull, isNull);
      expect(
        TimeTrackerBlocState.error(errorHandler: Exception('e')).activeEntryOrNull,
        isNull,
      );
    });

    /// Verifies that [activeEntryOrNull] returns the embedded [TimeEntry] from
    /// the running state.  The UI binds directly to this value to display the
    /// live timer text, project name, and task name; it must be the exact same
    /// object that was passed into the state constructor.
    test('activeEntryOrNull returns the entry from running state', () {
      final entry = _runningEntry();
      expect(
        TimeTrackerBlocState.running(entries: [], activeEntry: entry).activeEntryOrNull,
        entry,
      );
    });

    /// Verifies that [allEntries] returns an empty list (not null) for the
    /// idle and loading states.  During startup or while a load is in progress
    /// the history list must be empty so the UI renders an empty state rather
    /// than a stale list or a null-dereference crash.
    test('allEntries returns empty list from idle and loading states', () {
      expect(const TimeTrackerBlocState.idle().allEntries, isEmpty);
      expect(const TimeTrackerBlocState.loading().allEntries, isEmpty);
    });

    /// Verifies that [allEntries] exposes the entries list carried by the
    /// loaded state.  This is the happy-path case: after data is fetched from
    /// the repository the UI receives the full list via this getter.
    test('allEntries returns entries from loaded state', () {
      final entries = [_stoppedEntry()];
      expect(TimeTrackerBlocState.loaded(entries: entries).allEntries, entries);
    });

    /// Verifies that [allEntries] exposes the entries list from the running
    /// state.  When a timer is active the running state holds both the active
    /// entry *and* the full history list; [allEntries] must expose the history
    /// so the UI can show both the active timer and past entries simultaneously.
    test('allEntries returns entries from running state', () {
      final entries = [_stoppedEntry(), _runningEntry()];
      expect(
        TimeTrackerBlocState.running(entries: entries, activeEntry: _runningEntry())
            .allEntries,
        entries,
      );
    });
  });

  // ── 3. TimeTrackerLoaded event ─────────────────────────────────────────────

  group('TimeTrackerLoaded event', () {
    /// Verifies the state sequence emitted when [TimeTrackerEvent.loaded] is
    /// dispatched against an empty repository.
    /// Expected sequence: [loading] → [loaded(entries: [])].
    ///   • [loading] must appear first so the UI can show a spinner immediately.
    ///   • [loaded(entries: [])] must follow once the (empty) fetch completes
    ///     so the UI transitions to the empty-history view.
    /// The [expectLater] + [emitsInOrder] pattern asserts both order and exact
    /// values without polling.
    test('emits [loading, loaded(empty)] when repo is empty', () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);

      expectLater(
        bloc.stream,
        emitsInOrder([
          const TimeTrackerBlocState.loading(),
          const TimeTrackerBlocState.loaded(entries: []),
        ]),
      );

      bloc.add(const TimeTrackerEvent.loaded());
      await Future<void>.delayed(Duration.zero);
    });

    /// Verifies that when the repository already contains a running entry,
    /// [TimeTrackerEvent.loaded] produces [loading] followed by a [running]
    /// state (not [loaded]).  This covers the app-relaunch scenario where a
    /// previous session was not stopped before closing the app and the bloc
    /// must reconstruct the "timer is active" state from persisted data.
    test('emits [loading, running] when a running entry exists', () async {
      repo.seed(_runningEntry());
      final bloc = makeBloc();
      addTearDown(bloc.close);

      final states = <TimeTrackerBlocState>[];
      final sub = bloc.stream.listen(states.add);
      addTearDown(sub.cancel);

      bloc.add(const TimeTrackerEvent.loaded());
      await Future<void>.delayed(Duration.zero);

      expect(states.length, 2);
      expect(states[0], const TimeTrackerBlocState.loading());
      expect(states[1].isRunning, isTrue);
    });
  });

  // ── 4. TimeTrackerStarted event ────────────────────────────────────────────

  group('TimeTrackerStarted event', () {
    /// Verifies that dispatching [TimeTrackerEvent.started] transitions the
    /// bloc from idle to the running state.  This is the primary "start timer"
    /// path: after a single event the bloc must report isRunning == true so the
    /// UI switches to its active-tracking view.
    test('transitions to running state', () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);

      final state = await pump(bloc, const TimeTrackerEvent.started());
      expect(state.isRunning, isTrue);
    });

    /// Verifies that the running state produced after [TimeTrackerEvent.started]
    /// contains an [activeEntryOrNull] whose fields match the arguments passed
    /// to the event (projectId, taskId) and whose startAt equals the clock time
    /// at the moment of the event.  This ensures the bloc faithfully threads
    /// event arguments through the service and into the emitted state, which
    /// the UI uses to display "now tracking: <task> in <project>".
    test('running state carries the created active entry with correct fields', () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);

      await pump(bloc, const TimeTrackerEvent.started(projectId: 'p1', taskId: 't1'));

      final entry = bloc.state.activeEntryOrNull;
      expect(entry, isNotNull);
      expect(entry!.projectId, 'p1');
      expect(entry.taskId, 't1');
      expect(entry.startAt, kStart);
      expect(entry.status, TimeEntryStatus.running);
    });

    /// Verifies that [TimeTrackerEvent.started] is silently ignored (no new
    /// state emitted) when a timer is already running.  This guards against
    /// rapid double-taps on the Start button: the second tap must not create a
    /// second running entry or flicker the UI.  The test listens on the stream
    /// after the bloc is already in the running state and confirms no emission
    /// follows the duplicate event.
    test('is a no-op (emits nothing) when timer is already running', () async {
      repo.seed(_runningEntry());
      final bloc = makeBloc();
      addTearDown(bloc.close);

      // Seed bloc into running state
      await pump(bloc, const TimeTrackerEvent.loaded());
      expect(bloc.state.isRunning, isTrue);

      final statesBefore = bloc.state;
      final emitted = <TimeTrackerBlocState>[];
      final sub = bloc.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      // A second start must be swallowed
      bloc.add(const TimeTrackerEvent.started());
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);
      expect(bloc.state, statesBefore);
    });
  });

  // ── 5. TimeTrackerStopped event ────────────────────────────────────────────

  group('TimeTrackerStopped event', () {
    /// Verifies the full running → stopped state transition at the bloc level.
    /// After start the bloc must report isRunning == true; after stop it must
    /// report isRunning == false.  This is the primary "stop timer" happy path
    /// whose correctness is required for the UI to switch from active-tracking
    /// view back to the idle/history view.
    test('transitions from running to loaded (not running)', () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);

      await pump(bloc, const TimeTrackerEvent.started());
      expect(bloc.state.isRunning, isTrue);

      await pump(bloc, const TimeTrackerEvent.stopped());
      expect(bloc.state.isRunning, isFalse);
    });

    /// Verifies that [TimeTrackerEvent.stopped] is silently ignored when no
    /// timer is running.  The bloc must not emit a new state (which would
    /// cause spurious UI re-renders) and must not throw when the underlying
    /// service would throw a StateError — the early-return guard in the handler
    /// must prevent the service call entirely.
    test('is a no-op when no timer is running', () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);

      final emitted = <TimeTrackerBlocState>[];
      final sub = bloc.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      bloc.add(const TimeTrackerEvent.stopped());
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);
    });

    /// Verifies that the [endAt] field on the persisted stopped entry exactly
    /// equals the clock value at the moment [TimeTrackerEvent.stopped] was
    /// processed.  The fake clock is advanced by 1 hour between start and stop
    /// to produce a non-zero, deterministic endAt.  Correct endAt is required
    /// for accurate billing: any drift between real stop-time and persisted
    /// endAt would inflate or deflate reported hours.
    test('stopped entry has endAt matching clock.now() at stop time', () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);

      await pump(bloc, const TimeTrackerEvent.started());
      clock.advance(const Duration(hours: 1));
      await pump(bloc, const TimeTrackerEvent.stopped());

      final all = await service.getAll();
      final stopped = all.firstWhere((e) => e.status == TimeEntryStatus.stopped);
      expect(stopped.endAt, kStart.add(const Duration(hours: 1)));
    });

    /// Verifies that [activeEntryOrNull] returns null in the state emitted after
    /// [TimeTrackerEvent.stopped].  The UI binds to this getter to render the
    /// "currently tracking" section; it must be null after a stop so the section
    /// hides rather than showing stale data.
    test('activeEntryOrNull is null after stopping', () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);

      await pump(bloc, const TimeTrackerEvent.started());
      await pump(bloc, const TimeTrackerEvent.stopped());

      expect(bloc.state.activeEntryOrNull, isNull);
    });

    /// End-to-end lifecycle test: start → advance 45 minutes → stop, then
    /// inspect the repository directly to confirm the saved entry has the exact
    /// 45-minute duration.  This validates the complete chain from bloc event
    /// through service through repository, ensuring no data is lost or
    /// distorted at any handoff point.
    test('full lifecycle: start → 45 min elapsed → stop → correct duration in repo', () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);

      await pump(bloc, const TimeTrackerEvent.started());
      clock.advance(const Duration(minutes: 45));
      await pump(bloc, const TimeTrackerEvent.stopped());

      final all = await service.getAll();
      final entry = all.first;
      expect(entry.endAt!.difference(entry.startAt), const Duration(minutes: 45));
    });
  });

  // ── 6. IdleMonitor integration ─────────────────────────────────────────────

  group('IdleMonitor integration', () {
    /// Verifies the idle-auto-stop feature: when the [IdleMonitor] emits an
    /// [IdleThresholdReached] event while a timer is running, the bloc must
    /// automatically dispatch a stop and transition to a non-running state.
    ///
    /// Setup:
    ///   • A [StreamController<IdleEvent>] acts as the fake idle source.
    ///   • The mock [IdleMonitor] exposes that controller's stream.
    ///   • start() and stop() on the monitor are stubbed to succeed silently.
    ///
    /// The test confirms that pushing a single [IdleThresholdReached] into
    /// the stream — without any explicit stop event from the user — causes
    /// the bloc to stop the timer on its own.
    test('auto-stops when IdleThresholdReached fires while running', () async {
      final idleController = StreamController<IdleEvent>.broadcast();
      final mockIdle = MockIdleMonitor();

      when(() => mockIdle.onIdleEvent).thenAnswer((_) => idleController.stream);
      when(() => mockIdle.start(thresholdSeconds: any(named: 'thresholdSeconds')))
          .thenAnswer((_) async {});
      when(() => mockIdle.stop()).thenAnswer((_) async {});

      final bloc = makeBloc(idleMonitor: mockIdle);
      addTearDown(bloc.close);

      await pump(bloc, const TimeTrackerEvent.started());
      expect(bloc.state.isRunning, isTrue);

      idleController.add(IdleThresholdReached(
        idleSeconds: 600,
        timestamp: clock.now(),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.isRunning, isFalse);
      await idleController.close();
    });

    /// Verifies that [IdleThresholdReached] events are silently discarded when
    /// no timer is running.  The bloc's idle subscription checks [state.isRunning]
    /// before dispatching a stop event; this test confirms that check works and
    /// that idle noise while idle does not cause spurious state changes or errors.
    test('idle events are ignored when timer is not running', () async {
      final idleController = StreamController<IdleEvent>.broadcast();
      final mockIdle = MockIdleMonitor();

      when(() => mockIdle.onIdleEvent).thenAnswer((_) => idleController.stream);

      final bloc = makeBloc(idleMonitor: mockIdle);
      addTearDown(bloc.close);

      final emitted = <TimeTrackerBlocState>[];
      final sub = bloc.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      idleController.add(IdleThresholdReached(
        idleSeconds: 600,
        timestamp: clock.now(),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty); // idle = not running → no state change
      await idleController.close();
    });
  });

  // ── 7. Error handling ──────────────────────────────────────────────────────

  group('Error handling', () {
    /// Verifies that a [StateError] thrown by [TimeTrackerService.stop()] is
    /// caught by the bloc's [_reloadAndEmit] helper and surfaced as the
    /// [TimeTrackerBlocState.error] variant rather than propagating as an
    /// unhandled exception.
    ///
    /// Setup: the repo is seeded with a running entry so the bloc loads into
    /// running state, then the running entry is deleted from the repo *directly*
    /// (bypassing the service) before the stop event is dispatched.  This
    /// causes [service.stop()] to throw because it can no longer find an active
    /// entry.
    ///
    /// The test confirms that the resulting state is the error variant using
    /// the Freezed [when()] exhaustive switch, which is the only way to
    /// type-safely identify a specific Freezed union variant from outside the
    /// file where it is declared.
    test('emits error state when service throws during stop', () async {
      repo.seed(_runningEntry());
      final bloc = makeBloc();
      addTearDown(bloc.close);

      // Put bloc in running state by loading
      await pump(bloc, const TimeTrackerEvent.loaded());
      expect(bloc.state.isRunning, isTrue);

      // Now remove the running entry so service.stop() throws
      await repo.delete('run-1');

      await pump(bloc, const TimeTrackerEvent.stopped());

      // Must be the error variant
      final isError = bloc.state.when(
        idle: () => false,
        loading: () => false,
        loaded: (_, __) => false,
        running: (_, __) => false,
        error: (_, __, ___) => true,
      );
      expect(isError, isTrue);
    });

    /// Verifies that the error state is constructed correctly when the bloc
    /// preserves previous context across a failure.  Specifically, [allEntries]
    /// must equal the entries snapshot that was passed to the error constructor
    /// so the UI can continue showing the last-known history list even while
    /// displaying an error banner.  Also confirms [isRunning] is false: an
    /// error is never a running state.
    test('error state preserves previous allEntries context', () {
      final entries = [_stoppedEntry()];
      final errorState = TimeTrackerBlocState.error(
        errorHandler: Exception('boom'),
        entries: entries,
      );
      expect(errorState.allEntries, entries);
      expect(errorState.isRunning, isFalse);
    });
  });
}
