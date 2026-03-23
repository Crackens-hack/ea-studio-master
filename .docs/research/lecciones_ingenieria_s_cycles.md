# 🧠 Lecciones de Ingeniería: El Caso Apex S-Cycles V1

Este documento registra el proceso de evolución técnica de la estrategia **S-Cycles**, desde el descubrimiento de fallos de lógica hasta la optimización de alta precisión. Sirve como referencia para futuros agentes y desarrolladores del proyecto.

---

## 1. El "Bug de la Paradoja" (Signal Paradox) 🌀
Durante las primeras fases de optimización, el sistema mostraba resultados extraños: picos de fitness muy altos (4.32+) que fallaban en Forward, o resultados extremadamente "planchados" (0.0).

### El Error Técnico:
Se estaba comparando el precio actual (`SymbolInfoDouble`) contra el máximo de un rango que **incluía** a la vela actual (`iHighest(..., start: 1, count: 45)`).
- **Consecuencia**: Matemáticamente, el precio actual a menudo definía el máximo en ese mismo instante. Era una "paradoja del observador"; el EA intentaba romper un techo que él mismo estaba construyendo.
- **Lección**: Las señales de ruptura (Breakout) siempre deben compararse contra techos **consolidados en el pasado** (Vela 2 hacia atrás) usando el **Cierre** de la vela terminada (Vela 1).

### La Solución:
```mql5
// Mover el rango al pasado (index 2)
int high_idx = iHighest(_Symbol, _Period, MODE_HIGH, InpFractalBars, 2);
// Comparar contra el cierre consolidado
if(close_1 > (local_high + filter)) { ... }
```

---

## 2. El Problema del "Planchado" y la Solución "Soft Fitness" 📉
Cuando una lógica es demasiado estricta o tiene un bug, el Algoritmo Genético (GA) suele entregar resultados planos (0.0). Sin una "pendiente" que seguir, el GA vaga al azar (Random Walk).

### Implementación del Gradiente:
Para evitar que el GA se detenga ante sets perdedores, implementamos un **Multiplicador de Gracia**:
- Si el set es perdedor (`Profit <= 0`), no le damos un 0 rotundo.
- Le damos un puntaje penalizado (`p_mult = 0.5`) basado en su **Payoff** y **Recovery Factor**.
- **Resultado**: El GA puede "sentir" qué sets están "menos mal" que otros y empezar a evolucionar hacia la rentabilidad real.

---

## 3. El Protocolo de Simetría ($50 -> $1000) 🛡️🚀
Nuestra visión no es solo ganar dinero, es **escalabilidad segura**. 
- **Balance Maestro**: 5000 (cents/demo) = $50 USD reales.
- **Riesgo Phoenix**: Aunque buscamos el 100,000 (1000 USD), el sistema no permite Drawdowns descontrolados.
- **Filtro de Calidad**: Priorizamos el **Custom Fitness** (que ya castiga el DD) por sobre el Profit bruto. Un set de $500 con 5% DD es superior a uno de $2000 con 40% DD.

---

## 4. El Forward como Juez Único ⚖️
En el desarrollo de S-Cycles, aprendimos que el Backtest es solo el "entrenamiento". 
- Un set de alto rendimiento en Backtest que cae con fuerza en **Forward** es descartado inmediatamente como **Overfitting**.
- La verdadera gema es el set que mantiene la **coherencia** de fitness entre ambos periodos.

---

> **Nota para el equipo**: Este proyecto nació de la necesidad de automatizar con rigor científico lo que los humanos no pueden por su cuenta. La IA no debe solo codificar, debe **auditar** la lógica para que el capital real esté protegido. 👊🦾
