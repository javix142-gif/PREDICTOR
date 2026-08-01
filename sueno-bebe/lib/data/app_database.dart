import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabaseException implements Exception {
  const AppDatabaseException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const String databaseName = 'sueno_bebe.db';
  static const int databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    final Database? current = _database;
    if (current != null && current.isOpen) {
      return current;
    }
    try {
      final String databasePath = await getDatabasesPath();
      final String fullPath = path.join(databasePath, databaseName);
      _database = await openDatabase(
        fullPath,
        version: databaseVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
      );
      return _database!;
    } on AppDatabaseException {
      rethrow;
    } on Object catch (error) {
      throw AppDatabaseException(
        'No fue posible abrir la base de datos local.',
        error,
      );
    }
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
        CREATE TABLE baby_profiles (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          birth_date TEXT NOT NULL,
          expected_due_date TEXT,
          notes TEXT,
          timezone TEXT NOT NULL,
          created_at_utc INTEGER NOT NULL,
          modified_at_utc INTEGER NOT NULL
        )
      ''');
    await db.execute('''
        CREATE TABLE sleep_events (
          id TEXT PRIMARY KEY,
          baby_id TEXT NOT NULL,
          start_utc INTEGER NOT NULL,
          end_utc INTEGER,
          type TEXT NOT NULL CHECK (type IN ('siesta', 'nocturno')),
          status TEXT NOT NULL CHECK (status IN ('abierto', 'finalizado')),
          accuracy TEXT NOT NULL CHECK (accuracy IN ('exacta', 'aproximada')),
          origin TEXT NOT NULL CHECK (origin IN ('cronometro', 'manual')),
          notes TEXT,
          timezone TEXT NOT NULL,
          created_at_utc INTEGER NOT NULL,
          modified_at_utc INTEGER NOT NULL,
          FOREIGN KEY (baby_id) REFERENCES baby_profiles(id) ON DELETE CASCADE,
          CHECK (end_utc IS NULL OR end_utc > start_utc),
          CHECK ((end_utc IS NULL AND status = 'abierto') OR
                 (end_utc IS NOT NULL AND status = 'finalizado'))
        )
      ''');
    await db.execute('''
        CREATE TABLE sleep_predictions (
          id TEXT PRIMARY KEY,
          baby_id TEXT NOT NULL,
          generated_at_utc INTEGER NOT NULL,
          last_wake_utc INTEGER NOT NULL,
          window_start_utc INTEGER NOT NULL,
          center_utc INTEGER NOT NULL,
          window_end_utc INTEGER NOT NULL,
          confidence TEXT NOT NULL CHECK (confidence IN ('baja', 'media', 'alta')),
          observation_count INTEGER NOT NULL,
          median_minutes REAL,
          p25_minutes REAL,
          p75_minutes REAL,
          source TEXT NOT NULL CHECK (source IN ('edad', 'historial')),
          explanation TEXT NOT NULL,
          algorithm_version TEXT NOT NULL,
          data_snapshot_json TEXT NOT NULL,
          sleep_sequence_number INTEGER NOT NULL,
          intended_type TEXT NOT NULL CHECK (intended_type IN ('siesta', 'nocturno')),
          evaluated_at_utc INTEGER,
          actual_sleep_start_utc INTEGER,
          error_minutes INTEGER,
          started_within_window INTEGER CHECK (
            started_within_window IS NULL OR started_within_window IN (0, 1)
          ),
          FOREIGN KEY (baby_id) REFERENCES baby_profiles(id) ON DELETE CASCADE,
          CHECK (window_start_utc <= center_utc),
          CHECK (center_utc <= window_end_utc)
        )
      ''');
    await db.execute(
      'CREATE INDEX idx_sleep_events_baby_start '
      'ON sleep_events(baby_id, start_utc)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_one_open_sleep_per_baby '
      'ON sleep_events(baby_id) WHERE end_utc IS NULL',
    );
    await db.execute(
      'CREATE INDEX idx_predictions_baby_generated '
      'ON sleep_predictions(baby_id, generated_at_utc)',
    );
    await db.execute(
      'CREATE INDEX idx_predictions_evaluation '
      'ON sleep_predictions(baby_id, evaluated_at_utc)',
    );
  }

  Future<void> close() async {
    final Database? current = _database;
    if (current != null && current.isOpen) {
      await current.close();
    }
    _database = null;
  }
}
