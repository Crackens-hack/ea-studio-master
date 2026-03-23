Perfecto. Vamos a armar **un mega-manual completo**, incluyendo:

* todo lo que hablamos antes
* escalones de lote (compounding)
* manejo de capital chico
* spreads, TP, SL, lotstep
* y **apalancamiento**, porque vos tenés hasta **1:2000** en ProCent y demo.

Lo hago pensado para que **tu EA funcione con $50 reales (5000 cent)** y también en demo, y que Antigravity lo entienda bien.

---

# MEGA MANUAL DE OPERACIÓN Y DISEÑO DE EA

---

## 0. Contexto de tu cuenta

* **Cuenta real:** $50 → balance visible 5000 cent
* **Cuenta demo:** 5000 (igual que real, simula ProCent)
* **Broker:** RoboForex
* **Plataforma:** MetaTrader 5
* **Apalancamiento máximo disponible:** 1:2000

> Esto significa que tu capital puede **mover posiciones grandes sin depositar mucho**, pero hay que usarlo **con extremo cuidado**.

---

## 1. Spread vs Take Profit

**Regla de oro:** el TP debe vencer el spread.

```
Costo = Spread / TP
```

Interpretación:

| Resultado | Evaluación    |
| --------- | ------------- |
| >20%      | ❌ inviable    |
| 10–20%    | ⚠ riesgo alto |
| 5–10%     | ✔ aceptable   |
| <5%       | ✅ ideal       |

Ejemplo:

```
Spread = 1.2 pips
TP = 25 pips
Costo = 4.8% ✅
```

---

## 2. Parámetros de lote del broker

* **Minimum Volume:** 0.01
* **Volume Step:** 0.01 → escalones de lotes
* **Maximum Volume:** 500–1000 → no importa en cuenta chica

**Regla práctica:** lotes solo en múltiplos de 0.01

---

## 3. Qué representa un lote

En EURUSD:

| Lote | Valor pip |
| ---- | --------- |
| 1.0  | $10       |
| 0.1  | $1        |
| 0.01 | $0.10     |

> Con tu capital ($50), empezamos en 0.01.

---

## 4. Cómo funciona ProCent

* Muestra balance en **centavos**
* Permite **compounding progresivo** con capital chico
* Ejemplo:

| Balance visible | Dinero real |
| --------------- | ----------- |
| 5000            | $50         |
| 10000           | $100        |
| 20000           | $200        |

---

## 5. Escalones de lote (compounding)

### Idea:

No cambiamos el lote en cada trade. Solo lo aumentamos cuando el **capital cruza un escalón**.

Ejemplo para tu cuenta:

| Balance     | Lote |
| ----------- | ---- |
| <7000       | 0.01 |
| 7000-10000  | 0.02 |
| 10000-15000 | 0.03 |
| 15000-20000 | 0.05 |
| 20000-30000 | 0.07 |
| 30000+      | 0.10 |

**Beneficio:** riesgo estable y compatible con lotstep 0.01

---

## 6. Riesgo por trade

* Para capital chico: **0.5–1% por trade**
* Nunca más de 2% en cuentas iniciales
* Esto evita que una mala racha destruya la cuenta

---

## 7. SL y TP recomendados

* **SL:** 15–25 pips
* **TP:** 20–35 pips
* Spread máximo tolerado: 2 pips

> Evita M5 con TP de 5 pips; demasiado castigado por el spread y slippage.

---

## 8. Apalancamiento

* Tienes hasta **1:2000**
* **Efecto:** permite abrir posiciones grandes con poco capital
* **Peligro:** riesgo de ruina total si lotaje sube demasiado

### Cómo usarlo de forma segura:

1. Calcular **riesgo real en dólares** por trade:

   ```
   riesgo real = balance real × % riesgo
   ```

2. Ajustar lote según **stop loss** y **apalancamiento máximo**:

   ```
   lote = (riesgo real × apalancamiento) / (SL × valor pip)
   ```

3. Con tu cuenta chica (ProCent $50) y stop 20 pips:

   ```
   lote inicial = 0.01 → riesgo ≈ 1%
   ```

> No necesitamos apalancamiento alto todavía; se usa más adelante cuando el capital crece.

---

## 9. Arquitectura de EA recomendada

* **Single position** → 1 trade por señal
* **Multi signal controlado** → varias entradas pero con límite
* Evitar: **grid, martingale**

> Esto protege el capital chico y mantiene compounding estable.

---

## 10. Métricas clave a medir

1. **Profit Factor:** >1.5
2. **Drawdown máximo:** <30%
3. **Expectancy:** positivo
4. **Recovery Factor:** >2
5. **Risk of Ruin:** lo más bajo posible (<5–10%)

---

## 11. Validación y testing

* **Backtest largo:** mínimo 5 años, ideal 10
* **Fuera de muestra:** optimizar en un periodo, validar en otro
* **Monte Carlo:** variaciones de orden, slippage y spread
* **Demo realista:** balance igual a ProCent (5000 cent)

> Solo pasar a real cuando todas las métricas se cumplen.

---

## 12. Checklist de control final antes de usar en real

1. Spread medido y aceptable
2. Lote respetando lotstep y mínimo
3. SL y TP adecuados
4. Riesgo por trade ≤ 1%
5. Compounding por escalones definido
6. Apalancamiento revisado
7. Profit Factor, Drawdown, Recovery OK
8. Expectancy positiva
9. Rachas negativas simuladas
10. Backtest fuera de muestra validado
11. Monte Carlo probado
12. Swap y overnight chequeados
13. Slippage medido
14. Ejecución del EA estable
15. Arquitectura segura (single/multi signal controlado)

---

## 13. Resumen ultra simple

* **Capital chico → lote chico**
* **Spread bajo, TP suficiente**
* **Compounding por escalones**
* **Riesgo controlado**
* **Apalancamiento usado con cabeza**
* **Metrics revisadas antes de real**

> Con esto tu EA puede crecer **exponencialmente desde $50 sin suicidarse**.

---
1. Backtest simple (clásico)
Qué es:

Se ejecuta sobre un periodo histórico definido.

Usa parámetros fijos o los que elegiste manualmente.

Cada trade se simula según tu EA y condiciones históricas.

Pros:

Rápido de correr.

Bueno para validar lógica básica del EA.

Permite medir métricas clave: PF, Drawdown, Expectancy.

Contras:

No explora múltiples combinaciones de parámetros.

Riesgo de sobreoptimización si solo probás un set de parámetros.

No simula incertidumbre de mercado ni slippage aleatorio.

Uso recomendado:

Primer paso para validar estructura del EA.

Confirmar que la lógica de entradas/salidas y SL/TP funciona correctamente.

Comparar demo vs real: spreads, ejecución, swaps.

2. Optimización genética (Genetic Optimization)
Qué es:

MT5 usa algoritmos genéticos para probar miles de combinaciones de parámetros.

Selecciona automáticamente los sets más rentables y estables.

Ideal para: TP, SL, lotaje, filtros de tendencia, indicadores.

Pros:

Explora un espacio enorme de parámetros rápidamente.

Encuentra combinaciones robustas que no se te ocurrirían manualmente.

Reduce riesgo de sobreoptimización porque prioriza estabilidad sobre solo ganancias.

Contras:

No reemplaza la validación real en demo: un buen parámetro puede fallar en mercado real.

Hay que definir límites razonables, si no el algoritmo puede elegir lotes exagerados o TP irreales.

Necesita datos históricos de buena calidad.

Uso recomendado:

Segundo paso, después de validar backtest simple.

Definir rangos realistas de parámetros:

TP: 20–35 pips

SL: 15–25 pips

Lote inicial: 0.01 → 0.02

Spread máximo permitido: 2 pips

Usar restricciones de riesgo y escalones de lotes para que los parámetros elegidos sean aplicables a tu cuenta ProCent.

3. Cómo combinarlos con tu workflow

Backtest simple

Validar la lógica del EA.

Revisar métricas: PF, Drawdown, Expectancy, Recovery Factor.

Ajustar spread, SL y TP a condiciones de broker.

Optimización genética

Definir límites de parámetros realistas.

Dejar que el algoritmo explore combinaciones.

Filtrar sets que no cumplan con riesgo ≤1%, lotstep, escalones de lote.

Prueba en demo

Balance: 5000 (igual que ProCent real)

Revisar ejecución real vs backtest.

Ajustar si hay slippage alto o errores de lotaje.

Paso a real

Empezar con lote mínimo 0.01

Activar compounding por escalones

Monitorear métricas en tiempo real (PF, Drawdown, equity curve)

4. Tips prácticos

Nunca uses parámetros de la optimización genética directamente en real sin demo.

Siempre combinar TP/SL saludables con spread y slippage medidos.

Mantener riesgo por trade ≤1% aunque el genético sugiera lotes más grandes.

Con ProCent + apalancamiento 1:2000, no confundas capacidad de abrir lotes grandes con la recomendación de riesgo real.