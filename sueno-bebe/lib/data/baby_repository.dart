import 'package:sqflite/sqflite.dart';

import '../models/baby_profile.dart';
import 'app_database.dart';

class BabyRepository {
  BabyRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<BabyProfile?> getActiveProfile() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'baby_profiles',
      orderBy: 'modified_at_utc DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : BabyProfile.fromMap(rows.first);
  }

  Future<List<BabyProfile>> getAllProfiles() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      'baby_profiles',
      orderBy: 'created_at_utc ASC',
    );
    return rows.map(BabyProfile.fromMap).toList(growable: false);
  }

  Future<void> save(BabyProfile profile) async {
    final Database db = await _database.database;
    final Map<String, Object?> values = profile.toMap();
    final int updated = await db.update(
      'baby_profiles',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[profile.id],
    );
    if (updated == 0) {
      await db.insert(
        'baby_profiles',
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<void> deleteAll() async {
    final Database db = await _database.database;
    await db.delete('baby_profiles');
  }
}
