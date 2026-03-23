//+------------------------------------------------------------------+
//|                                                    EA_Symbiosis.mq5 |
//| Prop?sito: Ejemplo b?sico y funcional para mostrar el flujo.     |
//| L?gica: cruce SMA r?pido/lento con filtro de rango y SL/TP fijo. |
//| Cumple convenci?n Inp* para inputs y OnTester modelo Robusto.    |
//+------------------------------------------------------------------+
#property copyright "Antigravity Factory"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//--- Inputs (prefijo Inp obligatorio)
input double InpLotFixed       = 0.01;   // Lote fijo (ProCent step 0.01)
input int    InpFastPeriod     = 12;     // SMA rapida
input int    InpSlowPeriod     = 36;     // SMA lenta
input int    InpATRPeriod      = 14;     // ATR para filtro de rango
input double InpMinRangePips   = 14;     // Rango minimo (pips) para habilitar senales
input double InpSL_Pips        = 60;     // Stop Loss en pips
input double InpTP_Pips        = 200;    // Take Profit en pips
input bool   InpUseTrailing    = true;   // Activar trailing stop
input double InpTrailStartPips = 60;     // Empieza a tralear a partir de
input double InpTrailStepPips  = 25;     // Paso del trailing
input ENUM_TIMEFRAMES InpTF    = PERIOD_M15; // Timeframe operativo

//--- handles
int fastHandle = INVALID_HANDLE;
int slowHandle = INVALID_HANDLE;
int atrHandle  = INVALID_HANDLE;

//--- helpers
int    DigitsAdjust;
double PointPip;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpFastPeriod <= 0 || InpSlowPeriod <= 0 || InpFastPeriod >= InpSlowPeriod)
   {
      Print("Periodos inv?lidos: Fast < Slow y ambos > 0");
      return(INIT_PARAMETERS_INCORRECT);
   }

   DigitsAdjust = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   PointPip = (DigitsAdjust == 3 || DigitsAdjust == 5) ? 10 * _Point : _Point;

   fastHandle = iMA(_Symbol, InpTF, InpFastPeriod, 0, MODE_SMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, InpTF, InpSlowPeriod, 0, MODE_SMA, PRICE_CLOSE);
   atrHandle  = iATR(_Symbol, InpTF, InpATRPeriod);

   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Error creando handles");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(fastHandle!=INVALID_HANDLE) IndicatorRelease(fastHandle);
   if(slowHandle!=INVALID_HANDLE) IndicatorRelease(slowHandle);
   if(atrHandle !=INVALID_HANDLE) IndicatorRelease(atrHandle);
}
//+------------------------------------------------------------------+
void OnTick()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
   if(PositionsTotal() > 0) ManageTrailing();

   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, InpTF, 0);
   if(currentBar == lastBar) return; // solo en cierre de vela
   lastBar = currentBar;

   double fast[3], slow[3], atr[3];
   if(CopyBuffer(fastHandle, 0, 0, 3, fast) < 3) return;
   if(CopyBuffer(slowHandle, 0, 0, 3, slow) < 3) return;
   if(CopyBuffer(atrHandle,  0, 0, 3, atr)  < 3) return;

   double rangePips = atr[1] / PointPip;
   if(rangePips < InpMinRangePips) return; // filtro de calma

   bool crossUp   = fast[1] > slow[1] && fast[2] <= slow[2];
   bool crossDown = fast[1] < slow[1] && fast[2] >= slow[2];

   // una sola posici?n a la vez, reversible
   if(crossUp)
   {
      CloseAll();
      OpenOrder(ORDER_TYPE_BUY);
   }
   else if(crossDown)
   {
      CloseAll();
      OpenOrder(ORDER_TYPE_SELL);
   }
}
//+------------------------------------------------------------------+
void OpenOrder(const ENUM_ORDER_TYPE type)
{
   double sl = InpSL_Pips * PointPip;
   double tp = InpTP_Pips * PointPip;

   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slPrice = (type == ORDER_TYPE_BUY) ? price - sl : price + sl;
   double tpPrice = (type == ORDER_TYPE_BUY) ? price + tp : price - tp;

   trade.SetAsyncMode(false);
   trade.SetDeviationInPoints(20);
   trade.PositionOpen(_Symbol, type, InpLotFixed, price, slPrice, tpPrice, "EA_Symbiosis");
}
//+------------------------------------------------------------------+
void CloseAll()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      trade.PositionClose(ticket, 20); // close by ticket with small deviation
   }
}
//+------------------------------------------------------------------+
void ManageTrailing()
{
   if(!InpUseTrailing) return;
   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double price     = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double trailStart = InpTrailStartPips * PointPip;
      double trailStep  = InpTrailStepPips  * PointPip;

      if(type == POSITION_TYPE_BUY)
      {
         double profitPips = (price - openPrice) / PointPip;
         if(profitPips < InpTrailStartPips) continue;
         double newSL = price - trailStep;
         if(newSL > sl) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double profitPips = (openPrice - price) / PointPip;
         if(profitPips < InpTrailStartPips) continue;
         double newSL = price + trailStep;
         if(sl == 0 || newSL < sl) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
   }
}
//+------------------------------------------------------------------+
double OnTester()
{
   const int    trades    = (int)TesterStatistics(STAT_TRADES);
   const double profit    = TesterStatistics(STAT_PROFIT);
   const double pf        = TesterStatistics(STAT_PROFIT_FACTOR);
   const double rf        = TesterStatistics(STAT_RECOVERY_FACTOR);
   const double dd_rel    = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT) / 100.0);
   const double g_loss    = MathAbs(TesterStatistics(STAT_GROSS_LOSS));
   const double payoff    = g_loss < 0.0001 ? 0.0 : TesterStatistics(STAT_GROSS_PROFIT) / g_loss;
   const double winrate   = 100.0 * (double)TesterStatistics(STAT_PROFIT_TRADES) / MathMax(1.0, (double)trades);

   const int    min_trades = 50;   // H1/M15 por defecto
   const double rampa_div  = 200.0;

   if(trades < min_trades || pf <= 1.0 || profit <= 0) return 0.0;

   double rampa   = MathMin(1.0, (double)trades / rampa_div);
   double fitness = (pf * rf * payoff) * rampa / (1.0 + dd_rel);

   PrintFormat("PF=%.2f RF=%.2f Payoff=%.2f WR=%.1f%% Trades=%d DD=%.2f%% Fit=%.4f",
               pf, rf, payoff, winrate, trades, dd_rel * 100.0, fitness);
   return fitness;
}
//+------------------------------------------------------------------+
