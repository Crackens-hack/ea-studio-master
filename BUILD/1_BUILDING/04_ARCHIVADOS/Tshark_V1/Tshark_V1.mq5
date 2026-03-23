//+------------------------------------------------------------------+
//|                                                    Tshark_V1.mq5 |
//|                                  Copyright 2024, Trading Agente  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Trading Agente"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Include Trade class
#include <Trade\Trade.mqh>
#include <Expert\Expert.mqh>

//--- Enums ---
enum ENUM_ENTRY_MODE {
   ENTRY_CLOSE_INSIDE, // Close Inside Bands
   ENTRY_CROSSOVER    // RSI Crossover
};

//--- INPUT PARAMETERS ---
input group "=== Trading Settings ==="
input double      InpRiskPercent    = 2.0;      // Risk Percent per Trade (%)
input double      InpStopLossAtR    = 1.5;      // Stop Loss (ATR Multiplier)
input double      InpTakeProfitATR  = 3.0;      // Take Profit (ATR Multiplier)
input int         InpMagicNumber    = 123456;   // Magic Number
input int         InpMaxSpread      = 30;       // Max Spread (Points)
input int         InpStopLossPoints = 500;      // Min SL (Points) fallback

input group "=== RSI Settings ==="
input int         InpRSIPeriod     = 14;       // RSI Period
input int         InpRSIUpper      = 70;       // RSI Upper Level
input int         InpRSILower      = 30;       // RSI Lower Level

input group "=== Bollinger Bands ==="
input int         InpBBPeriod      = 20;       // BB Period
input double      InpBBDeviation   = 2.0;      // BB Deviation
input int         InpBBShift       = 0;        // BB Shift

input group "=== ATR Settings ==="
input int         InpATRPeriod     = 14;       // ATR Period

input group "=== Optimization Settings ==="
input double      InpMinProfitFactor = 1.3;     // Min Profit Factor for OnTester
input double      InpMaxDrawdown     = 25.0;     // Max Drawdown (%) for OnTester

//--- GLOBAL VARIABLES ---
CTrade      m_trade;
int         h_rsi, h_bb, h_atr;
double      buffer_rsi[], buffer_bb_up[], buffer_bb_low[], buffer_bb_mid[], buffer_atr[];
datetime    last_candle_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate inputs
   if(InpRiskPercent <= 0) return(INIT_PARAMETERS_INCORRECT);

   // Initialize indicators
   h_rsi = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   h_bb  = iBands(_Symbol, _Period, InpBBPeriod, InpBBShift, InpBBDeviation, PRICE_CLOSE);
   h_atr = iATR(_Symbol, _Period, InpATRPeriod);

   if(h_rsi == INVALID_HANDLE || h_bb == INVALID_HANDLE || h_atr == INVALID_HANDLE) {
      Print("Error initializing indicators");
      return(INIT_FAILED);
   }

   m_trade.SetExpertMagicNumber(InpMagicNumber);

   // Set buffers to series
   ArraySetAsSeries(buffer_rsi, true);
   ArraySetAsSeries(buffer_bb_up, true);
   ArraySetAsSeries(buffer_bb_low, true);
   ArraySetAsSeries(buffer_bb_mid, true);
   ArraySetAsSeries(buffer_atr, true);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_bb);
   IndicatorRelease(h_atr);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new candle
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time == last_candle_time) return;
   last_candle_time = current_time;

   // Copy indicator data
   if(CopyBuffer(h_rsi, 0, 0, 3, buffer_rsi) < 3) return;
   if(CopyBuffer(h_bb, 1, 0, 3, buffer_bb_up) < 3) return;
   if(CopyBuffer(h_bb, 2, 0, 3, buffer_bb_low) < 3) return;
   if(CopyBuffer(h_bb, 0, 0, 3, buffer_bb_mid) < 3) return;
   if(CopyBuffer(h_atr, 0, 0, 3, buffer_atr) < 3) return;

   // Check spread
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread) {
      //Print("Spread too high: ", spread);
      return;
   }

   // Strategy Logic
   bool is_long_signal = (iClose(_Symbol, _Period, 1) < buffer_bb_low[1] && buffer_rsi[1] < InpRSILower);
   bool is_short_signal = (iClose(_Symbol, _Period, 1) > buffer_bb_up[1] && buffer_rsi[1] > InpRSIUpper);

   // Check if already in position
   if(!PositionSelectByMagic(InpMagicNumber)) {
      if(is_long_signal) OpenPosition(ORDER_TYPE_BUY);
      else if(is_short_signal) OpenPosition(ORDER_TYPE_SELL);
   }
   else {
      // Exit Logic or Management
      // For now, simple BE or TP/SL will handle exits
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_points)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double money_risk = balance * (InpRiskPercent / 100.0);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(sl_points <= 0 || tick_value <= 0) return(min_lot);

   double lot = money_risk / (sl_points * (_Point / tick_size) * tick_value);
   
   lot = MathFloor(lot / lot_step) * lot_step;
   
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;

   return(lot);
}

//+------------------------------------------------------------------+
//| Open Position                                                    |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE type)
{
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = buffer_atr[1];
   double sl_dist = atr * InpStopLossAtR;
   double tp_dist = atr * InpTakeProfitATR;

   double sl = (type == ORDER_TYPE_BUY) ? (price - sl_dist) : (price + sl_dist);
   double tp = (type == ORDER_TYPE_BUY) ? (price + tp_dist) : (price - tp_dist);

   double sl_points = MathAbs(price - sl) / _Point;
   double lot = CalculateLotSize(sl_points);

   if(!m_trade.PositionOpen(_Symbol, type, lot, price, sl, tp, "Tshark_V1")) {
      Print("Error opening position: ", m_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Optimization Fitness (OnTester)                                  |
//+------------------------------------------------------------------+
double OnTester()
{
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);
   double draw = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double trades = TesterStatistics(STAT_TRADES);
   double recovery = TesterStatistics(STAT_RECOVERY_FACTOR);
   double winrate = (double)TesterStatistics(STAT_PROFIT_TRADES) / trades;

   // Custom Fitness Function: Balance of PF, Winrate and Drawdown
   // Penalty for low trades or high drawdown
   if(trades < 50 || draw > InpMaxDrawdown || pf < InpMinProfitFactor) return(0.0);

   // T-Shark Fitness: High Profitability * Recovery Factor / (1 + Drawdown)
   double fitness = (pf * recovery * winrate * 10.0) / (1.0 + draw);

   return(fitness);
}

//+------------------------------------------------------------------+
//| Helper to select position by magic                              |
//+------------------------------------------------------------------+
bool PositionSelectByMagic(long magic)
{
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return(true);
      }
   }
   return(false);
}
//+------------------------------------------------------------------+
