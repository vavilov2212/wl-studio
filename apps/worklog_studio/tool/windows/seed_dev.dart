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
    'Nimbus CRM (работа)',
    'Основная работа: B2B CRM для логистики. Спринты, платёжный модуль, отчёты и бесконечные созвоны.',
  );
  final pet = _Project(
    'Pet: Habitly',
    'Свой трекер привычек на Flutter. Вечерний проект мечты: однажды он доедет до стора.',
  );
  final freelance = _Project(
    'Фриланс',
    'Заказы с Upwork и по знакомым: лендинги, правки, созвоны с заказчиками.',
  );
  final learning = _Project(
    'Обучение',
    'Rust, LeetCode, статьи и доклады, чтобы мозг не заржавел.',
  );
  final personal = _Project(
    'Личное',
    'Спорт, английский, книги и прочая жизнь вне кода.',
  );
  final projects = [work, pet, freelance, learning, personal];

  // -------------------------------------------------------------------------
  // Tasks (creation dates roughly match when they first appear in the log)
  // -------------------------------------------------------------------------
  final d0 = DateTime(2026, 5, 18); // first seeded Monday

  final tStripe = _Task(
    work,
    'Платёжный модуль (Stripe)',
    'Подписки, вебхуки, инвойсы. Всё, что связано с деньгами и болью.',
    createdAt: d0,
    comments: [
      'вебхуки Stripe опять прислали сюрприз, разбираюсь',
      'победил double-charge при ретраях, горжусь собой',
      'читаю доки по подпискам. их писали гении и садисты одновременно',
      'тестовые платежи в песочнице, полёт нормальный',
      'прикрутил прорейт при апгрейде тарифа',
      'ловил race между вебхуком и редиректом, поймал',
      'инвойсы наконец сходятся с бухгалтерией до копейки',
    ],
  );
  final tBugs = _Task(
    work,
    'Багфиксы спринта',
    'Разгребание борды после релизов. Она не кончается никогда.',
    createdAt: d0,
    comments: [
      'баг с таймзонами. я выиграл, но какой ценой',
      'hotfix в пятницу вечером, классика жанра',
      'закрыл три тикета, открыл два. итого плюс один',
      'воспроизвёл плавающий баг с 14-й попытки',
      'чинил пагинацию, сломал сортировку, починил обе',
      'null pointer в проде. виноват, конечно, стажёр из 2024-го (это был я)',
    ],
  );
  final tMeetings = _Task(
    work,
    'Созвоны и планирование',
    'Стендапы, груминги, ретро и прочий синхрон.',
    createdAt: d0,
    comments: [
      'стендап перерос в архитектурный спор на час',
      'груминг: оценили задачу в 3 поинта, все знают, что будет 8',
      'ретро: решили меньше созваниваться. на созвоне',
      'планирование спринта, набрали как в последний раз',
      'демо для заказчика, ничего не упало, поразительно',
      'один-на-один с тимлидом, обсудили рост',
    ],
  );
  final tReview = _Task(
    work,
    'Код-ревью',
    'PR коллег и вечные споры о нейминге.',
    createdAt: d0,
    comments: [
      'ревью PR на 2к строк. глаза устали, душа тоже',
      'полчаса спорили про нейминг, победила дружба (и мой вариант)',
      'нашёл в PR закомментированный код 2023 года, провёл экскурсию',
      'апрувнул с первого раза, коллега растёт',
      'оставил 27 комментариев, чувствую себя занудой. полезным занудой',
    ],
  );
  final tRefactor = _Task(
    work,
    'Рефакторинг отчётов',
    'Legacy-модуль отчётов: выпиливание костылей, которые старше меня в компании.',
    createdAt: d0,
    completedAt: DateTime(2026, 7, 3, 18, 30),
    comments: [
      'снёс божественный класс на 1800 строк, стало легче дышать',
      'покрыл тестами перед раскопками, сапёр без миноискателя не ходит',
      'нашёл TODO от 2022 года: "переделать по-нормальному". переделал',
      'вынес генерацию PDF в отдельный сервис',
      'финальный прогон: отчёты сходятся со старыми до копейки',
    ],
  );
  final tOnboarding = _Task(
    work,
    'Онбординг джуна',
    'Менторство: парное программирование и ответы на "а почему тут так".',
    createdAt: DateTime(2026, 6, 15),
    comments: [
      'парное программирование, джун шарит больше, чем признаётся',
      'объяснял нашу архитектуру. в процессе сам понял пару мест',
      'разобрали его первый PR, было почти не больно',
      'настроили окружение. полдня из-за антивируса, как обычно',
      'дал задачку со звёздочкой, справился быстрее меня. тревожно',
    ],
  );

  final tPetStats = _Task(
    pet,
    'Экран статистики',
    'Графики стриков, heatmap активности и красивые цифры.',
    createdAt: d0,
    comments: [
      'пилю heatmap стриков, выглядит уже прилично',
      'три часа дебажил анимацию. забыл про hot restart',
      'переписал стейт на кубиты, дышать стало легче',
      'подобрал палитру для графиков, дизайнер во мне доволен',
      'edge case: привычка, созданная в 23:59. ненавижу время',
    ],
  );
  final tPetSync = _Task(
    pet,
    'Синхронизация с облаком',
    'Firebase, офлайн-режим и конфликты, куда без них.',
    createdAt: DateTime(2026, 5, 30),
    comments: [
      'офлайн-очередь работает, я почти не верю',
      'конфликт мержа привычек: last-write-wins и не выпендриваться',
      'firestore правила безопасности, час втыкал в симулятор',
      'синк на двух устройствах сошёлся с первого раза. подозрительно',
    ],
  );
  final tPetWidget = _Task(
    pet,
    'Виджет на рабочий стол',
    'Мини-виджет со стриками для Windows.',
    createdAt: DateTime(2026, 7, 4),
    comments: [
      'ресёрч по win32-виджетам, вариантов меньше, чем хотелось',
      'прототип оверлея готов, осталось чтобы не падал',
      'виджет пережил перезагрузку, отмечаю маленькую победу',
    ],
  );
  final tPetStore = _Task(
    pet,
    'Иконка и лендинг',
    'Иконка, скриншоты и страничка для стора.',
    createdAt: DateTime(2026, 6, 6),
    completedAt: DateTime(2026, 6, 21, 22, 0),
    comments: [
      'нарисовал 6 вариантов иконки, жене нравится третья, беру третью',
      'лендинг на одном html-файле, олдскул и быстро',
      'скриншоты для стора, час двигал статусбар на пиксель',
    ],
  );

  final tUpwork = _Task(
    freelance,
    'Поиск заказов (Upwork)',
    'Отклики, портфолио и переписки с потенциальными клиентами.',
    createdAt: d0,
    comments: [
      'разослал 5 откликов, два прочитали. успех',
      'обновил портфолио, добавил кейс с лендингом',
      'клиент хочет "просто как у Airbnb, но за вечер". вежливо отказался',
      'созвон-знакомство, вроде адекватные',
      'поднял ставку в профиле. страшно, но пора',
    ],
  );
  final tDental = _Task(
    freelance,
    'Лендинг для стоматологии',
    'Одностраничник с формой записи для клиники "Улыбка".',
    createdAt: DateTime(2026, 6, 2),
    completedAt: DateTime(2026, 6, 16, 21, 0),
    comments: [
      'сверстал первый экран, зубы на фото пугающе идеальные',
      'форма записи + телеграм-бот для заявок',
      'заказчик попросил "поиграть со шрифтами". поиграл. вернул как было',
      'адаптив под мобилку, кнопка записи теперь не прыгает',
      'финальные правки и деплой, клиника довольна',
    ],
  );
  final tCoffee = _Task(
    freelance,
    'Правки для кофейни "Зерно"',
    'Мелкие доработки сайта по дружбе (за кофе и деньги).',
    createdAt: DateTime(2026, 7, 7),
    comments: [
      'обновил меню на сайте, цены выросли, я тут ни при чём',
      'прикрутил карту с новой точкой',
      'ускорил загрузку фоток, было 8 секунд, стало полторы',
    ],
  );
  final tCalls = _Task(
    freelance,
    'Созвоны с заказчиками',
    'Обсуждение ТЗ, демо и "давайте созвонимся на минутку".',
    createdAt: DateTime(2026, 5, 23),
    comments: [
      '"минутка" длилась 50 минут, но ТЗ стало понятнее',
      'демо лендинга, заказчик доволен, аванс на карте',
      'обсудили правки, записал всё в заметки, чтобы не было "мы же говорили"',
    ],
  );

  final tRust = _Task(
    learning,
    'Курс по Rust',
    'The Rust Book и упражнения. Borrow checker пока побеждает.',
    createdAt: d0,
    comments: [
      'глава про ownership, кажется, начал понимать',
      'borrow checker отверг мой код 12 раз. на 13-й я понял почему',
      'написал CLI-утилиту, компилируется - значит работает',
      'lifetimes. просто оставлю это здесь',
      'решил упражнения главы, чувствую себя системным программистом',
    ],
  );
  final tLeet = _Task(
    learning,
    'LeetCode',
    'Утренняя разминка: одна задача в день.',
    createdAt: d0,
    comments: [
      'easy за 10 минут, чувствую себя гением',
      'medium с подсказкой, но сам! почти',
      'hard не решил, самооценка на дне, зато стрик жив',
      'two pointers, наконец-то вижу их сразу',
      'задача на DP, посмотрел решение, всё ещё магия',
    ],
  );
  final tArticles = _Task(
    learning,
    'Статьи и доклады',
    'HackerNews, хабр и конфы на ютубе на скорости 1.5x.',
    createdAt: DateTime(2026, 5, 21),
    comments: [
      'доклад про архитектуру фронта, украл пару идей для работы',
      'статья про индексы в постгресе, наконец понял partial index',
      'час в HackerNews, оправдываю это словом "ресёрч"',
      'посмотрел доклад с конфы, спикер жёг',
    ],
  );

  final tGym = _Task(
    personal,
    'Спортзал',
    'Пн/ср/пт, full-body. Прогресс есть, спина пока молчит.',
    createdAt: d0,
    comments: [
      'ноги. завтра лестницы отменяются',
      'новый рекорд в становой, спина, держись',
      'лёгкая тренировка, вчерашний хотфикс отнял все силы',
      'кардио и растяжка, почувствовал себя человеком',
      'в зале толпа, полтренировки ждал скамью',
    ],
  );
  final tEnglish = _Task(
    personal,
    'Английский',
    'Репетитор по вт/чт и Anki по настроению.',
    createdAt: d0,
    comments: [
      'разбирали conditionals, would have been - это уже слишком',
      'спикинг про работу, объяснил что такое code review, гордость',
      'домашка за 10 минут до урока, школьные привычки вечны',
      'новые идиомы, пытаюсь ввернуть piece of cake везде',
    ],
  );
  final tReading = _Task(
    personal,
    'Чтение',
    'Художка перед сном, чтобы не листать ленту.',
    createdAt: DateTime(2026, 5, 20),
    comments: [
      'глава "Проекта Аве Мария", не мог оторваться',
      'полчаса чтения вместо ленты, маленькая победа',
      'дочитал главу, спойлерить не буду даже себе',
      'читал, уснул на третьей странице, тоже результат',
    ],
  );
  final tFinance = _Task(
    personal,
    'Финансы',
    'Ежемесячный разбор бюджета и портфеля.',
    createdAt: DateTime(2026, 6, 1),
    comments: [
      'разобрал траты за месяц, доставка еды опять лидирует',
      'ребаланс портфеля, скучно и правильно',
      'посчитал подушку, до цели ещё чуть-чуть',
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
        // Pet project or upwork or article.
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

      // Dental landing burst took over two June weekends.
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

      // Monthly finance review on first weekend of the month.
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
