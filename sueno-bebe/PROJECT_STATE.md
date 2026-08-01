# PROJECT_STATE.md

## Proyecto

- Nombre técnico: `sueno_bebe`
- Nombre visible: Sueño Bebé
- Versión: 1.0.0+1
- Plataforma inicial: Android
- Application ID: `cl.javiersanmartin.suenobebe`
- Flutter objetivo: 3.44.8 estable
- Dart objetivo: 3.12.2
- Algoritmo: `sleep-window-v1`

## Alcance implementado

- Perfil local de un bebé y onboarding.
- Cronómetro de sueño abierto, ingreso manual, edición y eliminación.
- Cronología agrupada por fecha con selector diario.
- Validación de fechas, superposición y unicidad de evento abierto.
- SQLite local con eventos y predicciones versionadas.
- Escritura atómica del nuevo evento y evaluación de la predicción.
- Estadísticas móviles de 24 h, 7, 14 y 30 días.
- Cuatro gráficos sin datos simulados.
- Predicción determinista con mediana, P25, P75 y confianza explicable.
- Estimación orientativa del inicio nocturno.
- Evaluación posterior de predicciones sin modificar el intervalo original.
- Notificaciones locales inexactas configurables.
- Exportación CSV de perfil, eventos, predicciones y resultados.
- Privacidad, limitaciones y orientación de sueño seguro.
- Temas claro, oscuro y automático.
- 21 pruebas unitarias que cubren los 18 casos obligatorios y casos adicionales.
- Workflow CI para formato, análisis, pruebas y APK debug.

## Decisiones

- Android mínimo API 24 por requisitos de los plugins seleccionados.
- No se ajusta edad por prematuridad.
- Los eventos nocturnos no se dividen en la base de datos; solo se recortan al calcular agregados diarios.
- Las referencias de ventanas despierto están centralizadas en `lib/constants/sleep_reference_ranges.dart` y se identifican como orientativas, no clínicas.
- Las notificaciones usan `AndroidScheduleMode.inexactAllowWhileIdle` y no requieren alarmas exactas.
- El perfil se actualiza mediante `UPDATE` para no activar eliminaciones en cascada propias de SQLite `REPLACE`.
- Las fallas de notificación no bloquean el registro o eliminación de los datos principales.
- El bootstrap de Gradle verifica el SHA-256 oficial de Gradle 8.13.

## Validación ejecutada

`python tool/static_validate.py`: aprobada.

Se validaron archivos, YAML, XML, imports relativos, delimitadores, esquema e índices SQLite, restricción de evento abierto, cascada, permisos, marcadores pendientes y posibles secretos.

## Validación pendiente del entorno

El código fuente se creó en un entorno sin Flutter SDK, Dart SDK ni Android SDK disponibles. No se ejecutaron localmente `flutter pub get`, `dart format`, `flutter analyze`, `flutter test` ni `flutter build apk --debug`.

La CI incluida ejecuta esas operaciones en Flutter 3.44.8. Ver `VALIDATION_REPORT.md`.
