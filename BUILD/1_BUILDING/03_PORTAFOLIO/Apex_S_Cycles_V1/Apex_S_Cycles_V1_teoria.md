# 📑 Teoría del Sistema: Apex S-Cycles V1
## "The Symmetry Protocol" (Modo 5000 -> 100,000)

### 1. El Concepto de Simetría
El sistema está diseñado bajo el **Protocolo de Simetría**. Esto significa que cada parámetro ha sido optimizado para una cuenta de **5000 unidades**. 
- En una cuenta **ProCent**, esto representa **$50 USD**.
- El objetivo final es alcanzar las **100,000 unidades** ($1000 USD reales).
- La simetría asegura que el riesgo calculado por el EA sea exactamente el mismo en Demo que en Real, eliminando el choque psicológico.

### 2. Estructura de Ciclos Secuenciales
S-Cycles no opera de forma aislada; opera en **ciclos de dos fases**:

#### Fase A: El SNIPER (Supervivencia)
- **Objetivo**: Conseguir la primera "mordida" del mercado con precisión quirúrgica.
- **Riesgo**: Agresivo (Phoenix Mode - 1.8% a 3.5% según el set).
- **Gestión**: Utiliza un **TP Imaginario**. Cuando el profit alcanza el 40% del TP imaginario (`InpTrailingTrigger`), la orden se mueve inmediatamente a **Break Even (BE)**. 
- **Cierre**: La orden se cierra al alcanzar el TP imaginario completo para asegurar el capital del ciclo.

#### Fase B: El MAXIMIZER (Explosión)
- **Activación**: Solo se activa si la fase Sniper cerró en **Ganancia**.
- **Objetivo**: Aprovechar la inercia del movimiento previo (Momentum) para maximizar el profit sin un techo fijo.
- **Riesgo**: Conservador sobre el balance total (0.5%), pero agresivo sobre la ganancia previa.
- **Gestión**: No tiene TP. Utiliza un **Trailing Stop** dinámico (`InpTrailingStep`) que persigue al precio.
- **Filosofía**: "Deja correr las ganancias". Si el mercado explota, aquí es donde ocurre el crecimiento exponencial.

### 3. Filtros Técnicos (The Edge)
- **Filtro de Tendencia (EMA 140)**: Solo se opera a favor de la tendencia macro.
- **Filtro de Ruptura (Fractal 85)**: Se busca la ruptura de un rango consolidado para asegurar volatilidad.
- **Filtro ATR (Multiplier 0.4)**: Se requiere una expansión de volatilidad mínima para validar que el movimiento no es ruido.

### 4. Modelo de Optimización: Cazador
El EA utiliza una función de fitness personalizada en el `OnTester()` que prioriza el **Profit Factor** y el **Recovery Factor** sobre el profit bruto.
- Premia la **estabilidad** y la **supervivencia** del capital de $50.
- Castiga severamente los Drawdowns superiores al 15% en fase de supervivencia.

---
`Documentación recuperada y reconstruida por Antigravity AI`
`Fecha: 18 de Marzo, 2026`
