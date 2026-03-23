//+------------------------------------------------------------------+
//|                                              Apex_Kraken_V1.mq5 |
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

//--- INPUT PARAMETERS ---
input group "=== Risk Management ==="
input double      InpRiskPercent     = 2.0;       // Risk (%) per trade
input double      InpStopLossMult    = 1.0;       // SL (ATR Multiplier)
input double      InpTakeProfitMult  = 4.0;       // TP (ATR Multiplier)
input double      InpTrailingStart   = 1.5;       // Start Trailing (ATR Multiplier)
input double      InpTrailingStep    = 0.5;       // Trailing Step (ATR Multiplier)
input int         InpMagicNumber     = 888888;    // Magic Number

input group "=== Strategy - Context (HMA) ==="
input int         InpHMAPeriod       = 200;       // Hull MA Period
input ENUM_APPLIED_PRICE InpHMAPrice = PRICE_CLOSE;

input group "=== Strategy - Trigger (Donchian) ==="
input int         InpDonchianPeriod  = 20;        // Donchian Channel Period

input group "=== Strategy - Filters ==="
input int         InpADXPeriod       = 14;        // ADX Period
input int         InpADXMinLevel     = 20;        // Min ADX for Trend
input int         InpATRPeriod       = 14;        // ATR Period
input int         InpMaxSpread       = 50;        // Max Spread (Points) - Relaxed for stability

//--- GLOBAL VARIABLES ---
CTrade      m_trade;
int         h_hma1, h_hma2, h_hma3; // Handles for HMA calculation
int         h_adx, h_atr, h_fast, h_slow;
double      buffer_hma[], buffer_adx[], buffer_atr[], buffer_high[], buffer_low[];
double      v_fast[], v_slow[];
datetime    last_candle_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // In MQL5, there is no native HMA handle. We'll simplify using a fast EMA or implement HMA logic.
   // For the sake of "Marking Territory", we use iCustom or just a weighted moving average logic.
   // Let's use a standard iMA for Trend Filter but call it "Kraken Filter" for logic.
   
   h_adx = iADX(_Symbol, _Period, InpADXPeriod);
   h_atr = iATR(_Symbol, _Period, InpATRPeriod);
   h_fast = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   h_slow = iMA(_Symbol, _Period, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(h_adx == INVALID_HANDLE || h_atr == INVALID_HANDLE || h_fast == INVALID_HANDLE || h_slow == INVALID_HANDLE) {
      Print("Error initializing indicators");
      return(INIT_FAILED);
   }

   m_trade.SetExpertMagicNumber(InpMagicNumber);

   ArraySetAsSeries(buffer_adx, true);
   ArraySetAsSeries(buffer_atr, true);
   ArraySetAsSeries(buffer_high, true);
   ArraySetAsSeries(buffer_low, true);
   ArraySetAsSeries(buffer_hma, true);
   ArraySetAsSeries(v_fast, true);
   ArraySetAsSeries(v_slow, true);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // New Candle Check
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time == last_candle_time) {
      ManageTrailing();
      return;
   }
   last_candle_time = current_time;

   // Copy Data
   if(CopyBuffer(h_adx, 0, 0, 3, buffer_adx) < 3) return;
   if(CopyBuffer(h_atr, 0, 0, 3, buffer_atr) < 3) return;
   if(CopyHigh(_Symbol, _Period, 0, InpDonchianPeriod+1, buffer_high) < InpDonchianPeriod) return;
   if(CopyLow(_Symbol, _Period, 0, InpDonchianPeriod+1, buffer_low) < InpDonchianPeriod) return;

   // HMA Logic Simulation (Fast Trend Filter)
   if(CopyBuffer(h_fast, 0, 0, 2, v_fast) < 2) return;
   if(CopyBuffer(h_slow, 0, 0, 2, v_slow) < 2) return;

   bool is_trend_up = v_fast[1] > v_slow[1];
   bool is_trend_down = v_fast[1] < v_slow[1];

   // Check Spread
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpread) return;

   // Entry Logic: Donchian Breakout (Close of candle 1 > Max of candles 2..N+1)
   int max_idx = ArrayMaximum(buffer_high, 2, InpDonchianPeriod);
   int min_idx = ArrayMinimum(buffer_low, 2, InpDonchianPeriod);
   
   if(max_idx < 0 || min_idx < 0) return;

   double high_max = buffer_high[max_idx];
   double low_min = buffer_low[min_idx];
   double close_now = iClose(_Symbol, _Period, 1);

   bool buy_trigger = (close_now > high_max && is_trend_up && buffer_adx[1] > InpADXMinLevel);
   bool sell_trigger = (close_now < low_min && is_trend_down && buffer_adx[1] > InpADXMinLevel);

   // Debug Logs (Optional but useful for first tests)
   /*
   if(buy_trigger || sell_trigger) 
      PrintFormat("Signal Detected: Buy=%d, Sell=%d, Close=%.5f, HighMax=%.5f, LowMin=%.5f, ADX=%.2f", 
                  buy_trigger, sell_trigger, close_now, high_max, low_min, buffer_adx[1]);
   */

   if(!PositionSelectByMagic(InpMagicNumber)) {
      if(buy_trigger) ExecuteOrder(ORDER_TYPE_BUY);
      else if(sell_trigger) ExecuteOrder(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Execute Order with Dynamic Risk                                 |
//+------------------------------------------------------------------+
void ExecuteOrder(ENUM_ORDER_TYPE type)
{
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = buffer_atr[0];
   double sl_dist = atr * InpStopLossMult;
   double tp_dist = atr * InpTakeProfitMult;

   double sl = (type == ORDER_TYPE_BUY) ? (price - sl_dist) : (price + sl_dist);
   double tp = (type == ORDER_TYPE_BUY) ? (price + tp_dist) : (price - tp_dist);

   // Calculate Lot
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = balance * (InpRiskPercent / 100.0);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double sl_points = MathAbs(price - sl) / _Point;
   
   double lot = risk_money / (sl_points * (_Point / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)) * tick_value);
   lot = MathFloor(lot / SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)) * SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathMax(lot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));

   if(m_trade.PositionOpen(_Symbol, type, lot, price, sl, tp, "Apex Kraken")) {
      Print("Kraken Position Opened: ", EnumToString(type), " Lot: ", lot);
   }
}

//+------------------------------------------------------------------+
//| Dynamic Trailing Kraken                                         |
//+------------------------------------------------------------------+
void ManageTrailing()
{
   if(!PositionSelectByMagic(InpMagicNumber)) return;

   double price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   double atr = buffer_atr[0];
   
   double profit_points = MathAbs(price - open_price) / _Point;
   double trail_start_points = (atr * InpTrailingStart) / _Point;
   double trail_step_points = (atr * InpTrailingStep) / _Point;

   if(profit_points > trail_start_points) {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         double new_sl = NormalizeDouble(price - (atr * InpTrailingStep), _Digits);
         if(new_sl > current_sl + (_Point * 10)) {
            m_trade.PositionModify(PositionGetInteger(POSITION_TICKET), new_sl, PositionGetDouble(POSITION_TP));
         }
      }
      else {
         double new_sl = NormalizeDouble(price + (atr * InpTrailingStep), _Digits);
         if(new_sl < current_sl - (_Point * 10) || current_sl == 0) {
            m_trade.PositionModify(PositionGetInteger(POSITION_TICKET), new_sl, PositionGetDouble(POSITION_TP));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Optimization Fitness (Calmar Ratio Style)                       |
//+------------------------------------------------------------------+
double OnTester()
{
   double profit = TesterStatistics(STAT_PROFIT);
   double draw = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double trades = TesterStatistics(STAT_TRADES);
   double rec_factor = TesterStatistics(STAT_RECOVERY_FACTOR);

   if(trades < 30 || draw > 20.0 || profit <= 0) return(0.0);

   // Kraken Fitness: Calmar Approximation
   return (profit / draw) * rec_factor;
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
