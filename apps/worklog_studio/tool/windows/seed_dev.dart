// ignore_for_file: avoid_print
// Dev-database seeder for Windows. Run from apps\worklog_studio:
//   fvm dart run tool/windows/seed_dev.dart
//
// Fills the DEVELOPMENT flavor database
// (%APPDATA%\com.example\worklog_studio\Worklog_studio-dev\worklog.db)
// with two months of believable activity for one person: a day job,
// a pet project, freelance gigs, learning and personal time.
// The previous DB file is backed up to backups\ before anything is touched.

import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:worklog_studio/data/sqlite/db_create.dart';

const _uuid = Uuid();
final _random = Random(42);

String _dbPath() {
  final appData = Platform.environment['APPDATA'];
  if (appData == null) throw Exception('APPDATA is not set');
  return join(
    appData,
    'com.example',
    'worklog_studio',
    'Worklog_studio-dev',
    'worklog.db',
  );
}

// ---------------------------------------------------------------------------
// Dataset description
// ---------------------------------------------------------------------------

class _Project {
  final String id = _uuid.v4();
  final String name;
  final String description;
  _Project(this.name, this.description);
}

class _Task {
  final String id = _uuid.v4();
  final _Project project;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<String> comments;
  _Task(
    this.project,
    this.title,
    this.description, {
    required this.createdAt,
    this.completedAt,
    required this.comments,
  });
}

class _Entry {
  final _Task task;
  final DateTime start;
  final DateTime end;
  final String comment;
  _Entry(this.task, this.start, this.end, this.comment);
}

T _pick<T>(List<T> list) => list[_random.nextInt(list.length)];
int _mins(int min, int max) => min + _random.nextInt(max - min + 1);

// ---------------------------------------------------------------------------

Future<void> main() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final dbPath = _dbPath();
  print('Target dev database: $dbPath');

  final dbFile = File(dbPath);
  if (await dbFile.exists()) {
    final backupsDir = Directory(join(dirname(dbPath), 'backups'));
    await backupsDir.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final backupPath = join(backupsDir.path, 'worklog-pre-seed-$stamp.db');
    await dbFile.copy(backupPath);
    print('Backup written: $backupPath');
  } else {
    await Directory(dirname(dbPath)).create(recursive: true);
    print('No existing dev DB, a fresh one will be created.');
  }

  final db = await factory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(version: 3, onCreate: onCreate),
  );

  final oldCounts = <String, int>{};
  for (final table in ['projects', 'tasks', 'time_entries']) {
    final row = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    oldCounts[table] = row.first['c'] as int;
  }
  print('Existing rows (will be replaced): $oldCounts');

  await db.delete('time_entries');
  await db.delete('tasks');
  await db.delete('projects');

  // -------------------------------------------------------------------------
  // Projects
  // -------------------------------------------------------------------------
  final work = _Project(
    'Nimbus CRM (day job)',
    'Main job: B2B CRM for logistics. Sprints, the payments module, reports and endless meetings.',
  );
  final pet = _Project(
    'Pet: Habitly',
    'My own habit tracker in Flutter. Evening dream project: one day it ships to the store.',
  );
  final freelance = _Project(
    'Freelance',
    'Upwork gigs and friends-of-friends work: landing pages, small fixes, client calls.',
  );
  final learning = _Project(
    'Learning',
    'Rust, LeetCode, articles and talks, so the brain does not rust.',
  );
  final personal = _Project(
    'Personal',
    'Gym, English, books and the rest of life outside the code.',
  );
  final projects = [work, pet, freelance, learning, personal];

  // -------------------------------------------------------------------------
  // Tasks (creation dates roughly match when they first appear in the log)
  // -------------------------------------------------------------------------
  final d0 = DateTime(2026, 5, 18); // first seeded Monday

  final tStripe = _Task(
    work,
    'Payments module (Stripe)',
    'Subscriptions, webhooks, invoices. Everything that involves money and pain.',
    createdAt: d0,
    comments: [
      'Stripe webhooks delivered another surprise, digging in',
      'beat the double-charge on retries, proud of myself',
      'reading the subscription docs, written by geniuses and sadists at once',
      'test payments in the sandbox, all green',
      'wired up proration for plan upgrades',
      'chased a race between the webhook and the redirect, caught it',
      'invoices finally match accounting to the cent',
    ],
  );
  final tBugs = _Task(
    work,
    'Sprint bugfixes',
    'Cleaning up the board after releases. It never ends.',
    createdAt: d0,
    comments: [
      'the timezone bug. I won, but at what cost',
      'Friday evening hotfix, a classic',
      'closed three tickets, opened two. net plus one',
      'reproduced the flaky bug on attempt number 14',
      'fixed pagination, broke sorting, fixed both',
      'null pointer in prod. blaming the 2024 intern (it was me)',
    ],
  );
  final tMeetings = _Task(
    work,
    'Meetings & planning',
    'Standups, groomings, retros and other sync rituals.',
    createdAt: d0,
    comments: [
      'standup turned into an hour-long architecture debate',
      'grooming: estimated 3 points, everyone knows it will be 8',
      'retro: decided to have fewer meetings (during a meeting)',
      'sprint planning, overcommitted like the last time',
      'client demo, nothing crashed, astonishing',
      'one-on-one with the lead, talked about growth',
    ],
  );
  final tReview = _Task(
    work,
    'Code review',
    'Colleagues PRs and the eternal naming debates.',
    createdAt: d0,
    comments: [
      'reviewed a 2k-line PR, my eyes filed a complaint',
      'argued about naming for half an hour, friendship won (and my variant)',
      'found commented-out code from 2023 in a PR, gave a guided tour',
      'approved on the first pass, the team is growing',
      'left 27 comments, feeling like a pedant. a useful pedant',
    ],
  );
  final tRefactor = _Task(
    work,
    'Reports module refactoring',
    'The legacy reports module: removing crutches older than my tenure.',
    createdAt: d0,
    completedAt: DateTime(2026, 7, 3, 18, 30),
    comments: [
      'deleted a 1800-line god class, breathing got easier',
      'covered it with tests before digging, no minesweeping without a detector',
      'found a TODO from 2022: "redo this properly". redone',
      'extracted PDF generation into its own service',
      'final run: the new reports match the old ones to the cent',
    ],
  );
  final tOnboarding = _Task(
    work,
    'Junior onboarding',
    'Mentoring: pair programming and answering "why is it like this here".',
    createdAt: DateTime(2026, 6, 15),
    comments: [
      'pair programming, the junior knows more than he admits',
      'explained our architecture, understood two places myself in the process',
      'went through his first PR, it was almost painless',
      'environment setup took half a day because of the antivirus, as usual',
      'gave him a stretch task, he finished faster than I would. concerning',
    ],
  );

  final tPetStats = _Task(
    pet,
    'Statistics screen',
    'Streak charts, an activity heatmap and pretty numbers.',
    createdAt: d0,
    comments: [
      'building the streak heatmap, looks decent already',
      'debugged an animation for three hours, forgot about hot restart',
      'moved the state to cubits, the code breathes easier',
      'picked a palette for the charts, my inner designer approves',
      'edge case: a habit created at 23:59. I hate time',
    ],
  );
  final tPetSync = _Task(
    pet,
    'Cloud sync',
    'Firebase, offline mode and merge conflicts, obviously.',
    createdAt: DateTime(2026, 5, 30),
    comments: [
      'the offline queue works, I can hardly believe it',
      'habit merge conflict: last-write-wins and no drama',
      'firestore security rules, spent an hour in the simulator',
      'sync across two devices matched on the first try. suspicious',
    ],
  );
  final tPetWidget = _Task(
    pet,
    'Desktop widget',
    'A mini widget with streaks for Windows.',
    createdAt: DateTime(2026, 7, 4),
    comments: [
      'researching win32 widgets, fewer options than I hoped',
      'the overlay prototype works, now to make it not crash',
      'the widget survived a reboot, celebrating a small victory',
    ],
  );
  final tPetStore = _Task(
    pet,
    'Icon & landing page',
    'The icon, screenshots and a store page.',
    createdAt: DateTime(2026, 6, 6),
    completedAt: DateTime(2026, 6, 21, 22, 0),
    comments: [
      'drew six icon variants, my wife likes the third one, taking the third one',
      'landing page in a single html file, old school and fast',
      'store screenshots: an hour of moving the status bar by one pixel',
    ],
  );

  final tUpwork = _Task(
    freelance,
    'Lead hunting (Upwork)',
    'Proposals, portfolio updates and chats with prospects.',
    createdAt: d0,
    comments: [
      'sent five proposals, two got read. success',
      'updated the portfolio with the landing page case',
      'client wants "like Airbnb, but in one evening". politely declined',
      'intro call, they seem sane',
      'raised my hourly rate. scary, but overdue',
    ],
  );
  final tDental = _Task(
    freelance,
    'Dental clinic landing page',
    'A one-pager with a booking form for the Smile clinic.',
    createdAt: DateTime(2026, 6, 2),
    completedAt: DateTime(2026, 6, 16, 21, 0),
    comments: [
      'built the hero section, the stock photo teeth are terrifyingly perfect',
      'booking form plus a telegram bot for the leads',
      'client asked to "play with the fonts". played. reverted',
      'mobile layout done, the booking button stopped jumping around',
      'final tweaks and deploy, the clinic is happy',
    ],
  );
  final tCoffee = _Task(
    freelance,
    'Tweaks for the Bean cafe',
    'Small website fixes for a friend (paid in coffee and money).',
    createdAt: DateTime(2026, 7, 7),
    comments: [
      'updated the menu on the site, prices went up, not my doing',
      'added the new location to the map',
      'optimized the photos: was 8 seconds, now 1.5',
    ],
  );
  final tCalls = _Task(
    freelance,
    'Client calls',
    'Specs, demos and "quick five-minute calls".',
    createdAt: DateTime(2026, 5, 23),
    comments: [
      'the "five minutes" lasted fifty, but the spec is clearer now',
      'landing page demo, client happy, advance payment received',
      'discussed the changes, wrote everything down to avoid "but we agreed"',
    ],
  );

  final tRust = _Task(
    learning,
    'Rust course',
    'The Rust Book plus exercises. The borrow checker is winning so far.',
    createdAt: d0,
    comments: [
      'the ownership chapter, I think it finally clicked',
      'the borrow checker rejected my code 12 times, on the 13th I understood why',
      'wrote a small CLI tool, it compiles so it works',
      'lifetimes. I will just leave this here',
      'finished the chapter exercises, feeling like a systems programmer',
    ],
  );
  final tLeet = _Task(
    learning,
    'LeetCode',
    'Morning warm-up: one problem a day.',
    createdAt: d0,
    comments: [
      'an easy one in 10 minutes, feeling like a genius',
      'a medium with a hint, but I solved it myself! almost',
      'failed a hard one, self-esteem at the bottom, but the streak lives',
      'two pointers, finally spotting them instantly',
      'a DP problem, read the solution, still magic to me',
    ],
  );
  final tArticles = _Task(
    learning,
    'Articles & talks',
    'HackerNews and conference talks at 1.5x speed.',
    createdAt: DateTime(2026, 5, 21),
    comments: [
      'a talk on frontend architecture, stole a couple of ideas for work',
      'an article on postgres indexes, finally understood partial indexes',
      'an hour on HackerNews, calling it research',
      'watched a conference talk, the speaker was on fire',
    ],
  );

  final tGym = _Task(
    personal,
    'Gym',
    'Mon/Wed/Fri, full-body. Progress happens, the back stays silent for now.',
    createdAt: d0,
    comments: [
      'leg day. stairs are cancelled tomorrow',
      'new deadlift PR, back, please hold on',
      'a light session, yesterday\'s hotfix took all my strength',
      'cardio and stretching, felt human again',
      'the gym was packed, waited half the workout for a bench',
    ],
  );
  final tEnglish = _Task(
    personal,
    'English lessons',
    'A tutor on Tue/Thu plus Anki when in the mood.',
    createdAt: d0,
    comments: [
      'conditionals: "would have been" is simply too much',
      'speaking practice about work, explained what code review is, proud',
      'did the homework 10 minutes before the lesson, school habits are forever',
      'new idioms, now trying to sneak "piece of cake" everywhere',
    ],
  );
  final tReading = _Task(
    personal,
    'Reading',
    'Fiction before sleep instead of doomscrolling.',
    createdAt: DateTime(2026, 5, 20),
    comments: [
      'a chapter of Project Hail Mary, could not put it down',
      'half an hour of reading instead of the feed, a small win',
      'finished a chapter, no spoilers, not even for myself',
      'read a bit, fell asleep on page three, still counts',
    ],
  );
  final tFinance = _Task(
    personal,
    'Finances',
    'Monthly budget and portfolio review.',
    createdAt: DateTime(2026, 6, 1),
    comments: [
      'monthly spending review, food delivery leads again',
      'portfolio rebalancing, boring and correct',
      'counted the emergency fund, almost at the goal',
    ],
  );

  final tasks = [
    tStripe, tBugs, tMeetings, tReview, tRefactor, tOnboarding,
    tPetStats, tPetSync, tPetWidget, tPetStore,
    tUpwork, tDental, tCoffee, tCalls,
    tRust, tLeet, tArticles,
    tGym, tEnglish, tReading, tFinance,
  ];

  // -------------------------------------------------------------------------
  // Timeline generation: May 18 .. July 17, cursor per day, no overlaps.
  // -------------------------------------------------------------------------
  final entries = <_Entry>[];
  final tripStart = DateTime(2026, 6, 26); // Fri..Sun city trip, almost no log
  final tripEnd = DateTime(2026, 6, 28);

  void add(_Task task, DateTime start, int minutes) {
    entries.add(_Entry(
      task,
      start,
      start.add(Duration(minutes: minutes)),
      _pick(task.comments),
    ));
  }

  for (var day = d0;
      !day.isAfter(DateTime(2026, 7, 17));
      day = day.add(const Duration(days: 1))) {
    final isTrip = !day.isBefore(tripStart) && !day.isAfter(tripEnd);
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final isToday = day.year == 2026 && day.month == 7 && day.day == 17;

    if (isTrip) {
      // Vacation trip: only some evening reading on Saturday.
      if (day.weekday == DateTime.saturday) {
        add(tReading, day.add(const Duration(hours: 22, minutes: 15)), 30);
      }
      continue;
    }

    if (!isWeekend) {
      // ----- Weekday -----
      var cursor = day.add(Duration(hours: 8, minutes: 40 + _random.nextInt(20)));

      // Morning LeetCode about half the days.
      if (_random.nextDouble() < 0.55) {
        final m = _mins(20, 40);
        add(tLeet, cursor, m);
        cursor = cursor.add(Duration(minutes: m + _mins(10, 20)));
      } else {
        cursor = day.add(Duration(hours: 9, minutes: 20 + _random.nextInt(20)));
      }

      // Standup / planning.
      final standup = _mins(15, day.weekday == DateTime.monday ? 60 : 35);
      add(tMeetings, cursor, standup);
      cursor = cursor.add(Duration(minutes: standup + _mins(5, 15)));

      // Morning deep-work block. Today gets a shorter one that ends around
      // the time this seeder runs, so nothing sits in the future.
      final morningTask = day.isBefore(DateTime(2026, 7, 4))
          ? _pick([tStripe, tStripe, tRefactor, tBugs])
          : _pick([tStripe, tStripe, tBugs]);
      final morning = isToday ? 80 : _mins(95, 150);
      add(morningTask, cursor, morning);
      if (isToday) continue;
      cursor = cursor.add(Duration(minutes: morning + _mins(45, 70))); // lunch

      // Afternoon block(s).
      final afternoonTask = day.weekday == DateTime.friday
          ? _pick([tReview, tReview, tBugs])
          : _pick([tStripe, tBugs, tReview]);
      final afternoon = _mins(100, 170);
      add(afternoonTask, cursor, afternoon);
      cursor = cursor.add(Duration(minutes: afternoon + _mins(10, 25)));

      // Onboarding sessions from June 15, ~3 times a week.
      if (!day.isBefore(tOnboarding.createdAt) && _random.nextDouble() < 0.5) {
        final m = _mins(40, 80);
        add(tOnboarding, cursor, m);
        cursor = cursor.add(Duration(minutes: m + _mins(10, 20)));
      }

      // Short wrap-up block some days.
      if (_random.nextDouble() < 0.6) {
        final m = _mins(35, 75);
        add(_pick([tBugs, tReview, tStripe]), cursor, m);
        cursor = cursor.add(Duration(minutes: m));
      }

      // ----- Weekday evening (never overlaps a long work day) -----
      var evening = day.add(Duration(hours: 19, minutes: _random.nextInt(30)));
      if (!cursor.isBefore(evening)) {
        evening = cursor.add(Duration(minutes: _mins(35, 60)));
      }

      if (day.weekday == DateTime.monday ||
          day.weekday == DateTime.wednesday ||
          day.weekday == DateTime.friday) {
        final m = _mins(55, 85);
        add(tGym, evening, m);
        evening = evening.add(Duration(minutes: m + _mins(30, 50)));
      } else if (day.weekday == DateTime.tuesday ||
          day.weekday == DateTime.thursday) {
        add(tEnglish, evening, 60);
        evening = evening.add(Duration(minutes: 60 + _mins(20, 40)));
      }

      // Freelance bursts on weekday evenings.
      final inDental = !day.isBefore(DateTime(2026, 6, 2)) &&
          day.isBefore(DateTime(2026, 6, 16));
      final inCoffee = !day.isBefore(DateTime(2026, 7, 7)) &&
          day.isBefore(DateTime(2026, 7, 13));
      if (inDental && _random.nextDouble() < 0.6) {
        final m = _mins(50, 95);
        add(tDental, evening, m);
        evening = evening.add(Duration(minutes: m + _mins(10, 20)));
      } else if (inCoffee && _random.nextDouble() < 0.6) {
        final m = _mins(40, 80);
        add(tCoffee, evening, m);
        evening = evening.add(Duration(minutes: m + _mins(10, 20)));
      } else if (_random.nextDouble() < 0.45) {
        // Pet project or upwork or an article.
        final choice = _random.nextDouble();
        final int m;
        final _Task eveningTask;
        if (choice < 0.55) {
          eveningTask = !day.isBefore(tPetWidget.createdAt)
              ? _pick([tPetStats, tPetSync, tPetWidget])
              : (!day.isBefore(tPetSync.createdAt)
                  ? _pick([tPetStats, tPetSync])
                  : tPetStats);
          m = _mins(60, 120);
        } else if (choice < 0.8) {
          eveningTask = tUpwork;
          m = _mins(25, 55);
        } else {
          eveningTask = tArticles;
          m = _mins(30, 60);
        }
        add(eveningTask, evening, m);
        evening = evening.add(Duration(minutes: m));
      }

      // Late reading some nights, never before the evening block ends.
      if (_random.nextDouble() < 0.5) {
        var readStart =
            day.add(Duration(hours: 22, minutes: 30 + _random.nextInt(25)));
        if (!evening.isBefore(readStart)) {
          readStart = evening.add(Duration(minutes: _mins(10, 25)));
        }
        add(tReading, readStart, _mins(20, 45));
      }
    } else {
      // ----- Weekend -----
      var cursor = day.add(Duration(hours: 10, minutes: 30 + _random.nextInt(60)));

      // Rust course most weekend mornings.
      if (_random.nextDouble() < 0.7) {
        final m = _mins(60, 100);
        add(tRust, cursor, m);
        cursor = cursor.add(Duration(minutes: m + _mins(30, 60)));
      }

      // The dental landing burst took over two June weekends.
      final inDental = !day.isBefore(DateTime(2026, 6, 6)) &&
          day.isBefore(DateTime(2026, 6, 15));
      if (inDental) {
        final m = _mins(120, 200);
        add(tDental, cursor, m);
        cursor = cursor.add(Duration(minutes: m + _mins(40, 80)));
      } else if (_random.nextDouble() < 0.75) {
        // Pet project afternoon.
        final petTask = !day.isBefore(tPetStore.createdAt) &&
                day.isBefore(DateTime(2026, 6, 22)) &&
                _random.nextDouble() < 0.4
            ? tPetStore
            : (!day.isBefore(tPetWidget.createdAt)
                ? _pick([tPetStats, tPetSync, tPetWidget])
                : (!day.isBefore(tPetSync.createdAt)
                    ? _pick([tPetStats, tPetSync])
                    : tPetStats));
        final m = _mins(90, 180);
        add(petTask, cursor, m);
        cursor = cursor.add(Duration(minutes: m + _mins(30, 60)));
      }

      // Client call on some Saturdays.
      if (day.weekday == DateTime.saturday && _random.nextDouble() < 0.4) {
        add(tCalls, cursor, _mins(25, 50));
        cursor = cursor.add(Duration(minutes: 60));
      }

      // Saturday gym sometimes (pushed later if the day ran long).
      if (day.weekday == DateTime.saturday && _random.nextDouble() < 0.5) {
        var gymStart = day.add(const Duration(hours: 17, minutes: 30));
        if (!cursor.isBefore(gymStart)) {
          gymStart = cursor.add(Duration(minutes: _mins(20, 40)));
        }
        add(tGym, gymStart, _mins(55, 80));
      }

      // Monthly finance review on the first weekend of the month.
      if (day.day <= 7 && day.weekday == DateTime.sunday) {
        add(tFinance, day.add(const Duration(hours: 18)), _mins(35, 55));
      }

      // Evening reading.
      if (_random.nextDouble() < 0.6) {
        add(tReading, day.add(Duration(hours: 22, minutes: _random.nextInt(40))),
            _mins(25, 50));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Inserts
  // -------------------------------------------------------------------------
  final projectCreated =
      DateTime(2026, 5, 16, 12, 0).millisecondsSinceEpoch;
  for (final p in projects) {
    await db.insert('projects', {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'created_at': projectCreated,
      'archived_at': null,
    });
  }

  for (final t in tasks) {
    await db.insert('tasks', {
      'id': t.id,
      'project_id': t.project.id,
      'title': t.title,
      'description': t.description,
      'status': t.completedAt == null ? 'open' : 'done',
      'created_at': t.createdAt
          .add(const Duration(hours: 9))
          .millisecondsSinceEpoch,
      'completed_at': t.completedAt?.millisecondsSinceEpoch,
    });
  }

  final batch = db.batch();
  for (final e in entries) {
    batch.insert('time_entries', {
      'id': _uuid.v4(),
      'project_id': e.task.project.id,
      'task_id': e.task.id,
      'comment': e.comment,
      'start_at': e.start.millisecondsSinceEpoch,
      'end_at': e.end.millisecondsSinceEpoch,
      'status': 'stopped',
    });
  }
  await batch.commit(noResult: true);

  // -------------------------------------------------------------------------
  // Summary
  // -------------------------------------------------------------------------
  final perProject = <String, int>{};
  for (final e in entries) {
    perProject[e.task.project.name] =
        (perProject[e.task.project.name] ?? 0) +
            e.end.difference(e.start).inMinutes;
  }
  print('Seeded ${projects.length} projects, ${tasks.length} tasks, '
      '${entries.length} time entries.');
  perProject.forEach((name, minutes) {
    final h = (minutes / 60).toStringAsFixed(1);
    print('  $name: ${h}h');
  });

  await db.close();
  print('DONE');
}
