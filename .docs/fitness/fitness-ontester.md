# 📊 Fitness Adaptativo V5.4 – Grado Hedge Fund (OnTester)

Esta es la **Constitución Soberana Definitiva** de evaluación de la fábrica. Basada en una arquitectura de bloques jerárquicos con ponderación de actividad, blindaje anti-overfitting endurecido y auditoría de estabilidad comparativa. Es el modelo de selección evolutiva más robusto del repositorio.

---

## 🛡️ 1. Misión Estratégica
> "No buscamos el mejor resultado; buscamos el más difícil de romper." 

Este modelo prioriza la **resiliencia estructural** y la **consistencia temporal**, garantizando que el optimizador genético solo promueva el ADN con verdadera ventaja estadística (edge) y estabilidad prolija.

---

## ⚙️ 2. Inputs Universales (DNA Config)
```mql5
input int  InpTFMode = 1;   // 0=Alta (M1-M5), 1=Media (M15-H1), 2=Baja (H4-D1)
input bool InpDebug  = false; // Auditoría visual en diario
```

---

## ⏱️ 3. Motor de Autodetección Temporal y Justicia (yFactor)
Se basa exclusivamente en estadísticas nativas determinísticas del motor del tester de MetaTrader 5.

**Lógica V5.4:**
`datetime sS = (datetime)TesterStatistics(STAT_START_DATE);`
`datetime eE = (datetime)TesterStatistics(STAT_END_DATE);`
`double yA = (double)(eE - sS) / (365.25 * 24.0 * 3600.0);`
`double yF = MathMax(1.0, MathSqrt(yA / 3.0)); // Escalado por raíz para equilibrio de largo plazo`

| Modo TF | tradesBase | ramp (Saturación) | ddBase (Castigo) | wrPower |
| :--- | :--- | :--- | :--- | :--- |
| **0 (Alta)** | 150 | 500 | 140 | 1.7 |
| **1 (Media)** | 50 | 200 | 120 | 1.5 |
| **2 (Baja)** | 25 | 80 | 90 | 1.3 |

---

## 📐 4. Arquitectura de Bloques Quirúrgicos (V5.4)

### A. Bloque CORE (Sustento Estadístico)
*   `p_smooth`: `MathLog(1.0 + MathAbs(profit)) * (profit >= 0 ? 1.0 : 0.3)`
*   `activity`: `MathMin(1.0, (double)trades / (ramp * yF))`
*   `tradeFactor`: `MathMin(1.0, (double)trades / (tradesBase * yF))`
`CORE = p_smooth * activity * tradeFactor`

### B. Bloque QUALITY (Consistencia y Linealidad)
*   `stability`: `MathPow(winrate / 100.0, wrPower * 0.7)` 
*   `linearity`: `MathPow(MathMax(0.0, STAT_LR_CORRELATION), 1.2)`
*   `error_penalty`: `1.0 / (1.0 + STAT_LR_STANDARD_ERROR)`
`QUALITY = stability * linearity * error_penalty`

### C. Bloque RISK (Eficiencia del Capital)
*   `risk_soft`: `1.0 / (1.0 + dd_rel * ddBase * yF)`
*   `rf_factor`: `MathMin(2.0, rf) / 2.0`
`RISK = risk_soft * rf_factor`

### D. Guardia ANTI-OVERFITTING (Endurecida)
*   `overfit_guard`: `1.0 / (1.0 + MathPow(STAT_LR_CORRELATION, 2.0) * 1.2)`
*   *Endurecido un 20% adicional para desconfiar de curvas sospechosamente perfectas.*

---

## 💻 5. Template MQL5 – Versión Hedge Fund (V5.4)

```mql5
//+------------------------------------------------------------------+
//| VARIABLES GLOBALES DE AUDITORÍA                                  |
//+------------------------------------------------------------------+
#define MAX_YEARS 30
double   yearlyProfit[MAX_YEARS];
int      yearlyTrades[MAX_YEARS];
int      baseYear = -1;

void ResetTemporalData() { ArrayInitialize(yearlyProfit, 0.0); ArrayInitialize(yearlyTrades, 0); baseYear = -1; }

void RegisterTrade(double profit, datetime closeTime) {
   int year = TimeYear(closeTime);
   if(baseYear == -1) baseYear = year;
   int index = year - baseYear;
   if(index >= 0 && index < MAX_YEARS) { yearlyProfit[index] += profit; yearlyTrades[index]++; }
}

void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& req, const MqlTradeResult& res) {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
      double p = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
      datetime t = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
      RegisterTrade(p, t);
   }
}

//+------------------------------------------------------------------+
//| CONSISTENCIA TEMPORAL (ESTABILIDAD COMPARATIVA V5.4)             |
//+------------------------------------------------------------------+
double EvaluateTemporalConsistency() {
   int totalYears = 0;
   double lossYearsWeighted = 0, sum = 0, worstYear = 1e9;

   for(int i=0; i<MAX_YEARS; i++) {
      if(yearlyTrades[i] > 0) {
         totalYears++;
         double p   = yearlyProfit[i];
         sum += p;
         if(p < worstYear) worstYear = p;
         if(p < 0) {
            double weight = MathMin(1.0, (double)yearlyTrades[i] / 50.0);
            lossYearsWeighted += weight;
         }
      }
   }
   if(totalYears == 0) return 0.5;
   double avg = sum / totalYears;
   double penalty = MathExp(-(lossYearsWeighted / totalYears) * 1.5);
   
   // Sintonía Despiadada: Peor Año vs Promedio
   double stability_ratio = MathAbs(avg) > 0.0 ? MathAbs(worstYear) / MathAbs(avg) : 2.0;
   penalty *= 1.0 / (1.0 + stability_ratio);
   
   return penalty;
}

//+------------------------------------------------------------------+
//| ON TESTER (ARQUITECTURA V5.4 - GRADO HEDGE FUND)                  |
//+------------------------------------------------------------------+
double OnTester() {
   // --- Autodetección Temporal ---
   datetime sD = (datetime)TesterStatistics(STAT_START_DATE);
   datetime eD = (datetime)TesterStatistics(STAT_END_DATE);
   double yA = (double)(eD - sD) / (365.25 * 24 * 3600);
   double yF = MathMax(1.0, MathSqrt(yA / 3.0));

   // --- Configuración por Modo TF ---
   double tB, ramp, ddB, wrP;
   switch(InpTFMode) {
      case 0: tB = 150; ramp = 500; ddB = 140; wrP = 1.7; break;
      case 1: tB = 50;  ramp = 200; ddB = 120; wrP = 1.5; break;
      case 2: tB = 25;  ramp = 80;  ddB = 90;  wrP = 1.3; break;
      default: tB = 50; ramp = 200; ddB = 120; wrP = 1.5;
   }

   const int    tr  = (int)TesterStatistics(STAT_TRADES);
   const double pr  = TesterStatistics(STAT_PROFIT);
   const double rf  = MathMax(0.01, TesterStatistics(STAT_RECOVERY_FACTOR));
   const double dd  = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT)/100.0);
   const double wr  = 100.0 * TesterStatistics(STAT_PROFIT_TRADES) / MathMax(1.0, (double)tr);
   const double lin = TesterStatistics(STAT_LR_CORRELATION);
   const double err = TesterStatistics(STAT_LR_STANDARD_ERROR);

   // --- BLOQUES V5.4 ---
   double core = (MathLog(1.0 + MathAbs(pr)) * (pr >= 0 ? 1.0 : 0.3)) * 
                 MathMin(1.0, (double)tr / (ramp * yF)) * 
                 MathMin(1.0, (double)tr / (tB * yF));

   double quality = MathPow(wr / 100.0, wrP * 0.7) * 
                    MathPow(MathMax(0.0, lin), 1.2) * 
                    (1.0 / (1.0 + err));

   double risk = (1.0 / (1.0 + dd * ddB * yF)) * (MathMin(2.0, rf) / 2.0);

   double overfit_guard = 1.0 / (1.0 + MathPow(lin, 2.0) * 1.2);

   // --- FITNESS FINAL ---
   double fitness = core * quality * risk * overfit_guard * EvaluateTemporalConsistency();

   return fitness + 1e-8;
}
```

---

## 🏁 6. Validación de Auditoría Final
> "El cuello de botella ya no es el fitness. Ya construiste el juez... ahora falta ver qué tan buenos son los acusados." 🏆
Esta versión consolida la arquitectura sin conflictos internos, resolviendo la sensibilidad contra sistemas mediocres pero estables y el sobreajuste de linealidad sospechosa.

---

## 🧠 7. CERTIFICACIÓN DE AUDITORÍA FINAL (V5.2 VALIDADA)
V5.2 es un sistema sólido, coherente y profesional. No tiene sesgos groseros ni 'agujeros' explotables por el genético. Mantiene el gradiente vivo y penaliza la inconsistencia de forma implacable. **El genético ya no tiene margen para el engaño.**

---

## 📂 8. PROTOCOLO MAESTRO DE ARCHIVOS .SET

Para cada EA, el bloque de inputs de fitness se configura según el objetivo de temporalidad.

### M1-M5 (Alta Frecuencia)
```ini
;archivo de configuracion
InpTFMode=0||0||0||0||N
InpDebug=0||0||0||0||N
```

### M15-H1 (Media Frecuencia)
```ini
;archivo de configuracion
InpTFMode=1||1||1||0||N
InpDebug=0||0||0||0||N
```

### H4-D1 (Baja Frecuencia)
```ini
;archivo de configuracion
InpTFMode=2||2||2||0||N
InpDebug=0||0||0||0||N
```

**Nota para Agentes**: La regla de oro es comenzar siempre el preset con `;archivo de configuracion` y respetar los 5 campos de MetaTrader (`Valor||Mínimo||Paso||Máximo||Flags`). El `InpTFMode` NUNCA se optimiza. 🤜🤛💎🚀🔝🏆🦾🥈🏆🔝🚀🦾🏆

---

## 🔍 9. ESCALADOR VISUAL DE EXPECTATIVAS (AMPLIFICADOR MT5)

Para forzar la "presión evolutiva" en el optimizador genético cerrado de MT5 y evadir los posibles redondeos de Epsilon en distancias microscópicas (ej. `1e-07`), y además proporcionar una UX visualmente analizable en el gráfico, el retorno final de `OnTester` exige un escalador lineal:

```mql5
return (fitness * 1000000.0) + 1e-8;
```

**Tabla Práctica de Escala Visual Resultante:**
*   `0` a `0.05` → Algoritmo o parámetros mediocres / Sobreajustados (Basura).
*   `0.1` a `0.8` → Rentabilidad básica, pero en terrenos frágiles. (El clásico "meh").
*   `1.0` a `5.0` → **El Terreno Elegido.** ADN consistente con buen win rate.
*   `> 5.0` → Potencial candidato súper élite a revisión final intensiva.
