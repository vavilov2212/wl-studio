// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:worklog_studio/data/sqlite/db_create.dart';

/// SeedService — утилита для наполнения локальной базы данных моковыми данными.
///
/// ⚠️ ВАЖНО: Скрипт запускается через `fvm dart tool/seed.dart`.
/// Он не использует Flutter SDK напрямую, чтобы избежать конфликтов с dart:ui,
/// но имитирует поведение приложения для macOS.
class SeedService {
  static final _uuid = const Uuid();
  static final _random = Random();
  static const _dbName = 'worklog.db';

  /// Определяет путь к базе данных на macOS.
  ///
  /// Имитирует стандартный путь Flutter-пакета sqflite для macOS:
  /// ~/Library/Application Support/[BUNDLE_ID]/worklog.db
  static Future<String> _getDatabasePath() async {
    // 1. Извлекаем Bundle ID динамически из конфигов Xcode.
    // Это гарантирует, что seed всегда пишет в ту же базу, что и запущенное приложение.
    final configFile = File('macos/Runner/Configs/AppInfo.xcconfig');
    String bundleId =
        'com.example.worklogStudio'; // Fallback если файл не найден

    if (await configFile.exists()) {
      final content = await configFile.readAsString();
      final match = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*(.*)',
      ).firstMatch(content);
      if (match != null) {
        bundleId = match.group(1)!.trim();
      }
    }

    // 2. Получаем домашнюю папку текущего пользователя macOS.
    final home = Platform.environment['HOME'];
    if (home == null) throw Exception('Could not find HOME directory');

    // 3. Формируем финальный путь.
    return join(home, 'Library', 'Application Support', bundleId, _dbName);
  }

  /// Основной метод запуска наполнения данных.
  static Future<void> seed() async {
    // Инициализация SQLite FFI (Foreign Function Interface).
    // Позволяет использовать SQLite в обычном Dart-скрипте без Flutter-движка.
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;

    final dbPath = await _getDatabasePath();
    print('📂 Target Database: $dbPath');

    // Автоматическое создание структуры папок, если база запускается на новой машине.
    if (!await File(dbPath).exists()) {
      print('💡 Creating directory and new database...');
      await Directory(dirname(dbPath)).create(recursive: true);
    }

    // Открытие базы данных с автоматическим созданием таблиц (схема должна совпадать с DatabaseProvider).
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 1, onCreate: onCreate),
    );

    print('🧹 Cleaning old data...');
    // Порядок важен из-за потенциальных связей (хотя в SQLite они тут не строгие).
    await db.delete('time_entries');
    await db.delete('tasks');
    await db.delete('projects');

    print('🏗 Generating entities...');

    // 1. Наполняем проекты
    final projects = _projects();
    for (final project in projects) {
      await db.insert('projects', project);
    }

    // 2. Генерируем задачи для каждого проекта
    final tasks = <Map<String, dynamic>>[];
    for (final project in projects) {
      tasks.addAll(_tasks(project['id'] as String));
    }
    for (final task in tasks) {
      await db.insert('tasks', task);
    }

    // 3. Создаем записи времени для каждой задачи
    final timeEntries = <Map<String, dynamic>>[];
    for (final task in tasks) {
      timeEntries.addAll(_timeEntries(task));
    }
    for (final entry in timeEntries) {
      await db.insert('time_entries', entry);
    }

    await db.close();
    print('✅ SEEDING COMPLETED SUCCESSFULLY');
  }

  // ---------------------------------------------------------------------------
  // ГЕНЕРАТОРЫ ДАННЫХ (MOCK DATA)
  // ---------------------------------------------------------------------------

  /// Генерирует список базовых проектов.
  static List<Map<String, dynamic>> _projects() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Список реальных названий и описаний для создания живой атмосферы в приложении.
    final data = [
      (
        'Fluxora',
        'AI-powered productivity platform focused on knowledge management, task tracking, and real-time collaboration. Integrates smart suggestions and automation to improve team efficiency.',
      ),
      (
        'NeuroDesk',
        'Team management and workflow orchestration tool designed for engineering teams. Includes sprint planning, backlog prioritization, and performance insights.',
      ),
      (
        'Fintrix',
        'Personal finance and investment tracking platform with real-time analytics, budgeting tools, and financial forecasting.',
      ),
      (
        'Cloudrift',
        'Cloud infrastructure management platform providing deployment pipelines, edge distribution, and serverless orchestration tools.',
      ),
      (
        'Dataforge',
        'Data analytics and ETL platform for processing large-scale datasets with built-in BI dashboards and reporting capabilities.',
      ),
      (
        'PulseChat',
        'Real-time messaging platform for teams with channels, threads, and integrations for productivity tools.',
      ),
      (
        'Auraly',
        'AI-powered voice synthesis and audio processing platform with support for real-time streaming and voice cloning.',
      ),
      (
        'Orbitix',
        'CRM and sales automation platform designed to manage leads, deals, and customer engagement workflows.',
      ),
      (
        'Velaris',
        'Design system and UI component platform used to standardize design across multiple products and teams.',
      ),
      (
        'Tracklio',
        'Time tracking and productivity analytics tool focused on deep work insights and performance optimization.',
      ),
    ];

    return data.map((e) {
      return {
        'id': _uuid.v4(),
        'name': e.$1,
        'description': e.$2,
        'created_at': now,
        'archived_at': null,
      };
    }).toList();
  }

  /// Генерирует случайные задачи для конкретного проекта.
  static List<Map<String, dynamic>> _tasks(String projectId) {
    final now = DateTime.now().millisecondsSinceEpoch;

    final data = [
      (
        'Implement feature module',
        'Develop and integrate a new feature module including UI, state management, and backend communication.',
      ),
      (
        'Fix critical production bug',
        'Investigate and resolve a high-priority production issue affecting user workflows and data consistency.',
      ),
      (
        'Refactor legacy code',
        'Clean up and refactor outdated code to improve readability, maintainability, and performance.',
      ),
      (
        'Optimize performance',
        'Analyze performance bottlenecks and implement optimizations for rendering, API calls, and data handling.',
      ),
      (
        'Write unit and integration tests',
        'Add test coverage for core business logic and ensure stability across critical flows.',
      ),
      (
        'Improve UI/UX interactions',
        'Enhance user experience by refining layouts, transitions, and interaction patterns.',
      ),
      (
        'Setup CI/CD pipeline',
        'Configure automated build, test, and deployment pipelines for faster and more reliable releases.',
      ),
      (
        'Integrate analytics system',
        'Add event tracking and analytics to monitor user behavior and product performance.',
      ),
      (
        'Investigate crash reports',
        'Analyze crash logs and debug issues reported in production environments.',
      ),
      (
        'Reduce technical debt',
        'Identify and resolve accumulated technical debt to improve long-term system stability.',
      ),
    ];

    return List.generate(5, (_) {
      final item = data[_random.nextInt(data.length)];
      return {
        'id': _uuid.v4(),
        'project_id': projectId,
        'title': item.$1,
        'description': item.$2,
        'status': 'open',
        'created_at': now,
        'completed_at': null,
      };
    });
  }

  /// Генерирует записи времени (логи) для задачи.
  /// Рандомизирует даты в пределах последних 7 дней.
  static List<Map<String, dynamic>> _timeEntries(Map<String, dynamic> task) {
    final entriesCount = _random.nextInt(5) + 1;

    final comments = [
      'Initial implementation and setup',
      'Working on core logic and edge cases',
      'Debugging and fixing issues',
      'Refactoring and improving code quality',
      'Reviewing and testing functionality',
      'Polishing UI and interactions',
      'Integrating with backend services',
      'Analyzing performance and optimizing',
      'Writing tests and validating flows',
      'Final adjustments and cleanup',
    ];

    return List.generate(entriesCount, (_) {
      // Генерируем случайную дату начала в течение недели.
      final start = DateTime.now()
          .subtract(Duration(days: _random.nextInt(7)))
          .millisecondsSinceEpoch;

      // Продолжительность от 30 до 150 минут.
      final duration = (_random.nextInt(120) + 30) * 60 * 1000;

      return {
        'id': _uuid.v4(),
        'project_id': task['project_id'],
        'task_id': task['id'],
        'comment': comments[_random.nextInt(comments.length)],
        'start_at': start,
        'end_at': start + duration,
        'status': 'stopped',
      };
    });
  }
}

/// Точка входа для запуска через `fvm dart`.
void main() async => await SeedService.seed();
