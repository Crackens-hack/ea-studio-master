# .eastudio

Objetivo central: pensar, diseñar y construir Asesores Expertos (EA) de alta calidad usando IA como copiloto, combinando herramientas automáticas y pasos manuales guiados.

Cómo trabajamos
- Ideación asistida por IA: definir lógica, métricas y criterios de fitness antes de escribir código.
- Desarrollo de EA: la IA genera/edita `.mq5` en `BUILD/01_ea_construccion`.
- Compilación y despliegue: scripts de la carpeta raíz (`01_Compilador.ps1`, etc.) copian el `.ex5` a la instancia activa.
- Backtesting y optimización: `02_M-Tester.ps1` genera `Tools/EXEC-INI/exec.ini` a partir de `mtester.conf` y las mini plantillas `Tools/<modo>.ini`; el usuario elige modo, fechas y símbolos. El `.set` debe estar en `00_setup/Instancias/<instancia>/instalacion/MQL5/Presets/` con primera línea `;preset creado por agentes`.
- Iteración sobre resultados: leer logs, ajustar parámetros/código, repetir hasta obtener métricas limpias.

Principios
- IA + humano: la IA propone y ejecuta tareas acotadas; el humano valida credenciales, decide modos de prueba y lanza scripts sensibles.
- Transparencia: cada cambio queda documentado en los archivos de referencia (`AGENTS.md`, `docs/`).
- Calidad: siempre incluir `OnTester` con métricas clave (PF, DD, winrate, payoff, RR, Sharpe/Sortino cuando aplique).

Dónde mirar primero
- `llamado.md`: Es el sensor de pulso del proyecto. Bitácora activa del usuario que la IA DEBE leer para entender con quién habla y la misión actual.
- `AGENTS.md`: flujo operativo y reglas de seguridad (credenciales, compilación, backtesting).
- `docs/backtesting-modos/`: plantillas .ini y guía de modos.
- `docs/sets-ejemplo/`: ejemplos de `.set` (formato y convenciones).
