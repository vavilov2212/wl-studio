import 'package:sqflite/sqflite.dart';
import 'package:worklog_studio/data/sqlite/database_provider.dart';

/// Generic base for all SQLite repository implementations.
///
/// Subclasses declare [tableName] and implement [fromMap] / [toMap];
/// the shared CRUD plumbing lives here exactly once.
abstract class SqliteRepositoryBase<T> {
  /// The SQLite table this repository operates on.
  String get tableName;

  /// Deserialise a raw DB row into an entity.
  T fromMap(Map<String, dynamic> map);

  /// Serialise an entity into a raw DB row.
  Map<String, dynamic> toMap(T entity);

  // ── DB accessor ────────────────────────────────────────────────────────────

  Future<Database> get db async => DatabaseProvider.getDatabase();

  // ── Shared CRUD ────────────────────────────────────────────────────────────

  /// Returns all rows ordered by [orderBy] (default: `created_at DESC`).
  Future<List<T>> getAll({String orderBy = 'created_at DESC'}) async {
    final d = await db;
    final rows = await d.query(tableName, orderBy: orderBy);
    return rows.map(fromMap).toList();
  }

  /// Returns the first row matching [id], or `null` if not found.
  Future<T?> getById(String id) async {
    final d = await db;
    final rows = await d.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return fromMap(rows.first);
  }

  /// Inserts [entity]. Throws on conflict.
  Future<void> insert(T entity) async {
    final d = await db;
    await d.insert(
      tableName,
      toMap(entity),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Updates the row matching the entity's `id`.
  /// Throws [StateError] if no row was affected.
  Future<void> update(T entity) async {
    final d = await db;
    final map = toMap(entity);
    final count = await d.update(
      tableName,
      map,
      where: 'id = ?',
      whereArgs: [map['id']],
    );
    if (count != 1) {
      throw StateError('$tableName row not found: ${map['id']}');
    }
  }

  /// Deletes the row with the given [id].
  Future<void> delete(String id) async {
    final d = await db;
    await d.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }
}
