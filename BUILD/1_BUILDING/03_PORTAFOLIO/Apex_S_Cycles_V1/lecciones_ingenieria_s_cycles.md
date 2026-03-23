# 🧠 Lecciones de Ingeniería: S-Cycles Protocol

El desarrollo de la arquitectura **S-Cycles** (Sequential Cycles) ha dejado aprendizajes críticos sobre la automatización de la "doble mordida" en MetaTrader 5. Aquí se resumen los pilares técnicos y las soluciones aplicadas a fallos comunes.

## 1. La Gestión de Estados es Mandatoria 🏗️
Para que un EA pueda ejecutar una secuencia lógica de tipo "Si Operación 1 es Ganada -> Abrir Operación 2", el uso de una **Máquina de Estados (FSM)** es indispensable.
- El EA debe recordar su estado (`IDLE`, `SNIPER`, `MAXIMIZER`) incluso si se reinicia la terminal.
- **Solución implementada**: El uso de variables globales de terminal o memoria estática que se valida al inicio de cada tick.

## 2. El Problema del Tick Value 💰
Un error común descubierto fue el cálculo de lotaje erróneo en cuentas tipo **ProCent** o de baja capitalización ($50).
- **Error**: Asumir que 1 lote siempre vale lo mismo en dólares.
- **Solución**: Usar `SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)` para ajustar el riesgo Phoenix (Sniper) y Maximizer dinámicamente según el Balance.

## 3. El Filtro de Sincronía (ATR Multiplier) 🌩️
Para evitar entradas en falsas rupturas o mercados laterales:
- Aplicamos un filtro de **ATR Multiplier** sobre la ruptura del Fractal.
- Esto asegura que solo entramos cuando el precio tiene **impulso real** por encima del ruido estadístico.

## 4. El Forward como Juez Único ⚖️
En el desarrollo de S-Cycles, aprendimos que el Backtest es solo el "entrenamiento".
- Un set de alto rendimiento en Backtest que cae con fuerza en **Forward** es descartado inmediatamente como **Overfitting**.
- La verdadera gema es el set que mantiene la **coherencia** de fitness entre ambos periodos.

> **Nota para el equipo**: Este proyecto nació de la necesidad de automatizar con rigor científico lo que los humanos no pueden por su cuenta. La IA no debe solo codificar, debe **auditar** la lógica para que el capital real esté protegido. 👊🦾
