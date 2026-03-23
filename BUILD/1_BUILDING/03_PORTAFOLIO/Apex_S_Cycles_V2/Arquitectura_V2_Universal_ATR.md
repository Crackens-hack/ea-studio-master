# 📑 Arquitectura del Sistema: Apex S-Cycles V2
## "The Universal ATR Protocol"
---

### 1. La Evolución: Del Pips-Fijo al ATR-Dinámico 🌀
La V2 marca el fin de los parámetros estáticos. El EA ya no busca "42 pips", sino que busca **"la volatilidad proporcional de la última hora"**. 
*   **Gestión por Multiplicadores**: El SL, el TP y el Trailing Stop ahora son un múltiplo del ATR (`InpSL_Mult`, `InpTP_Mult`).
*   **Adaptabilidad Universal**: El sistema puede ser optimizado para cualquier activo (XAUUSD, EURUSD, BTCUSD) sin cambiar el código, solo ajustando los multiplicadores al ritmo del instrumento. 📈

### 2. El Reloj de Ciclos (Time-Based Holding) ⏱️
Se introdujeron los **"Frenos de Mano Temporales"** para evitar el estancamiento de capital. Cada fase tiene su propio límite de retención:
*   **Fase Sniper (Sniper Timeout)**: Optimizable de 12 a 168 horas. Si la orden no "despega" rápido al profit, el sistema la cierra para liberar margen. 🛡️
*   **Fase Maximizer (Maximizer Timeout)**: Optimizable de 24 a 500 horas. Da espacio para cazar tendencias semanales, pero asegura el cierre por si la tendencia se vuelve lateral. 📉

### 3. El Motor "Métrica Cazador" (OnTester) 🥇
Se implementó un motor de Fitness avanzado que busca la "Curva de Plata":
*   **Recovery Factor (RF)**: Es el corazón del sistema. Solo se premian los sets que recuperan rápido sus caídas.
*   **Drawdown (DD)**: El enemigo público #1. Cualquier set con DD > 15% es penalizado matemáticamente.
*   **Rampla de Trades**: Se exige un mínimo de 30 operaciones para evitar golpes de suerte (ruido). 📊

### 4. Estrategia de Phoenix Refinada 🔥
*   **EMA 140 + Fractales**: Seguimos respetando la tendencia mayor y las rupturas de rango, pero el filtro ATR añade un **Filtro de Compresión**: No entramos si el mercado está muerto (ATR demasiado bajo).

---
`Documentación generada por Antigravity AI`
`Fecha: 20 de Marzo, 2026`
`Estado: VERSIÓN DE PORTAFOLIO TERMINADA`
