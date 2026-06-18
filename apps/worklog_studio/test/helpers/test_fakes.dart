// ignore_for_file: depend_on_referenced_packages

/// Test helpers shared across all test files.
///
/// Provides two pure in-memory test doubles that replace real infrastructure
/// without any platform code, database I/O, or network calls:
///
///   • [FakeClock]               – deterministic, manually-controllable time source.
///   • [FakeTimeEntryRepository] – in-memory list-backed implementation of
///                                 [TimeEntryRepository] with extra test-seeding helpers.
///
/// Why fakes instead of mocks?
/// Fakes are preferred here because both collaborators have non-trivial stateful
/// behaviour (advancing time, maintaining a list of entries) that is central to
/// the domain logic being tested.  A mock would force each test to re-specify
/// that behaviour as stub calls, making tests brittle and repetitive.  With a
/// fake, the test simply manipulates state directly and lets the real logic run.
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/time_tracker.dart';

// ---------------------------------------------------------------------------
// FakeClock
// ---------------------------------------------------------------------------

/// A deterministic implementation of [Clock] for use in tests.
///
/// Wraps a [DateTime] value that starts at whatever moment the test supplies
/// and only changes when the test explicitly calls [advance] or [set].
/// This makes every call to [now()] fully predictable, eliminating flakiness
/// that would arise from reading [DateTime.now()] in production code.
///
/// Usage in tests:
/// ```dart
/// final clock = FakeClock(DateTime(2025, 1, 1, 9));
/// clock.advance(const Duration(hours: 1)); // now == 10:00
/// clock.set(DateTime(2025, 6, 1));         // jump to a specific moment
/// ```
class FakeClock implements Clock {
  DateTime _now;

  FakeClock(this._now);

  /// Returns the current frozen time without reading the system clock.
  @override
  DateTime now() => _now;

  /// Moves the frozen time forward by [duration].
  /// Simulates the passage of time between two operations in a test without
  /// actually waiting (e.g. between start() and stop()).
  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  /// Jumps the frozen time to an arbitrary [value].
  /// Useful when a test needs a specific stop-time rather than a relative offset.
  void set(DateTime value) {
    _now = value;
  }
}

// ---------------------------------------------------------------------------
// FakeTimeEntryRepository
// ---------------------------------------------------------------------------

/// A pure in-memory implementation of [TimeEntryRepository] for use in tests.
///
/// Stores [TimeEntry] objects in a plain [List] — no SQLite, no platform
/// channels, no disk I/O.  The implementation mirrors the invariants that the
/// production SQLite repository enforces:
///
///   • Only one entry may have [TimeEntryStatus.running] at any moment.
///     Attempting to insert a second running entry throws [StateError].
///   • [update] throws [StateError] if the entry does not already exist,
///     preventing silent data loss.
///   • [getActive] returns `null` (not an exception) when no running entry exists.
///
/// Extra test-only helpers:
///   • [seed]  – bypass [insert]'s invariant check and add an entry directly.
///               Used to pre-populate the store before the system-under-test runs.
///   • [all]   – synchronous read-only view of the store for concise assertions.
class FakeTimeEntryRepository implements TimeEntryRepository {
  final List<TimeEntry> _store = [];

  /// Returns the single [TimeEntryStatus.running] entry, or `null` if none exists.
  /// Mirrors the production contract: callers must handle the null case.
  @override
  Future<TimeEntry?> getActive() async {
    try {
      return _store.firstWhere((e) => e.status == TimeEntryStatus.running);
    } catch (_) {
      return null;
    }
  }

  /// Returns an unmodifiable snapshot of all stored entries.
  @override
  Future<List<TimeEntry>> getAll() async => List.unmodifiable(_store);

  /// Adds [entry] to the store.
  /// Throws [StateError] if [entry] is running and another running entry already
  /// exists, matching the uniqueness constraint enforced by production storage.
  @override
  Future<void> insert(TimeEntry entry) async {
    final running = await getActive();
    if (entry.status == TimeEntryStatus.running && running != null) {
      throw StateError('Only one running entry allowed');
    }
    _store.add(entry);
  }

  /// Replaces the existing entry with the same [TimeEntry.id].
  /// Throws [StateError] if no matching entry is found, preventing silent no-ops.
  @override
  Future<void> update(TimeEntry entry) async {
    final idx = _store.indexWhere((e) => e.id == entry.id);
    if (idx == -1) throw StateError('TimeEntry not found: ${entry.id}');
    _store[idx] = entry;
  }

  /// Removes the entry with the given [id] from the store.
  /// Silently succeeds if no matching entry is found (mirrors SQL DELETE semantics).
  @override
  Future<void> delete(String id) async {
    _store.removeWhere((e) => e.id == id);
  }

  // ── Test-only helpers ───────────────────────────────────────────────────

  /// Synchronous read-only snapshot of the store.
  /// Useful for concise post-condition assertions without await.
  List<TimeEntry> get all => List.unmodifiable(_store);

  /// Bypasses [insert]'s running-entry uniqueness check and appends [entry]
  /// directly.  Use this to set up preconditions that would otherwise require
  /// calling the service layer (e.g. seeding a running entry before testing stop()).
  void seed(TimeEntry entry) => _store.add(entry);
}
