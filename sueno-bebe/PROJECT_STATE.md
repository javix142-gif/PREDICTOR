# PROJECT_STATE.md

## Proyecto
- Nombre: Sueño Bebé (`sueno_bebe`)
- Versión: 1.1.0+2
- Application ID: `cl.javiersanmartin.suenobebe`
- Flutter validado: 3.44.8 estable
- Android mínimo: API 24
- Algoritmo: `sleep-window-v1`

## Implementado
- Despertar nocturno entre 18:00 y 06:00 con acciones “Volvió a dormir” y “Terminó la noche”.
- Segmentos nocturnos conservados como eventos independientes y agrupados visualmente.
- Cobertura mínima antes de comparar 24 horas y mensajes no médicos.
- Días sin registros tratados como “sin datos”.
- Mínimos estadísticos para siestas, noches, ventanas, IQR, variabilidad y error predictivo.
- Pantallas Hoy, Estadísticas, Historial y Formulario rediseñadas.
- Tema Material 3 centralizado y soporte de texto ampliado hasta 1.5.
- Sin cambios de esquema SQLite ni permisos Android.

## Validación
- Dependencias, formato, análisis, 37 pruebas, validación estructural y build ARM64: aprobados.
- Firma debug y alineación de 16 KB: verificadas.

## Limitaciones
- APK debug; no sustituye una firma persistente de publicación.
- No se realizó una nueva prueba manual completa en teléfono físico durante esta ejecución.
