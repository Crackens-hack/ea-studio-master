//+------------------------------------------------------------------+
//|                                              Apex_Predator_V2.mq5 |
//|                                  Copyright 2026, Antigravity AI   |
//|                                     "The Ghost Hunter Evolution"  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://ea-studio.com"
#property version   "2.01"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| ESTRUCTURA DE INPUTS (REGLA Inp + DUCKDB SYMMETRY)               |
//+------------------------------------------------------------------+
input group "=== LÓGICA CORE: REVERSIÓN A LA MEDIA ==="
input int      InpBBPeriod       = 20;      // Periodo Bandas Bollinger
input double   InpBBDialation    = 2.5;     // Desviación Estándar BB
input int      InpRSIPeriod      = 14;      // Periodo RSI
input double   InpRSIOverbought  = 70.0;    // Nivel RSI Sobrecompra
input double   InpRSIOversold    = 30.0;    // Nivel RSI Sobreventa

input group "=== FILTROS DE INTELIGENCIA (V2 GHOST HUNTER) ==="
input bool     InpUseEMAFilter   = true;    // EMA 200: Solo operar a favor del flujo mayor
input int      InpEMAPeriod      = 200;     // Periodo de la EMA de Contexto
input bool     InpUseADXFilter   = true;    // ADX: Evitar entradas en tendencias fuertes
input int      InpADXPeriod      = 14;      // Periodo ADX
input int      InpADXThreshold   = 30;      // Nivel máximo ADX (Si > Threshold = Peligro)

input group "=== GESTIÓN DE RIESGO (1:1 SYMMETRY) ==="
input double   InpLotSize        = 0.10;    // Lote Fijo (Modo 5000 ProCent)
input int      InpATRPeriod      = 14;      // Periodo ATR para SL/TP
input double   InpATR_SL_Mult    = 3.0;     // Multiplicador ATR para SL
input double   InpATR_TP_Mult    = 1.0;     // Multiplicador ATR para TP
input bool     InpUseFixedPerc   = false;   // Compounding (MERO TESTER - APAGADO)
input double   InpRiskPercent    = 2.0;     // % de Riesgo (Protocolo Fenix)
input int      InpMaxSpread      = 30;      // Máximo Spread Permitido (Points)

input group "=== PROTECCIÓN Y TRAILING ==="
input bool     InpUseTrailing    = true;    // Activar Trailing Stop
input double   InpTrailingATRMult= 1.5;     // Multiplicador ATR para Trailing
input double   InpTrailingTrigger= 1.0;     // Gatillo Beneficio Mínimo

input group "=== FITNESS ADAPTATIVO V5.4.1 ==="
input int      InpTFMode         = 1;       // 0=Alta (M1-M5), 1=Media (M15-H1), 2=Baja (H4-D1)
input bool     InpDebug          = false;   // Auditoría visual

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade  trade;
int     handleBB, handleRSI, handleATR, handleEMA, handleADX;

// Auditoría Temporal para Fitness V5.4.1
#define MAX_YEARS 30
double   yearlyProfit[MAX_YEARS];
int      yearlyTrades[MAX_YEARS];
int      baseYear = -1;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   ArrayInitialize(yearlyProfit, 0.0);
   ArrayInitialize(yearlyTrades, 0);
   baseYear = -1;

   handleBB  = iBands(_Symbol, _Period, InpBBPeriod, 0, InpBBDialation, PRICE_CLOSE);
   handleRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   handleEMA = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleADX = iADX(_Symbol, _Period, InpADXPeriod);

   if(handleBB == INVALID_HANDLE || handleRSI == INVALID_HANDLE || handleATR == INVALID_HANDLE || 
      handleEMA == INVALID_HANDLE || handleADX == INVALID_HANDLE) {
      Print("Error inicializando indicadores de la V2.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(666992);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

bool CanTrade() {
   return (PositionsTotal() == 0);
}

//+------------------------------------------------------------------+
//| ON TICK Y LÓGICA COMERCIAL                                       |
//+------------------------------------------------------------------+
void OnTick() {
   ApplyTrailing();
   if(!CanTrade()) return;

   static datetime lastBar = 0;
   datetime currBar = iTime(_Symbol, _Period, 0);
   if(lastBar == currBar) return;
   lastBar = currBar;

   double bbUp[1], bbDn[1], rsi[1], atr[1], ema[1], adx[1];
   if(CopyBuffer(handleBB, UPPER_BAND, 1, 1, bbUp) <= 0) return;
   if(CopyBuffer(handleBB, LOWER_BAND, 1, 1, bbDn) <= 0) return;
   if(CopyBuffer(handleRSI, 0, 1, 1, rsi) <= 0) return;
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;
   if(CopyBuffer(handleEMA, 0, 1, 1, ema) <= 0) return;
   if(CopyBuffer(handleADX, 0, 1, 1, adx) <= 0) return;

   double close1 = iClose(_Symbol, _Period, 1);
   
   if(InpUseADXFilter && adx[0] > InpADXThreshold) return;

   bool allowBuy = true, allowSell = true;
   if(InpUseEMAFilter) {
      allowBuy = (close1 > ema[0]);
      allowSell = (close1 < ema[0]);
   }

   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread) return;

   double lot = InpLotSize;
   if(InpUseFixedPerc) {
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double stopPoints = (atr[0] * InpATR_SL_Mult) / _Point;
      if(stopPoints > 0) lot = NormalizeDouble(riskAmount / (stopPoints * tickValue), 2);
   }
   lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   lot = MathMin(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));

   double sl_dist = atr[0] * InpATR_SL_Mult;
   double tp_dist = atr[0] * InpATR_TP_Mult;

   if(allowBuy && close1 < bbDn[0] && rsi[0] < InpRSIOversold) {
      double sl = NormalizeDouble(close1 - sl_dist, _Digits);
      double tp = NormalizeDouble(close1 + tp_dist, _Digits);
      trade.Buy(lot, _Symbol, 0, sl, tp, "Apex_V2_GhostBuy");
   }
   else if(allowSell && close1 > bbUp[0] && rsi[0] > InpRSIOverbought) {
      double sl = NormalizeDouble(close1 + sl_dist, _Digits);
      double tp = NormalizeDouble(close1 - tp_dist, _Digits);
      trade.Sell(lot, _Symbol, 0, sl, tp, "Apex_V2_GhostSell");
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP BASADO EN ATR                                      |
//+------------------------------------------------------------------+
void ApplyTrailing() {
   if(!InpUseTrailing) return;
   double atr[1];
   if(CopyBuffer(handleATR, 0, 0, 1, atr) <= 0) return;
   double trailDist = atr[0] * InpTrailingATRMult;
   double triggerDist = atr[0] * InpTrailingTrigger;

   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         if(PositionGetInteger(POSITION_MAGIC) != 666992) continue;
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double sl = PositionGetDouble(POSITION_SL);
         double op = PositionGetDouble(POSITION_PRICE_OPEN);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         if(type == POSITION_TYPE_BUY && bid > op + triggerDist) { 
            double newSL = NormalizeDouble(bid - trailDist, _Digits);
            if(newSL > sl + _Point * 10 || sl == 0) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
         else if(type == POSITION_TYPE_SELL && ask < op - triggerDist) { 
            double newSL = NormalizeDouble(ask + trailDist, _Digits);
            if(newSL < sl - _Point * 10 || sl == 0) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ON TRADE TRANSACTION (FITNESS V5.4.1)                            |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& req, const MqlTradeResult& res) {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      if(HistoryDealSelect(trans.deal)) {
         long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT) {
            double p = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            datetime t = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
            MqlDateTime dt;
            TimeToStruct(t, dt);
            if(baseYear == -1) baseYear = dt.year;
            int idx = dt.year - baseYear;
            if(idx >= 0 && idx < MAX_YEARS) { yearlyProfit[idx] += p; yearlyTrades[idx]++; }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CONSISTENCIA TEMPORAL (ESTABILIDAD COMPARATIVA V5.4.1)           |
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
         if(p < 0) lossYearsWeighted += MathMin(1.0, (double)yearlyTrades[i] / 50.0);
      }
   }
   if(totalYears == 0) return 0.5;
   double avg = sum / totalYears;
   double penalty = MathExp(-(lossYearsWeighted / (double)totalYears) * 1.5);
   double stability_ratio = MathAbs(avg) > 0.0 ? MathAbs(worstYear) / MathAbs(avg) : 2.0;
   return penalty * (1.0 / (1.0 + stability_ratio));
}

//+------------------------------------------------------------------+
//| ON TESTER (ARQUITECTURA V5.4.2 - ULTRA COMPATIBLE)               |
//+------------------------------------------------------------------+
double OnTester() {
   // --- Autodetección Temporal vía Historial (Única forma 100% segura en MT5) ---
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

   double tB, ramp, ddB, wrP;
   switch(InpTFMode) {
      case 0: tB = 150; ramp = 500; ddB = 140; wrP = 1.7; break;
      case 1: tB = 50;  ramp = 200; ddB = 120; wrP = 1.5; break;
      case 2: tB = 25;  ramp = 80;  ddB = 90;  wrP = 1.3; break;
      default: tB = 50; ramp = 200; ddB = 120; wrP = 1.5;
   }

   int tr = (int)TesterStatistics(STAT_TRADES);
   if(tr < 5) return 0; 
   
   double pr = TesterStatistics(STAT_PROFIT);
   double rf = MathMax(0.1, TesterStatistics(STAT_RECOVERY_FACTOR));
   double dd = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT)/100.0);
   double wr = 100.0 * TesterStatistics(STAT_PROFIT_TRADES) / (double)tr;
   
   // Usamos Sharpe y Profit Factor como proxies de linealidad en MT5 nativo
   double sh = MathMax(0.0, TesterStatistics(STAT_SHARPE_RATIO));
   double pf = MathMax(0.1, TesterStatistics(STAT_PROFIT_FACTOR));
   double lin = MathMin(1.0, sh / 3.0); 

   double core = (MathLog(1.0 + MathAbs(pr)) * (pr >= 0 ? 1.0 : 0.3)) * 
                 MathMin(1.0, (double)tr / (ramp * yF)) * 
                 MathMin(1.0, (double)tr / (tB * yF));

   double quality = MathPow(wr / 100.0, wrP * 0.7) * MathPow(lin, 1.2) * (pf / (pf + 1.0));

   double risk = (1.0 / (1.0 + dd * ddB * yF)) * (MathMin(2.0, rf) / 2.0);
   double overfit_guard = 1.0 / (1.0 + MathPow(lin, 2.0) * 1.2);

   double fitness = core * quality * risk * overfit_guard * EvaluateTemporalConsistency();
   return (fitness * 1000000.0) + 1e-8;
}
