// ignore_for_file: depend_on_referenced_packages

/// Unit tests for [TimeTrackerService] — the core business-logic layer.
///
/// These tests are pure Dart: no Flutter framework, no platform channels,
/// no database.  All infrastructure is replaced by [FakeClock] and
/// [FakeTimeEntryRepository] defined in test/helpers/test_fakes.dart.
///
/// Test groups:
///   1. TimeEntry domain model  – verifies the value-object behaviour of
///      [TimeEntry] in isolation (status flag, duration calculation, assignment
///      flag, copyWith identity preservation).
///   2. start()                 – timer-start contract (timestamps, field
///      propagation, persistence, id uniqueness, double-start guard).
///   3. stop()                  – timer-stop contract (no-active guard,
///      correct endAt, post-stop active=null, entry retained in history).
///   4. Elapsed duration lifecycle – verifies that a live entry's duration
///      grows with the clock, that a stopped entry's duration is frozen, and
///      that startAt is never mutated by stop().
///   5. updateActive()          – field-update contract (no-active guard,
///      mutation applied, persisted correctly).
///   6. CRUD helpers            – deleteEntry, createEntry (id assignment),
///      updateEntry persistence.
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/domain/time_entry.dart';

import '../helpers/test_fakes.dart';

void main() {
  late FakeClock clock;
  late FakeTimeEntryRepository repo;
  late TimeTrackerService sut;

  /// Fixed anchor point used as the initial clock value across all tests.
  /// Using a concrete, far-future date makes test failures easy to read in
  /// assertion output and avoids coincidental matches with DateTime.now().
  final kStart = DateTime(2025, 1, 1, 9, 0, 0);

  /// Recreate fresh collaborators and the service under test before every
  /// individual test so that no state bleeds between tests.
  setUp(() {
    clock = FakeClock(kStart);
    repo = FakeTimeEntryRepository();
    sut = TimeTrackerService(repository: repo, clock: clock);
  });

  // ── 1. TimeEntry domain model ─────────────────────────────────────────────

  group('TimeEntry domain model', () {
    /// Verifies that the [TimeEntry.isRunning] convenience getter accurately
    /// reflects the underlying [TimeEntryStatus] enum value.
    /// Specifically: a freshly-created running entry must report true, and
    /// a copy produced by [copyWith(status: stopped)] must report false.
    /// This getter is used by UI layers and the bloc to decide whether to show
    /// the active-timer indicator, so its correctness is foundational.
    test('isRunning reflects status correctly', () {
      final running = TimeEntry(
        id: 'a',
        startAt: kStart,
        status: TimeEntryStatus.running,
      );
      final stopped = running.copyWith(
        status: TimeEntryStatus.stopped,
        endAt: kStart.add(const Duration(minutes: 10)),
      );

      expect(running.isRunning, isTrue);
      expect(stopped.isRunning, isFalse);
    });

    /// Verifies that [TimeEntry.duration] uses the stored [endAt] timestamp
    /// when it is non-null, completely ignoring the `now` argument passed to
    /// it.  This is the correct behaviour for completed (stopped) entries:
    /// their duration is fixed at stop time and must not drift as real time
    /// advances.  The test passes a wildly-future `now` (99 hours later) to
    /// confirm it has no effect on the result.
    test('duration() uses endAt when present', () {
      final entry = TimeEntry(
        id: 'a',
        startAt: kStart,
        endAt: kStart.add(const Duration(hours: 1, minutes: 30)),
        status: TimeEntryStatus.stopped,
      );
      // endAt is present, so the provided `now` argument is irrelevant
      expect(
        entry.duration(kStart.add(const Duration(hours: 99))),
        const Duration(hours: 1, minutes: 30),
      );
    });

    /// Verifies that [TimeEntry.duration] falls back to the `now` argument
    /// when [endAt] is null (i.e. the entry is still running).
    /// This is how the UI computes a live elapsed time: it passes the current
    /// moment on every frame and expects the returned duration to grow.
    /// The test uses [FakeClock] indirectly (via `fakeNow`) to keep time
    /// deterministic.
    test('duration() falls back to provided now when endAt is null', () {
      final entry = TimeEntry(
        id: 'a',
        startAt: kStart,
        status: TimeEntryStatus.running,
      );
      final fakeNow = kStart.add(const Duration(minutes: 45));
      expect(entry.duration(fakeNow), const Duration(minutes: 45));
    });

    /// Verifies that [TimeEntry.isAssigned] requires *both* [projectId] and
    /// [taskId] to be non-null.  Having only one of the two is not considered
    /// "assigned" because the business rule is that a fully-contextualised
    /// time entry must belong to a task within a project.
    /// Three states are checked: bare entry (false), project-only (false),
    /// both set (true).
    test('isAssigned requires both projectId and taskId', () {
      final bare = TimeEntry(id: 'a', startAt: kStart, status: TimeEntryStatus.running);
      final withProject = bare.copyWith(projectId: 'p1');
      final full = withProject.copyWith(taskId: 't1');

      expect(bare.isAssigned, isFalse);
      expect(withProject.isAssigned, isFalse);
      expect(full.isAssigned, isTrue);
    });

    /// Verifies the special identity-preservation rule in [TimeEntry.copyWith]:
    /// passing an empty string as [id] must *not* replace the existing id.
    /// This guards against accidental id erasure when callers omit the id
    /// argument and the default empty-string sentinel is used.
    test('copyWith preserves original id when new id is empty', () {
      final original = TimeEntry(id: 'original-id', startAt: kStart, status: TimeEntryStatus.running);
      final copy = original.copyWith(id: '');
      expect(copy.id, 'original-id');
    });
  });

  // ── 2. start() ────────────────────────────────────────────────────────────

  group('TimeTrackerService.start()', () {
    /// Verifies that [start()] returns a [TimeEntry] with:
    ///   - status == running  (the timer is live)
    ///   - startAt == clock.now() at the moment of the call (no drift)
    ///   - endAt == null (the entry is open-ended; not yet stopped)
    /// This establishes the minimal contract for a freshly-started timer.
    test('returns a running entry stamped with clock.now()', () async {
      final entry = await sut.start();

      expect(entry.status, TimeEntryStatus.running);
      expect(entry.startAt, kStart);
      expect(entry.endAt, isNull);
    });

    /// Verifies that optional context fields passed to [start()] are correctly
    /// stored on the returned entry.  These fields allow the user to associate
    /// the new session with an existing project, task, and optional free-text
    /// comment without needing a separate update call.
    test('propagates projectId, taskId and comment', () async {
      final entry = await sut.start(
        projectId: 'p1',
        taskId: 't1',
        comment: 'my work',
      );

      expect(entry.projectId, 'p1');
      expect(entry.taskId, 't1');
      expect(entry.comment, 'my work');
    });

    /// Verifies that [start()] does not just return a transient object but
    /// also *writes* the new entry to the repository.  After the call,
    /// [repo.getActive()] must return a non-null entry with running status.
    /// Without this persistence, a restart of the app would lose the active
    /// session.
    test('persists the running entry in the repository', () async {
      await sut.start();

      final active = await repo.getActive();
      expect(active, isNotNull);
      expect(active!.status, TimeEntryStatus.running);
    });

    /// Verifies that each call to [start()] produces a globally-unique,
    /// non-empty UUID.  Two consecutive sessions (start → stop → start) must
    /// not share an id, as id is the primary key used by the repository and
    /// any downstream systems (e.g. sync, analytics).
    test('generates a non-empty, unique id on each call', () async {
      final a = await sut.start();
      await sut.stop();
      final b = await sut.start();

      expect(a.id, isNotEmpty);
      expect(b.id, isNotEmpty);
      expect(a.id, isNot(equals(b.id)));
    });

    /// Verifies that [start()] throws [StateError] if another timer is already
    /// active.  This enforces the single-active-timer invariant: only one
    /// session may run at a time, so attempting to start a second one without
    /// first stopping the current one is a programming error that must fail
    /// loudly rather than silently create a second running entry.
    test('throws StateError when a timer is already running', () async {
      await sut.start();
      expect(() => sut.start(), throwsStateError);
    });
  });

  // ── 3. stop() ─────────────────────────────────────────────────────────────

  group('TimeTrackerService.stop()', () {
    /// Verifies that [stop()] throws [StateError] when there is no active
    /// timer to stop.  Calling stop() with nothing running is a programming
    /// error (the UI should have disabled the stop button), so it must fail
    /// loudly to surface bugs in call-site logic.
    test('throws StateError when no timer is running', () {
      expect(() => sut.stop(), throwsStateError);
    });

    /// Verifies that [stop()] correctly seals the entry by:
    ///   - changing status to [TimeEntryStatus.stopped]
    ///   - setting [endAt] to exactly [clock.now()] at the moment of the call
    /// The fake clock is advanced by 30 minutes before stopping so that a
    /// non-zero, deterministic endAt is observed.  This ensures the service
    /// reads the clock at stop-time rather than at start-time.
    test('returns stopped entry with endAt == clock.now() at stop time', () async {
      await sut.start();

      final stopTime = kStart.add(const Duration(minutes: 30));
      clock.set(stopTime);

      final stopped = await sut.stop();

      expect(stopped.status, TimeEntryStatus.stopped);
      expect(stopped.endAt, stopTime);
    });

    /// Verifies that after [stop()], the repository no longer has an active
    /// entry.  [getActive()] must return null, meaning the service correctly
    /// transitioned the entry out of the "running" bucket.  This prevents a
    /// ghost active entry from blocking future [start()] calls.
    test('active entry is null after stop', () async {
      await sut.start();
      await sut.stop();

      expect(await sut.getActive(), isNull);
    });

    /// Verifies that [stop()] does not *delete* the entry — it merely
    /// transitions its status.  The stopped entry must still be retrievable
    /// via [getAll()], which is required to populate the history list.
    test('stopped entry appears in getAll()', () async {
      await sut.start();
      final stopped = await sut.stop();

      final all = await sut.getAll();
      expect(all.any((e) => e.id == stopped.id), isTrue);
    });
  });

  // ── 4. Elapsed duration lifecycle ─────────────────────────────────────────

  group('Elapsed duration lifecycle', () {
    /// Verifies that a live (running) entry's computed duration increases
    /// proportionally as the clock advances.  This models the behaviour seen
    /// by the UI ticker: it calls [entry.duration(clock.now())] on every
    /// animation frame and expects a monotonically-growing value.
    /// The fake clock is advanced in two 15-minute steps to confirm linearity.
    test('duration grows proportionally as clock advances', () async {
      final entry = await sut.start();

      clock.advance(const Duration(minutes: 15));
      expect(entry.duration(clock.now()), const Duration(minutes: 15));

      clock.advance(const Duration(minutes: 15));
      expect(entry.duration(clock.now()), const Duration(minutes: 30));
    });

    /// Verifies that once an entry is stopped, its duration is permanently
    /// fixed at (endAt - startAt) and does not change no matter how much later
    /// [duration()] is called.  The test queries the duration 10 hours after
    /// the stop event to confirm the sealed value is unaffected by future time.
    /// This invariant is critical for correct history display: completed entries
    /// must show their actual worked time, not a growing counter.
    test('stopped entry duration is fixed (endAt - startAt) regardless of when queried', () async {
      await sut.start();
      clock.advance(const Duration(hours: 2));
      final stopped = await sut.stop();

      // Query 10 hours later — duration must not change
      final later = clock.now().add(const Duration(hours: 10));
      expect(stopped.duration(later), const Duration(hours: 2));
    });

    /// Verifies that [stop()] does not mutate [startAt].  The start timestamp
    /// must be the same on the stopped entry as on the original running entry,
    /// because [startAt] is the authoritative "when did work begin" value used
    /// for billing and reporting.  Any mutation would silently corrupt history.
    test('stop preserves the original startAt', () async {
      final entry = await sut.start();
      clock.advance(const Duration(hours: 1));
      final stopped = await sut.stop();

      expect(stopped.startAt, entry.startAt);
    });

    /// End-to-end lifecycle test that chains start → advance → stop and
    /// confirms the resulting entry carries the exact duration implied by the
    /// clock advance (45 minutes).  This exercises the full path through the
    /// service and repository without any intermediate assertions, validating
    /// that the three operations compose correctly.
    test('full lifecycle: start → 45 min elapsed → stop → correct duration', () async {
      await sut.start();
      clock.advance(const Duration(minutes: 45));
      final stopped = await sut.stop();

      expect(
        stopped.endAt!.difference(stopped.startAt),
        const Duration(minutes: 45),
      );
    });
  });

  // ── 5. updateActive() ─────────────────────────────────────────────────────

  group('TimeTrackerService.updateActive()', () {
    /// Verifies that [updateActive()] throws [StateError] when there is no
    /// active timer.  Updating a non-existent active entry is a programming
    /// error (the UI should only show the edit form when a timer is running),
    /// so it must fail loudly.
    test('throws StateError when no timer is running', () {
      expect(() => sut.updateActive(projectId: 'p1'), throwsStateError);
    });

    /// Verifies that [updateActive()] patches the running entry's context
    /// fields ([projectId], [taskId], [comment]) in place without changing
    /// its [status].  Users commonly start a timer first and assign it to a
    /// project/task mid-session; this operation must not accidentally stop
    /// the timer.
    test('updates fields on the running entry', () async {
      await sut.start();
      final updated = await sut.updateActive(
        projectId: 'p2',
        taskId: 't2',
        comment: 'updated comment',
      );

      expect(updated.projectId, 'p2');
      expect(updated.taskId, 't2');
      expect(updated.comment, 'updated comment');
      expect(updated.status, TimeEntryStatus.running);
    });

    /// Verifies that the updated fields are durably written to the repository,
    /// not just returned as a transient value.  After [updateActive()], a fresh
    /// [getActive()] call must see the new [projectId] and [taskId].  Without
    /// this, an app restart would revert the user's changes.
    test('updated fields are reflected in getActive()', () async {
      await sut.start();
      await sut.updateActive(projectId: 'p99', taskId: 't99');

      final active = await sut.getActive();
      expect(active!.projectId, 'p99');
      expect(active.taskId, 't99');
    });
  });

  // ── 6. CRUD helpers ───────────────────────────────────────────────────────

  group('CRUD helpers', () {
    /// Verifies that [deleteEntry(id)] permanently removes the entry from the
    /// repository.  After deletion, [getAll()] must not contain an entry with
    /// the deleted id.  This is the primary mechanism for users correcting
    /// accidentally-started timers or removing erroneous history entries.
    test('deleteEntry removes entry from repository', () async {
      final entry = await sut.start();
      await sut.stop();

      await sut.deleteEntry(entry.id);

      final all = await sut.getAll();
      expect(all.any((e) => e.id == entry.id), isFalse);
    });

    /// Verifies that [createEntry()] auto-assigns a new UUID when the supplied
    /// entry has an empty id.  This covers the "manual entry" flow where the
    /// user creates a past time entry from scratch via the history editor.
    /// The caller should not have to generate the id themselves; the service
    /// must produce a non-empty, valid id before persisting.
    test('createEntry generates a new id when entry id is empty', () async {
      final bare = TimeEntry(id: '', startAt: kStart, status: TimeEntryStatus.stopped);
      await sut.createEntry(bare);

      final all = await sut.getAll();
      expect(all.length, 1);
      expect(all.first.id, isNotEmpty);
    });

    /// Verifies that [createEntry()] preserves a caller-supplied id when it is
    /// non-empty.  This is needed for sync/import flows where the id is the
    /// canonical identifier assigned by an external system and must not be
    /// overwritten on the local device.
    test('createEntry preserves explicit id', () async {
      final entry = TimeEntry(id: 'explicit-id', startAt: kStart, status: TimeEntryStatus.stopped);
      await sut.createEntry(entry);

      expect((await sut.getAll()).first.id, 'explicit-id');
    });

    /// Verifies that [updateEntry()] writes field changes through to the
    /// repository.  The test seeds an entry directly (bypassing the service)
    /// and then calls [updateEntry()] with a mutated copy.  A subsequent
    /// [getAll()] must reflect the new [comment] value, confirming that the
    /// repository's update path is exercised end-to-end.
    test('updateEntry persists field changes', () async {
      final entry = TimeEntry(id: 'u1', startAt: kStart, status: TimeEntryStatus.stopped);
      repo.seed(entry);

      await sut.updateEntry(entry.copyWith(comment: 'after update'));

      final all = await sut.getAll();
      expect(all.firstWhere((e) => e.id == 'u1').comment, 'after update');
    });
  });
}
