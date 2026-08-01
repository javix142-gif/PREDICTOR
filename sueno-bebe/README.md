# Sueño Bebé

Aplicación Flutter local para registrar el sueño de un bebé, obtener estadísticas transparentes y estimar próximas ventanas orientativas mediante un algoritmo determinista.

## Funciones principales

- Perfil local de un bebé, preparado para ampliar el modelo a varios perfiles.
- Inicio y término de sueño mediante cronómetro sin escrituras continuas.
- Ingreso manual, edición, eliminación y cronología agrupada por fecha.
- SQLite con instantes UTC, restricciones de integridad y datos persistentes.
- Estadísticas móviles de 24 horas y períodos de 7, 14 y 30 días.
- Predicción por edad o historial reciente con mediana, P25, P75 y confianza explicable.
- Evaluación posterior del error de cada predicción.
- Estimación orientativa del inicio del sueño nocturno.
- Notificaciones locales inexactas configurables.
- Exportación CSV de perfil, eventos, predicciones y resultados.
- Tema claro, oscuro o automático.
- Secciones de privacidad, limitaciones y orientación de sueño seguro.

## Privacidad

Todos los datos permanecen en SQLite y preferencias locales del dispositivo. La aplicación no contiene backend, cuentas, publicidad, analítica, rastreo, ubicación ni transmisión automática.

El manifiesto principal no solicita Internet. Las variantes `debug` y `profile` lo declaran únicamente para las herramientas de desarrollo de Flutter.

## Requisitos de desarrollo

- Flutter 3.44.8 estable
- Dart 3.12.2
- Java 17 o superior
- Android SDK compatible con el `compileSdk` de Flutter 3.44
- Android mínimo API 24

## Ejecución

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

## APK de depuración

```bash
flutter build apk --debug
```

El APK se genera en:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

El workflow `.github/workflows/flutter-ci.yml` automatiza dependencias, formato, análisis, pruebas y APK debug. Publica solo el APK como artefacto.

## Validación estructural sin Flutter

```bash
python tool/static_validate.py
```

Esta revisión no sustituye `flutter analyze`, `flutter test` ni un build Android. El resultado de esta entrega se detalla en `VALIDATION_REPORT.md`.

## Datos y cálculo

- Los instantes se persisten en UTC.
- La presentación utiliza la zona IANA guardada en el perfil.
- “Últimas 24 horas” es una ventana móvil real.
- Los informes diarios se recortan por medianoche local sin alterar eventos originales.
- Con menos de tres ventanas válidas se usa una referencia orientativa por edad.
- Con tres o más ventanas se usan mediana, P25 y P75 de observaciones comparables de los últimos 14 días.
- La confianza depende de cantidad, precisión, variabilidad, antigüedad y cambio reciente.
- El intervalo nunca se estrecha artificialmente cuando existe alta variabilidad.

La especificación completa está en `docs/ALGORITMO.md`.

## Estructura

```text
lib/
  constants/
  controllers/
  data/
  models/
  screens/
  services/
  utils/
  widgets/
test/
docs/
tool/
android/
```

## Advertencia

La aplicación entrega orientación estadística basada en los registros ingresados. No reemplaza la evaluación de un profesional de salud.
