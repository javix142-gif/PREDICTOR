# Algoritmo estadístico de sueño

Versión: `sleep-window-v1`.

## Principios

- Es determinista: los mismos datos producen el mismo resultado.
- No usa inteligencia artificial generativa ni servicios externos.
- Los instantes se almacenan en UTC y se presentan en la zona IANA del perfil.
- Una predicción es una orientación probabilística, no una indicación clínica.

## Construcción de ventanas despierto

Una ventana despierto es el intervalo entre el término de un sueño finalizado y el inicio del siguiente. Se excluyen intervalos menores de 10 minutos o mayores de 12 horas, por considerarse probablemente registros incompletos o errores de ingreso.

Se priorizan, en este orden:

1. ventanas del mismo número de sueño del día y del mismo tipo previsto;
2. ventanas del mismo tipo previsto;
3. todas las ventanas válidas de los últimos 14 días;
4. registros exactos antes que aproximados;
5. registros recientes antes que antiguos.

El cálculo usa hasta 30 observaciones comparables.

## Sin historial suficiente

Con menos de tres observaciones comparables, se usa el rango orientativo por edad definido en `lib/constants/sleep_reference_ranges.dart`:

- centro: punto medio del rango;
- inicio: mínimo del rango;
- término: máximo del rango;
- confianza: baja;
- fuente: edad.

## Con historial

Con tres o más observaciones:

- centro: mediana;
- inicio: percentil 25;
- término: percentil 75;
- ancho mínimo: 20 minutos;
- fuente: historial reciente.

Un intervalo amplio por alta variabilidad no se estrecha artificialmente.

## Confianza

- **Baja:** menos de 5 observaciones, más de 40 % aproximadas, IQR mayor a 60 minutos, datos antiguos o cambio reciente.
- **Media:** al menos 5 observaciones, IQR de hasta 60 minutos, mayoría exacta y patrón estable.
- **Alta:** al menos 10 observaciones recientes, IQR de hasta 30 minutos, menos de 20 % aproximadas y sin cambio reciente importante.

La regla equivalente está documentada junto a `PredictionService.confidenceFor`.

## Evaluación posterior

Al guardar el siguiente inicio de sueño, la aplicación conserva en la predicción original:

- hora real de inicio;
- error absoluto respecto de la hora central;
- resultado dentro o fuera del intervalo;
- momento de evaluación.

La escritura del evento y la evaluación se realizan dentro de la misma transacción SQLite.
