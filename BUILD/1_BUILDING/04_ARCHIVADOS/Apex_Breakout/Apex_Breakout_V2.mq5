//+------------------------------------------------------------------+
//|                                              Apex_Breakout_V2.mq5 |
//|                                  Copyright 2026, Antigravity AI   |
//|                                             https://ea-studio.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://ea-studio.com"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| ESTRUCTURA DE INPUTS (REGLA Inp + DUCKDB SYMMETRY)               |
//+------------------------------------------------------------------+
input group "=== CONFIGURACIÓN DE ESTRATEGIA ==="
input int      InpDonchianPeriod = 12;      // Periodo Canal Donchian
input int      InpADXPeriod      = 14;      // Periodo ADX (Trend Strength)
input double   InpADXMinLevel    = 20.0;    // Nivel Mínimo ADX para entrar
input int      InpSlopePeriod    = 20;      // Periodo de Pendiente (Péndulo LR)
input double   InpSlopeThreshold = 0.000005; // Umbral de Pendiente (Péndulo)

input group "=== GESTIÓN DE RIESGO (1:1 SYMMETRY) ==="
input double   InpLotSize        = 0.10;    // Lote Fijo (Modo 5000 ProCent)
input int      InpATRPeriod      = 14;      // Periodo ATR para SL/TP
input double   InpATR_SL_Mult    = 2.0;     // Multiplicador ATR para SL
input double   InpATR_TP_Mult    = 2.0;     // Multiplicador ATR para TP (Simetría)
input bool     InpUseFixedPerc   = false;   // Usar % de Balance (Compounding)
input double   InpRiskPercent    = 1.0;     // % de Riesgo por Trade
input int      InpMaxSpread      = 30;      // Máximo Spread Permitido (Points)

input group "=== PROTECCIÓN Y TRAILING ==="
input bool     InpUseTrailing    = true;    // Activar Trailing Stop
input double   InpTrailingATRMult= 1.5;     // Multiplicador ATR para Trailing

input group "=== FITNESS ADAPTATIVO V5.4 ==="
input int      InpTFMode         = 1;       // 0=Alta (M1-M5), 1=Media (M15-H1), 2=Baja (H4-D1)
input bool     InpDebug          = true;    // Auditoría visual ACTIVADA

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade  trade;
int     handleDonchian, handleADX, handleATR;
double  bufHigh[], bufLow[], bufADX[], bufATR[];

// Auditoría Temporal para Fitness V5.4
#define MAX_YEARS 30
double   yearlyProfit[MAX_YEARS];
int      yearlyTrades[MAX_YEARS];
int      baseYear = -1;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Reset de auditoría fitness
   ArrayInitialize(yearlyProfit, 0.0);
   ArrayInitialize(yearlyTrades, 0);
   baseYear = -1;

   // Handles de indicadores
   // handleDonchian = iHighest(_Symbol, _Period, MODE_HIGH, InpDonchianPeriod, 1); 
   // Optamos por cálculo manual en OnTick para evitar duplicados de handles y dependencias.
   
   handleADX = iADX(_Symbol, _Period, InpADXPeriod);
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);

   if(handleADX == INVALID_HANDLE || handleATR == INVALID_HANDLE) {
      Print("Error inicializando indicadores.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(123456);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
//| RESTRICCIÓN DE UN TRADE A LA VEZ                                |
//+------------------------------------------------------------------+
bool CanTrade() {
   return (PositionsTotal() == 0);
}

//+------------------------------------------------------------------+
//| CÁLCULO DE PENDIENTE (PÉNDULO LR)                                |
//+------------------------------------------------------------------+
double GetSlope(int period) {
   double sumX=0, sumY=0, sumXY=0, sumX2=0;
   for(int i=0; i<period; i++) {
      double close = iClose(_Symbol, _Period, i);
      sumX  += i;
      sumY  += close;
      sumXY += i * close;
      sumX2 += i * i;
   }
   double slope = (period * sumXY - sumX * sumY) / (period * sumX2 - sumX * sumX);
   return -slope; // Invertimos porque i=0 es la vela actual (más reciente)
}

//+------------------------------------------------------------------+
//| ON TICK                                                          |
//+------------------------------------------------------------------+
void OnTick() {
   ApplyTrailing();
   
   if(!CanTrade()) return;

   // Solo operamos al inicio de una vela para mayor estabilidad
   static datetime lastBar = 0;
   datetime currBar = iTime(_Symbol, _Period, 0);
   if(lastBar == currBar) return;
   lastBar = currBar;

   // Obtener datos Donchian (calculados desde la vela 2 para comparar con vela 1)
   double highest = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, InpDonchianPeriod, 2));
   double lowest  = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, InpDonchianPeriod, 2));
   
   double adx[1], atr[1];
   if(CopyBuffer(handleADX, 0, 0, 1, adx) <= 0) return;
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;

   double slope = GetSlope(InpSlopePeriod);
   double close1 = iClose(_Symbol, _Period, 1);
   
   // FILTROS COORDINADOS
   bool trendFilter = (MathAbs(slope) > InpSlopeThreshold);
   bool adxFilter   = (adx[0] > InpADXMinLevel);
   
   // Filtro de Spread
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread) return;

   if(InpDebug) {
      PrintFormat("DEBUG: C1:%.5f | High:%.5f | Low:%.5f | Slope:%.6f | ADX:%.2f | Spread:%d", close1, highest, lowest, slope, adx[0], (int)spread);
   }

   if(!trendFilter || !adxFilter) return;

   double lot = InpLotSize;
   if(InpUseFixedPerc) {
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double stopPoints = (atr[0] * InpATR_SL_Mult) / _Point;
      if(stopPoints > 0) lot = NormalizeDouble(riskAmount / (stopPoints * tickValue), 2);
   }
   lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   lot = MathMin(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));

   // Protección contra Stop Level (Mínimo del Broker)
   long stoplevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stoplevel == 0) stoplevel = spread * 2; // Fallback agresivo si el broker reporta 0
   double min_stop = MathMax((double)stoplevel * _Point, spread * _Point * 1.5);

   double sl_dist = MathMax(atr[0] * InpATR_SL_Mult, min_stop);
   double tp_dist = MathMax(atr[0] * InpATR_TP_Mult, min_stop);

   // BREAKOUT BUY (CON ALINEACIÓN DE PÉNDULO)
   if(close1 > highest && slope > InpSlopeThreshold) {
      double sl = NormalizeDouble(close1 - sl_dist, _Digits);
      double tp = NormalizeDouble(close1 + tp_dist, _Digits);
      trade.Buy(lot, _Symbol, 0, sl, tp, "Apex Breakout Buy aligned");
   }
   // BREAKOUT SELL (CON ALINEACIÓN DE PÉNDULO)
   else if(close1 < lowest && slope < -InpSlopeThreshold) {
      double sl = NormalizeDouble(close1 + sl_dist, _Digits);
      double tp = NormalizeDouble(close1 - tp_dist, _Digits);
      trade.Sell(lot, _Symbol, 0, sl, tp, "Apex Breakout Sell aligned");
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP BASADO EN ATR                                      |
//+------------------------------------------------------------------+
void ApplyTrailing() {
   if(!InpUseTrailing) return;
   
   double atr[1];
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;
   
   // Protección Stop Level en Trailing
   long stoplevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stoplevel == 0) stoplevel = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * 2;
   double min_stop = (double)stoplevel * _Point;
   
   double trailDist = MathMax(atr[0] * InpTrailingATRMult, min_stop);

   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;
         
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double sl = PositionGetDouble(POSITION_SL);
         double op = PositionGetDouble(POSITION_PRICE_OPEN);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         // ACTIVATION TRIGGER: Solo activamos trailing si hay al menos 1 ATR de ganancia libre
         double triggerDist = atr[0] * 1.0; 

         if(type == POSITION_TYPE_BUY) {
            if(bid > op + triggerDist) { // Solo si rompió y confirmó por encima del trigger
               double newSL = NormalizeDouble(bid - trailDist, _Digits);
               if(newSL > sl + _Point * 10 || sl == 0) { 
                  trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
               }
            }
         }
         else if(type == POSITION_TYPE_SELL) {
            if(ask < op - triggerDist) { // Solo si rompió y confirmó por debajo del trigger
               double newSL = NormalizeDouble(ask + trailDist, _Digits);
               if(newSL < sl - _Point * 10 || sl == 0) {
                  trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| REGISTRO DE TRADES PARA FITNESS                                  |
//+------------------------------------------------------------------+
void RegisterTrade(double profit, datetime closeTime) {
   MqlDateTime dt;
   TimeToStruct(closeTime, dt);
   int year = dt.year;
   if(baseYear == -1) baseYear = year;
   int index = year - baseYear;
   if(index >= 0 && index < MAX_YEARS) { yearlyProfit[index] += profit; yearlyTrades[index]++; }
}

void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& req, const MqlTradeResult& res) {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      if(HistoryDealSelect(trans.deal)) {
         long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT) {
            double p = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            datetime t = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
            RegisterTrade(p, t);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ON TESTER (ARQUITECTURA V5.4 - GRADO HEDGE FUND)                  |
//+------------------------------------------------------------------+
double EvaluateTemporalConsistency() {
   int totalYears = 0;
   double lossYearsWeighted = 0, sum = 0, worstYear = 1e9;
   for(int i=0; i<MAX_YEARS; i++) {
      if(yearlyTrades[i] > 0) {
         totalYears++;
         double p = yearlyProfit[i];
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
   double penalty = MathExp(-(lossYearsWeighted / (double)totalYears) * 1.5);
   double stability_ratio = MathAbs(avg) > 0.0 ? MathAbs(worstYear) / MathAbs(avg) : 2.0;
   penalty *= 1.0 / (1.0 + stability_ratio);
   return penalty;
}

double OnTester() {
   // --- Autodetección Temporal via Historia (Más robusto que STAT_START_DATE) ---
   datetime sD = 0, eD = 0;
   if(HistorySelect(0, TimeCurrent())) {
      int deals = HistoryDealsTotal();
      if(deals > 0) {
         sD = (datetime)HistoryDealGetInteger(HistoryDealGetTicket(0), DEAL_TIME);
         eD = (datetime)HistoryDealGetInteger(HistoryDealGetTicket(deals-1), DEAL_TIME);
      }
   }
   if(sD == 0) sD = TimeCurrent() - 365*24*3600; // Fallback 1 año
   if(eD == 0) eD = TimeCurrent();
   
   double yA = (double)(eD - sD) / (365.25 * 24 * 3600);
   double yF = MathMax(1.0, MathSqrt(MathMax(0.1, yA) / 3.0));

   double tB, ramp, ddB, wrP;
   switch(InpTFMode) {
      case 0: tB = 150; ramp = 500; ddB = 140; wrP = 1.7; break;
      case 1: tB = 50;  ramp = 200; ddB = 120; wrP = 1.5; break;
      case 2: tB = 25;  ramp = 80;  ddB = 90;  wrP = 1.3; break;
      default: tB = 50; ramp = 200; ddB = 120; wrP = 1.5;
   }

   const int tr = (int)TesterStatistics(STAT_TRADES);
   if(tr < 5) return 0; 
   
   const double pr  = TesterStatistics(STAT_PROFIT);
   const double rf  = MathMax(0.01, TesterStatistics(STAT_RECOVERY_FACTOR));
   const double dd  = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT)/100.0);
   const double wr  = 100.0 * TesterStatistics(STAT_PROFIT_TRADES) / (double)tr;
   
   // Fallback para estadísticas de regresión si no están en la build
   double lin = 0.7; // Default conservador si falla
   double err = 0.5;
   
   // Intentamos capturar las estadísticas si existen (usando cast para evitar error de compilación si la build es caprichosa)
   // Pero como el compilador falló antes, mejor usamos alternativas universales:
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   lin = MathMin(1.0, MathMax(0.1, sharpe / 3.0)); // Aproximación de linealidad vía Sharpe
   err = 1.0 / (1.0 + rf); // Aproximación de error vía Factor de Recuperación

   double core = (MathLog(1.0 + MathAbs(pr)) * (pr >= 0 ? 1.0 : 0.3)) * 
                 MathMin(1.0, (double)tr / (ramp * yF)) * 
                 MathMin(1.0, (double)tr / (tB * yF));

   double quality = MathPow(wr / 100.0, wrP * 0.7) * 
                    MathPow(lin, 1.2) * 
                    (1.0 / (1.0 + err));

   double risk = (1.0 / (1.0 + dd * ddB * yF)) * (MathMin(2.0, rf) / 2.0);
   double overfit_guard = 1.0 / (1.0 + MathPow(lin, 2.0) * 1.2);

   double fitness = core * quality * risk * overfit_guard * EvaluateTemporalConsistency();
   
   // ESCALADOR VISUAL (Recomendación Genética)
   // Multiplicamos por 1,000,000 para que la tabla Result sea humanamente legible
   // y evitemos el bug de tolerancia Epsilon en el optimizador genético cerrado de MT5.
   return (fitness * 1000000.0) + 1e-8;
}
