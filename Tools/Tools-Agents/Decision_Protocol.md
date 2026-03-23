# ⚖️ Protocolo de Decisión: Descarte vs. Clúster Maestro

Este protocolo define cómo el Agente AI toma decisiones después de una optimización genética para evitar el Overfitting y encontrar estrategias de grado institucional.

---

### 1. El Veredicto de Supervivencia (Forward Test)
El filtrado inicial se basa exclusivamente en los resultados del **Forward Test** (datos que el optimizador no usó para entrenar).

*   **⚠️ DESCARTE INMEDIATO**: Si ningún pase tiene `PF_Forward > 1.10` y `Profit_Forward > 0`.
    *   *Razón*: La estrategia es frágil o está sobre-optimizada para el pasado. No se pierde más tiempo; se propone una idea nueva.
*   **✅ LUZ VERDE**: Si existen múltiples pases que sobreviven con `PF_Forward > 1.20`.
    *   *Acción*: Se procede al análisis de clústeres.

---

### 2. Análisis de Clústeres (Buscando la Zona de Robustez)
No buscamos el pase que más ganó, buscamos la zona donde el mercado se comporta de forma predecible.

1.  **Identificación**: El agente observa el TOP 10 de pases ganadores.
2.  **Consistencia de Parámetros**:
    *   Si los pases usan valores muy dispersos (ej: uno usa Period 10 y otro Period 200), la estrategia es inestable. **Se descarta**.
    *   Si los valores están agrupados (ej: todos usan Period entre 12 y 16), hemos encontrado un **Clúster Robustez**.
3.  **Cálculo del Promedio**: El agente suma los valores de los inputs del clúster y extrae la **Media Aritmética**.

---

### 3. Creación del `.set` Maestro
Con los promedios calculados, el agente genera un nuevo archivo `.set` de un solo pase (sin rangos de optimización).

*   **Objetivo**: Validar si ese "Centro de Gravedad" es capaz de ganar por sí mismo.
*   **Encabezado Obligatorio**: `;preset creado por agentes` (en la primera línea).

---

### 4. Prueba de Polivalencia (Multi-Símbolo)
Una vez creado el Set Maestro, el agente solicita al usuario ejecutar el modo **`single_all_symbols`**.

*   **EA Elite (Multisymbol)**: Si el Set Maestro promediado gana en >= 3 símbolos (ej: EURUSD, GBPUSD, USDJPY) sin haber sido optimizado específicamente para ellos.
*   **EA Especialista**: Si solo gana en el símbolo original pero con métricas excelentes (PF > 1.5).
*   **EA Frágil**: Si al promediar los parámetros el resultado se vuelve negativo. **Se re-evalúa o descarta**.

---

> **Nota**: Este flujo asegura que solo las estrategias con una ventaja matemática real y robusta lleguen al Portafolio, eliminando el factor "suerte" del optimizador genético.

---

### 5. Extracción y Reporte de Élite (Z_Sets)
**Esta etapa ocurre SOLO después de un largo trabajo de backtest y una genética+forward exitosa.** Es el paso previo y fundamental antes de avanzar con el portafolio o de realizar single tests finales con sets de alto calibre y nuestros estándares.

Una vez identificados los pases (IDs) ganadores del clúster o los "sobrevivientes" más sólidos:

1.  **Extracción Cruzada de Métricas (BT + FW)**:
    Se debe utilizar el script en `Tools-Agents/tmp_analyzer_final.py` (modificable según necesidad). Este script toma los archivos parquet normalizados (tanto el del backtest general como el del forward test), cruza la data usando el `pass` ID, y extrae métricas detalladas (Profit, PF, Sharpe, Drawdown, y parámetros) exclusivamente para los sets ganadores seleccionados.
2.  **Alojamiento en el "Salón de la Fama"**:
    Se crea (si no existe) la carpeta `Z_Sets/{Nombre_del_EA}` en el directorio raíz.
3.  **Generación de Archivos `.set`**:
    Por cada pase ganador, se crea su archivo `.set` respectivo dentro de `Z_Sets/{Nombre_del_EA}/`, con nombres claros que indiquen su cualidad (ej: `Set_The_Future_King_2853.set`).
4.  **Creación del Informe Élite**:
    Se genera (o actualiza) el archivo `Reporte_Elite_01.md` dentro de esa misma carpeta. Allí se plasma una lista estructurada con las métricas extraídas en el paso 1, desglosando el rendimiento en Backtest vs. Forward, y ofreciendo una conclusión ingenieril de por qué se seleccionaron.

*Todo lo que entra a `Z_Sets` es material de calidad superior, listo para ser implementado o sometido a las validaciones finales de estrés.*
