# AGENTS

Contexto: usar siempre la terminal integrada de VS Code / Cursor / Antigravity. El agente avanza despacio, explica y confirma cada paso; no asume permisos ni lanza instaladores por su cuenta.

## Reglas Maestras de Estructura (NUEVO ORDEN)

El repositorio ha sido optimizado para la visualización minimalista y eficiencia de ingeniería. Los scripts de control están numerados secuencialmente en el root.

### 0. Gestión de Instancias y Hubs
- **`00_Jefe-Activa.ps1`**: Es el script MANDATORIO para empezar. Selecciona la instancia de MT5 activa y genera el **Hub Virtual** (Carpeta `.000_<instancia>_hub_000`) en el root con enlaces simbólicos a Presets, Logs y Profiles.
- **`00_setup/Instalador.ps1`**: Solo para configuración inicial o añadir nuevas cuentas. **El agente NO lo ejecuta.** Solo guía al usuario sobre cómo correrlo y qué responder.
- **`04_LauncherPortable.ps1`**: Lanza la instancia de MT5 actualmente activa en modo portable.

### 1. El Taller de Construcción (BUILD/1_BUILDING)
Toda la fabricación de EAs ocurre dentro de `BUILD/1_BUILDING/`.
- **`01_ea_construccion/`**: Donde nacen los EAs corporativos (ej. Apex S-Cycles).
- **`02_ea_mejorar/`**: Reservado para EAs externos o re-ingeniería de lógica ajena.
- **`03_PORTAFOLIO/`**: Destino final para EAs que han pasado Forward y Stress Tests.
- **`04_ARCHIVADOS/`**: El cementerio de versiones antiguas que se limpian automáticamente.
- **05_METRICAS_ELITES/**: El cofre del tesoro. Donde se guardan los sets ganadores (.set) y los reportes de rendimiento detallados tras el análisis de DuckDB.

### 2. Scripts de Producción
- **`01_Compilador.ps1`**: Compila EAs desde `01_ea_construccion`.
- **`03_Recompilador.ps1`**: Compila EAs desde `02_ea_mejorar`.
- Tras compilar, revisar logs en `00_setup/resources/Compiler` y confirmar copia del `.ex5` a la instancia activa.

### 3. El Laboratorio (Tools & Metrics)
- **`.docs/`**: Carpeta oculta con teoría y modelos de fitness. Consultar siempre **`.docs/fitness/fitness-ontester.md`** antes de codificar `OnTester()`. Es el estándar mandatorio.
- **`Tools/Tools-Agents/`**: Contiene `02_M-Tester-AutoAgents.ps1` y `DuckDB_Analyzer.py`.
- **`Tools/script/`**: Scripts de procesamiento masivo (`A_Normalizador_Master.py`, `B_Analista_Profesional.py`).
- **`BUILD/RESULTADOS/`**: Centraliza reportes analizados y normalizados.

---

## Flujo Recomendado de Sesión

### 0) EL LLAMADO (CRÍTICO)
- **`llamado.md` es el sensor de pulso**. Leer siempre. Si es sesión nueva, preguntar:
    - "¿Cuál es tu objetivo con este repositorio? ¿Por qué creíste en este proyecto?"
    - "¿Cuál es tu perfil? (Socio técnico, trader con experiencia...)"
- **Misión de Bitácora**: Documentar objetivos y nivel de urgencia para ajustar el ritmo de ejecución.

### 1) Sincronización de Instancia
- Revisar `00_setup/Instancias/credencial_en_uso.json`. Si no existe o no es la correcta, pedir al usuario correr `.\00_Jefe-Activa.ps1`.
- Informar cuenta y servidor activo al usuario antes de proceder.

### 2) Codificación y Nomenclatura (SIMETRÍA DUCKDB)
- **REGLA DE ORO**: Todo input MQL5 (`input type variable`) **OBLIGATORIAMENTE** empieza con `Inp` (Ej: `InpBaseLot`). Vital para que `DuckDB_Analyzer.py` identifique parámetros.
- Generar `BUILD/1_BUILDING/01_ea_construccion/<EA>_teoria.md` con lógica y gestión de riesgo.
- **ITERACIÓN**: Si falla la lógica original, descartar idea e informar. No cambiar la naturaleza de la estrategia en el mismo archivo; crear un nuevo EA.

### 3) Métricas y OnTester (MANDATORIO)
- Consultar **`.docs/fitness/fitness-ontester.md`** antes de implementar. Es OBLIGATORIO usar la arquitectura de Fitness Adaptativo Grado Hedge Fund (V5.4) con autodetección temporal y bloques lógicos.
- El EA debe estar listo para DuckDB antes de optimizar.

### 4) Backtesting y "JUEZ AI" (OBLIGATORIO)
Cuando el usuario diga "optimización genética terminada":
1.  **Normalización**: Ejecutar `Tools/script/A_Normalizador_Master.py` y `B_Analista_Profesional.py`.
2.  **DuckDB**: Correr `Tools/Tools-Agents/DuckDB_Analyzer.py`.
3.  **Forward Coherence**: Priorizar Forward sobre Backtest. Si el Forward cae (> 50% de caída respecto al BT), es Overfitting -> **DESCARTAR**.
4.  **Prioridad Custom**: El criterio de ordenamiento es la métrica de `OnTester`, no el Profit bruto.
5.  **Extracción Élite**: Ejecutar procesos de extracción y guardar en `BUILD/1_BUILDING/05_METRICAS_ELITES/<EA>/`. Crear `Reporte_Elite_01.md`.

---

## Archivos .set (Protocolo Maestro)
- **Cabecera**: Debe empezar con `;archivo de configuracion`.
- **Doble Guardado**: Guardar en `MQL5/Presets` y `MQL5/Profiles/Tester` sincrónicamente (usar el Hub para rutas cortas).
- **Modo 5000**: Balance inicial de **5000** obligatorio (Simetría ProCent $50).
- **Sin Sesgo**: Si el usuario pide meta agresiva ($50 -> $1000), trabajar en la matemática sin sermones, priorizando eficiencia y bajo DD.

## Portafolio Elite (Criterios de Pase)
- Forward Válido: PF >= 1.3, RF >= 1.0, Ganancia > 0.
- Robustez: >= 200 trades (100 si es intradía), DD relativo <= 25%.
- Bloque "Expectativa demo/vivo" mandatorio en la teoría.

## PROTOCOLO FÉNIX ($50 / 1:2000) - ALTA URGENCIA

Este repositorio NO es para trading conservador de bancos; es una fábrica de escalabilidad agresiva para cuentas de **$50 USD (5000 centavos)**. El Agente debe operar bajo estas premisas NO NEGOCIABLES:

1.  **Sin Sermones de Riesgo**: Si el usuario define una meta agresiva ($50 -> $1000), el agente no debe dar lecciones sobre "gestión conservadora". El trabajo del agente es **optimizar la probabilidad matemática de éxito** dentro de ese nivel de riesgo, no juzgarlo.
2.  **Estándar de Fábrica**:
    -   **Depósito**: Siempre **5000**.
    -   **Apalancamiento**: Siempre **1:2000**.
    -   **Objetivo**: Escalamiento rápido y eficiente.
3.  **Frotura Sniper**: El agente debe priorizar entradas que minimicen el Drawdown inicial (Floating), ya que $50 no aguantan "ruido" de mercado innecesario.
4.  **Territorio Sagrado**: Queda terminantemente prohibido para la IA editar o leer la carpeta `Tools-Human/`. Ese es el panel de control exclusivo del usuario.

## Tono y Ritmo
- Trabajar con sentido de urgencia estratégica pero con rigor técnico absoluto.
- El Agente es el responsable de mantener la coherencia de la fábrica tras cada iteración.
