import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/baby_profile.dart';
import '../models/sleep_event.dart';
import '../models/sleep_prediction.dart';

class ExportServiceException implements Exception {
  const ExportServiceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class ExportService {
  const ExportService();

  Future<File> createCsv({
    required List<BabyProfile> profiles,
    required List<SleepEvent> events,
    required List<SleepPrediction> predictions,
    required DateTime generatedAtUtc,
  }) async {
    try {
      final Directory directory = await getTemporaryDirectory();
      final String stamp = generatedAtUtc
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final File file = File(path.join(directory.path, 'sueno_bebe_$stamp.csv'));
      final StringBuffer output = StringBuffer();
      output.writeln('SECCION,PERFIL');
      output.writeln(
        _row(<Object?>[
          'id',
          'nombre',
          'fecha_nacimiento',
          'fecha_probable_parto',
          'observacion',
          'zona_horaria',
          'creado_utc',
          'modificado_utc',
        ]),
      );
      for (final BabyProfile profile in profiles) {
        output.writeln(
          _row(<Object?>[
            profile.id,
            profile.name,
            _dateOnly(profile.birthDate),
            profile.expectedDueDate == null
                ? ''
                : _dateOnly(profile.expectedDueDate!),
            profile.notes ?? '',
            profile.timezone,
            profile.createdAtUtc.toIso8601String(),
            profile.modifiedAtUtc.toIso8601String(),
          ]),
        );
      }
      output.writeln();
      output.writeln('SECCION,EVENTOS_DE_SUENO');
      output.writeln(
        _row(<Object?>[
          'id',
          'bebe_id',
          'inicio_utc',
          'termino_utc',
          'tipo',
          'estado',
          'precision',
          'origen',
          'observacion',
          'zona_horaria',
          'creado_utc',
          'modificado_utc',
        ]),
      );
      for (final SleepEvent event in events) {
        output.writeln(
          _row(<Object?>[
            event.id,
            event.babyId,
            event.startUtc.toIso8601String(),
            event.endUtc?.toIso8601String() ?? '',
            event.type.dbValue,
            event.isOpen ? 'abierto' : 'finalizado',
            event.accuracy.dbValue,
            event.origin.dbValue,
            event.notes ?? '',
            event.timezone,
            event.createdAtUtc.toIso8601String(),
            event.modifiedAtUtc.toIso8601String(),
          ]),
        );
      }
      output.writeln();
      output.writeln('SECCION,PREDICCIONES');
      output.writeln(
        _row(<Object?>[
          'id',
          'bebe_id',
          'generada_utc',
          'ultimo_despertar_utc',
          'ventana_inicio_utc',
          'hora_central_utc',
          'ventana_fin_utc',
          'confianza',
          'observaciones',
          'mediana_min',
          'p25_min',
          'p75_min',
          'fuente',
          'explicacion',
          'version_algoritmo',
          'datos_usados_json',
          'numero_sueno_dia',
          'tipo_previsto',
          'evaluada_utc',
          'inicio_real_utc',
          'error_min',
          'dentro_intervalo',
        ]),
      );
      for (final SleepPrediction prediction in predictions) {
        output.writeln(
          _row(<Object?>[
            prediction.id,
            prediction.babyId,
            prediction.generatedAtUtc.toIso8601String(),
            prediction.lastWakeUtc.toIso8601String(),
            prediction.windowStartUtc.toIso8601String(),
            prediction.centerUtc.toIso8601String(),
            prediction.windowEndUtc.toIso8601String(),
            prediction.confidence.dbValue,
            prediction.observationCount,
            prediction.medianMinutes ?? '',
            prediction.p25Minutes ?? '',
            prediction.p75Minutes ?? '',
            prediction.source.dbValue,
            prediction.explanation,
            prediction.algorithmVersion,
            prediction.dataSnapshotJson,
            prediction.sleepSequenceNumber,
            prediction.intendedType.dbValue,
            prediction.evaluatedAtUtc?.toIso8601String() ?? '',
            prediction.actualSleepStartUtc?.toIso8601String() ?? '',
            prediction.errorMinutes ?? '',
            prediction.startedWithinWindow == null
                ? ''
                : prediction.startedWithinWindow!
                    ? 'si'
                    : 'no',
          ]),
        );
      }
      output.writeln();
      output.writeln('SECCION,RESULTADOS_PREDICCIONES');
      output.writeln(
        _row(<Object?>[
          'prediccion_id',
          'bebe_id',
          'evaluada_utc',
          'inicio_real_utc',
          'error_absoluto_min',
          'dentro_intervalo',
        ]),
      );
      for (final SleepPrediction prediction
          in predictions.where((SleepPrediction item) => item.isEvaluated)) {
        output.writeln(
          _row(<Object?>[
            prediction.id,
            prediction.babyId,
            prediction.evaluatedAtUtc!.toIso8601String(),
            prediction.actualSleepStartUtc?.toIso8601String() ?? '',
            prediction.errorMinutes ?? '',
            prediction.startedWithinWindow == true ? 'si' : 'no',
          ]),
        );
      }
      await file.writeAsString(
        '﻿${output.toString()}',
        encoding: utf8,
        flush: true,
      );
      return file;
    } on Object catch (error) {
      throw ExportServiceException(
        'No fue posible crear el archivo CSV.',
        error,
      );
    }
  }

  Future<void> shareCsv(File file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Exportación Sueño Bebé',
          text: 'Datos exportados desde Sueño Bebé.',
          files: <XFile>[XFile(file.path, mimeType: 'text/csv')],
          fileNameOverrides: <String>[path.basename(file.path)],
        ),
      );
    } on Object catch (error) {
      throw ExportServiceException(
        'El archivo se creó, pero no fue posible abrir el menú para compartir.',
        error,
      );
    }
  }

  String _row(List<Object?> values) => values.map(_escape).join(',');

  String _escape(Object? value) {
    final String text = value?.toString() ?? '';
    final String escaped = text.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
