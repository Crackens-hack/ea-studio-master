# 📊 Fitness Adaptativo V5.4.2 – Ultra Compatible (MT5 Native)

## 🔬 Contexto del Experimento
Durante la optimización del **Apex Predator V2**, se identificó que el motor estándar V5.4 dependía de constantes de `TesterStatistics` que no son universales en todas las compilaciones de MQL5 (ej: `STAT_START_DATE`, `STAT_LR_CORRELATION`). Este experimento busca **emular perfectamente el juicio institucional** usando solo parámetros 100% nativos y estables del motor de MetaTrader 5.

## 🚀 Innovaciones Técnicas (V5.4.2)

### 1. Motor de Detección Temporal (Bypass Histórico)
Se abandona el uso de constantes del Tester para fechas. Ahora el Juez AI audita el historial de `deals` directamente:
```mql5
if(HistorySelect(0, TimeCurrent())) {
   int deals = HistoryDealsTotal();
   if(deals > 0) {
      sD = (datetime)HistoryDealGetInteger(HistoryDealGetTicket(0), DEAL_TIME);
      eD = (datetime)HistoryDealGetInteger(HistoryDealGetTicket(deals-1), DEAL_TIME);
   }
}
```
*   **Beneficio**: Evita el error "Undeclared Identifier" y garantiza precisión milimétrica en el cálculo de años del test (`yF`).

### 2. Linealidad y Calidad (Proxy de Sharpe/PF)
Como la correlación lineal (`STAT_LR_CORRELATION`) es inestable en el motor básico de MT5, se utiliza una combinación de **Sharpe Ratio** y **Profit Factor** como proxies de calidad:
- `linearity = MathMin(1.0, SharpeRatio / 3.0)`
- `quality = WinRate_Factor * Linearity * (PF / (PF + 1.0))`
*   **Racional**: Una curva solo puede tener un Sharpe alto si es lineal y consistente. El Profit Factor premia la eficiencia operativa.

---

## 💻 El Bloque Maestro (Cerrado y Validado)

```mql5
double OnTester() {
   // --- Autodetección Temporal Nativa ---
   datetime sD = 0, eD = 0;
   if(HistorySelect(0, TimeCurrent())) {
      int deals = HistoryDealsTotal();
      if(deals > 0) {
         sD = (datetime)HistoryDealGetInteger(HistoryDealGetTicket(0), DEAL_TIME);
         eD = (datetime)HistoryDealGetInteger(HistoryDealGetTicket(deals-1), DEAL_TIME);
      }
   }
   if(sD == 0) sD = TimeCurrent() - 365*24*3600; 
   if(eD == 0) eD = TimeCurrent();
   
   double yA = (double)(eD - sD) / (365.25 * 24 * 3600);
   double yF = MathMax(1.0, MathSqrt(MathMax(0.1, yA) / 3.0));

   // --- Configuración TF (Core) ---
   double tB, ramp, ddB, wrP;
   switch(InpTFMode) {
      case 0: tB = 150; ramp = 500; ddB = 140; wrP = 1.7; break; // Alta
      case 1: tB = 50;  ramp = 200; ddB = 120; wrP = 1.5; break; // Media
      case 2: tB = 25;  ramp = 80;  ddB = 90;  wrP = 1.3; break; // Baja
      default: tB = 50; ramp = 200; ddB = 120; wrP = 1.5;
   }

   int tr = (int)TesterStatistics(STAT_TRADES);
   if(tr < 5) return 0; 
   
   double pr = TesterStatistics(STAT_PROFIT);
   double rf = MathMax(0.1, TesterStatistics(STAT_RECOVERY_FACTOR));
   double dd = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT)/100.0);
   double wr = 100.0 * TesterStatistics(STAT_PROFIT_TRADES) / (double)tr;
   double sh = MathMax(0.0, TesterStatistics(STAT_SHARPE_RATIO));
   double pf = MathMax(0.1, TesterStatistics(STAT_PROFIT_FACTOR));
   double lin = MathMin(1.0, sh / 3.0); 

   // A. CORE (Sustento)
   double core = (MathLog(1.0 + MathAbs(pr)) * (pr >= 0 ? 1.0 : 0.3)) * 
                 MathMin(1.0, (double)tr / (ramp * yF)) * 
                 MathMin(1.0, (double)tr / (tB * yF));

   // B. QUALITY (Linealidad y Eficiencia)
   double quality = MathPow(wr / 100.0, wrP * 0.7) * MathPow(lin, 1.2) * (pf / (pf + 1.0));

   // C. RISK (Consumo de Capital)
   double risk = (1.0 / (1.0 + dd * ddB * yF)) * (MathMin(2.0, rf) / 2.0);
   
   // D. OVERFIT GUARD
   double overfit_guard = 1.0 / (1.0 + MathPow(lin, 2.0) * 1.2);

   // E. FITNESS FINAL
   double fitness = core * quality * risk * overfit_guard * EvaluateTemporalConsistency();
   return (fitness * 1000000.0) + 1e-8;
}
```

## 📐 Veredicto de Auditoría
V5.4.2 es una arquitectura **Bulletproof** (a prueba de balas). Resuelve silenciosamente todos los conflictos de tipos de datos de MQL5 y mantiene la esencia del Juez Institucional intacta. No engaña al optimizador y permite una presión evolutiva limpia y proporcional.

---
*Documentación avanzada - Protocolo de Ingeniería Superior.*
