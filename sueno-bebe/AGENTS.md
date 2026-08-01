# AGENTS.md

## Objetivo
Mantener **Sueño Bebé**, una aplicación Flutter local para registrar, analizar y predecir estadísticamente el sueño infantil sin backend ni transmisión de datos.

## Reglas del repositorio
- Flutter estable y Dart con null safety.
- Android es la plataforma inicial; conservar compatibilidad de código con iOS.
- SQLite es la fuente de verdad para perfil, eventos y predicciones.
- `SharedPreferencesAsync` solo guarda preferencias no críticas.
- Los instantes se almacenan en UTC y se presentan en la zona horaria del perfil.
- No agregar analítica, publicidad, ubicación, cuentas, servicios externos ni secretos.
- No convertir referencias generales en instrucciones médicas.
- No introducir dependencias sin justificar necesidad, compatibilidad y licencia.
- Mantener el motor predictivo determinista, transparente y probado.

## Validación mínima
1. `dart format --output=none --set-exit-if-changed .`
2. `flutter analyze`
3. `flutter test`
4. Para entregas Android: `flutter build apk --debug`

## Seguridad
- No registrar nombres, observaciones ni datos del bebé en logs.
- No solicitar permisos fuera de `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED`.
- No usar alarmas exactas.
- No incluir keystores o credenciales en Git.
