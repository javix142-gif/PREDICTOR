import 'package:sqflite/sqflite.dart';

import '../models/sleep_event.dart';
import '../models/sleep_prediction.dart';
import '../services/sleep_event_validator.dart';
import 'app_database.dart';

class SleepRepository {
  SleepRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<SleepEvent>> getEvents(String babyId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'sleep_events',
      where: 'baby_id = ?',
      whereArgs: <Object?>[babyId],
      orderBy: 'start_utc ASC',
    );
    return rows.map(SleepEvent.fromMap).toList(growable: false);
  }

  Future<SleepEvent?> getOpenEvent(String babyId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'sleep_events',
      where: 'baby_id = ? AND end_utc IS NULL',
      whereArgs: <Object?>[babyId],
      limit: 1,
    );
    return rows.isEmpty ? null : SleepEvent.fromMap(rows.first);
  }

  Future<SleepPrediction?> saveEvent(
    SleepEvent event, {
    required DateTime nowUtc,
    bool evaluatePrediction = false,
  }) async {
    SleepEventValidator.validateBasic(event, nowUtc: nowUtc);
    final Database db = await _database.database;
    return db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> existingRows = await txn.query(
        'sleep_events',
        where: 'baby_id = ? AND id != ?',
        whereArgs: <Object?>[event.babyId, event.id],
      );
      final List<SleepEvent> existing =
          existingRows.map(SleepEvent.fromMap).toList(growable: false);
      if (SleepEventValidator.overlapsAny(event, existing, nowUtc: nowUtc)) {
        throw const SleepEventValidationException(
          'El registro se superpone con otro sueño existente.',
        );
      }
      await txn.insert(
        'sleep_events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (!evaluatePrediction) {
        return null;
      }
      return _evaluateLatestPredictionInTransaction(
        txn: txn,
        babyId: event.babyId,
        actualSleepStartUtc: event.startUtc,
        evaluatedAtUtc: nowUtc,
      );
    });
  }

  Future<void> deleteEvent(String id) async {
    final Database db = await _database.database;
    await db.delete('sleep_events', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<SleepPrediction>> getPredictions(String babyId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'sleep_predictions',
      where: 'baby_id = ?',
      whereArgs: <Object?>[babyId],
      orderBy: 'generated_at_utc ASC',
    );
    return rows.map(SleepPrediction.fromMap).toList(growable: false);
  }

  Future<SleepPrediction?> getLatestPrediction(String babyId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'sleep_predictions',
      where: 'baby_id = ?',
      whereArgs: <Object?>[babyId],
      orderBy: 'generated_at_utc DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : SleepPrediction.fromMap(rows.first);
  }

  Future<void> savePrediction(SleepPrediction prediction) async {
    final Database db = await _database.database;
    await db.insert(
      'sleep_predictions',
      prediction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SleepPrediction?> evaluateLatestPrediction({
    required String babyId,
    required DateTime actualSleepStartUtc,
    required DateTime evaluatedAtUtc,
  }) async {
    final Database db = await _database.database;
    return db.transaction(
      (Transaction txn) => _evaluateLatestPredictionInTransaction(
        txn: txn,
        babyId: babyId,
        actualSleepStartUtc: actualSleepStartUtc,
        evaluatedAtUtc: evaluatedAtUtc,
      ),
    );
  }

  Future<SleepPrediction?> _evaluateLatestPredictionInTransaction({
    required Transaction txn,
    required String babyId,
    required DateTime actualSleepStartUtc,
    required DateTime evaluatedAtUtc,
  }) async {
    final List<Map<String, Object?>> rows = await txn.query(
      'sleep_predictions',
      where: 'baby_id = ? AND evaluated_at_utc IS NULL '
          'AND generated_at_utc <= ? AND last_wake_utc < ?',
      whereArgs: <Object?>[
        babyId,
        actualSleepStartUtc.toUtc().millisecondsSinceEpoch,
        actualSleepStartUtc.toUtc().millisecondsSinceEpoch,
      ],
      orderBy: 'generated_at_utc DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final SleepPrediction evaluated = SleepPrediction.fromMap(rows.first).evaluate(
      actualStartUtc: actualSleepStartUtc,
      evaluatedAtUtc: evaluatedAtUtc,
    );
    await txn.update(
      'sleep_predictions',
      evaluated.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[evaluated.id],
    );
    return evaluated;
  }

  Future<void> deleteAll() async {
    final Database db = await _database.database;
    await db.transaction((Transaction txn) async {
      await txn.delete('sleep_predictions');
      await txn.delete('sleep_events');
    });
  }
}
