# BUILD/03_PORTAFOLIO

Objetivo: guardar EAs listos para pruebas combinadas / demo, con expectativas claras de rendimiento y riesgo.

### Estructura por EA
- `BUILD/03_PORTAFOLIO/<EA>/`
  - `<EA>.mq5` y `<EA>.ex5` (última versión aprobada).
  - `<EA>_teoria.md` (lógica, inputs, riesgo, métricas esperadas y drawdowns tolerables).
  - `<EA>.set` base (copiado también a la instancia activa en `Presets/`).
  - Opcional: `logs/` de compilación o notas de tuning.
  - Bloque obligatorio en `_teoria.md`: **Expectativa demo/vivo** con PF, RF, winrate, payoff, DD% esperado, trades/mes, horizonte de evaluación y riesgos/rachas negativas esperadas.

### Criterios mínimos (v1)
- Forward válido: PF >= 1.3, RF >= 1.0, resultado > 0; ratio forward/back >= 0.8.
- Robustez: >= 200 trades (o >= 100 si intradía de bajo spread); DD% relativo <= 25%.
- Estabilidad: parámetros ±10–15% mantienen PF/RF dentro de -10%.
- Calidad: `OnTester` implementado, teoría al día, presets limpios, logs sin errores.
- Recencia: optimizaciones/ajustes dentro de los últimos 30 días.

### Flujo
- Mover desde `BUILD/02_ea_mejorar` cuando cumple criterios; archivar la versión previa en `02_ea_mejorar/archivados`.
- Copiar `_teoria.md` y `.set` junto con el código/binario.
- `.eastudio` es el taller; el seguimiento en vivo se hará en un repo separado más adelante.
