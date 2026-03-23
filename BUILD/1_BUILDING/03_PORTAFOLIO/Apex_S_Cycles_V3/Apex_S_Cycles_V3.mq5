//+------------------------------------------------------------------+
//|                        APEX S-CYCLES V2                          |
//|                    "The Audit & Debug Edition"                   |
//|           Diseñado para Escalabilidad 5000 -> 100,000            |
//+------------------------------------------------------------------+
#property strict
#property copyright "Ezequiel - Antigravity AI"
#property version   "2.00"

#include <Trade/Trade.mqh>
CTrade trade;

//================ ENUMS =================//
enum ENUM_CYCLE_STATE {
   STATE_IDLE,
   STATE_SNIPER,
   STATE_WAITING_MAXIMIZER,
   STATE_MAXIMIZER
};

//================ INPUTS =================//

input group "=== Fase 1: Sniper (ATR Based) ==="
input double InpRiskSniper       = 1.8;    // % de riesgo Phoenix
input double InpSL_Mult          = 2.8;    // Stop Loss (ATR Multiplier)
input double InpTP_Mult          = 5.4;    // Take Profit (ATR Multiplier)
input double InpBE_Trigger_Mult  = 2.1;    // Nivel Break Even (ATR Multiplier)

input group "=== Fase 2: Maximizer (Explosión) ==="
input double InpRiskMaximizer    = 0.5;    // % de riesgo Maximizer
input double InpTrailing_Mult    = 1.8;    // Trailing Step (ATR Multiplier)

input group "=== Salidas por Tiempo (Optimizable) ==="
input int    InpTimeOutSniper    = 24;     // Limite horas FASE 1 (0=Off)
input int    InpTimeOutMaximizer = 48;     // Limite horas FASE 2 (0=Off)

input group "=== Sistema ==="
input int    InpMagic            = 2026312;
input bool   InpDebug            = true;

input group "=== Filtros Técnicos (Edge) ==="
input int    InpEMAPeriod        = 140;   // Tendencia definida por clúster
input int    InpFractalBars      = 85;    // Rango de ruptura robusto
input int    InpATRPeriod        = 14;    
input double InpATRMultiplier    = 0.4;   // Umbral de volatilidad maestro
input int    InpSlopeLookback    = 10;    // Barras atras para medir pendiente EMA
input double InpSlopeMin         = 0.15;  // Pendiente minima (relativa al ATR)
input int    InpMaxSpread        = 20;    // Spread maximo permitido (puntos)
input double InpATRMin           = 0.0003; // ATR minimo para operar (mercado vivo)

input group "=== Auditoría e IA Debug ==="
input bool   InpWriteAudit       = false;   // Habilitar auditoria CSV
input int    InpHangingHours     = 24;      // Alerta de estancamiento (Horas)
input bool   InpVisualDebug      = false;   // Dibujar indicadores en el gráfico 

//================ GLOBALS =================//

ENUM_CYCLE_STATE cycle_state = STATE_IDLE;
int    active_dir = 0; // 1=Buy, -1=Sell
double last_profit = 0;
ulong  active_ticket = 0;

int    emaHandle;
int    atrHandle;
double ema_bus[];
double atr_bus[];

void Log(string msg) { if(InpDebug) Print("[S-CYCLES-V2] ", msg); }

//--- Variables de Auditoría y Gestión Dinámica
double trade_max_mfe = 0;
double trade_max_mae = 0;
datetime trade_start_time = 0;
double entry_ema = 0;
double entry_atr = 0;
double entry_f_high = 0;
double entry_f_low = 0;
double dynamic_sl_dist = 0; // Guardado en el momento de entrada
double dynamic_tp_price = 0; // Precio TP imaginario
bool   hanging_notified = false;

//--- Helper: Capturar Datos de Entrada
void CaptureEntryAudit() {
   trade_start_time = TimeCurrent();
   trade_max_mfe = 0; trade_max_mae = 0;
   hanging_notified = false;
   
   if(CopyBuffer(emaHandle, 0, 0, 1, ema_bus) > 0) entry_ema = ema_bus[0];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr_bus) > 0) entry_atr = atr_bus[0];
   
   // Si el ATR falla por alguna razón, usamos un fallback de 10 pips
   if(entry_atr <= 0) entry_atr = 10 * _Point * 10;

   int h_idx = iHighest(_Symbol, _Period, MODE_HIGH, InpFractalBars, 2);
   int l_idx = iLowest(_Symbol, _Period, MODE_LOW, InpFractalBars, 2);
   if(h_idx >= 0) entry_f_high = iHigh(_Symbol, _Period, h_idx);
   if(l_idx >= 0) entry_f_low = iLow(_Symbol, _Period, l_idx);
   
   // Calcular Niveles Dinámicos para esta fase
   dynamic_sl_dist = entry_atr * InpSL_Mult;
   double tp_dist = entry_atr * InpTP_Mult;
   
   double entry_price = (active_dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   dynamic_tp_price = (active_dir == 1) ? entry_price + tp_dist : entry_price - tp_dist;
}

//--- Helper: Reset Auditoría
void ResetAudit() {
   trade_start_time = 0;
   hanging_notified = false;
}

//================ INIT =================//

int OnInit() {
   trade.SetExpertMagicNumber(InpMagic);
   
   emaHandle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   
   if(emaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE) {
      Log("Error: Fallo al crear indicadores.");
      return(INIT_FAILED);
   }
   
   ArraySetAsSeries(ema_bus, true);
   ArraySetAsSeries(atr_bus, true);
   
   Log("S-Cycles Protocol Activated. Goal: 100,000.");
   return(INIT_SUCCEEDED);
}

//================ HELPERS =================//

double CalcLot(double risk_percent, double sl_distance) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_usd = balance * (risk_percent / 100.0);
   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_val <= 0) tick_val = 1.0; 
   
   // sl_distance viene en precio (ej 0.0020), convertimos a puntos para el cálculo MT5 estándar
   double sl_points = sl_distance / _Point;
   if(sl_points <= 0) return 0.01;

   double lot = risk_usd / (sl_points * tick_val);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   return NormalizeDouble(MathMin(MathMax(lot, min_lot), max_lot), 2);
}

//--- Helper: Obtener distancia mínima legal del broker
double GetMinStopDist() {
   double stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   return MathMax(stop_level, freeze_level) + (_Point * 10); // 10 puntos de margen extra
}

//================ SIGNAL (PLACEHOLDER) =================//

int GetSignal() {
   int bars_needed = MathMax(2, InpSlopeLookback + 2);
   if(CopyBuffer(emaHandle, 0, 0, bars_needed, ema_bus) < bars_needed) return 0;
   if(CopyBuffer(atrHandle, 0, 0, 2, atr_bus) < 2) return 0;

   double atr = atr_bus[1];
   if(atr <= 0) return 0; // FIX: Guard ATR - evita division por cero y datos corruptos

   // === FILTRO DE CALLE: Spread Universal y Mercado Vivo ===
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_spread = (ask - bid) / _Point; // FIX: Spread universal Ask-Bid
   if(current_spread > InpMaxSpread) return 0;
   if(atr < InpATRMin) return 0;

   int high_idx = iHighest(_Symbol, _Period, MODE_HIGH, InpFractalBars, 2);
   int low_idx  = iLowest(_Symbol, _Period, MODE_LOW, InpFractalBars, 2);
   if(high_idx < 0 || low_idx < 0) return 0;

   double local_high = iHigh(_Symbol, _Period, high_idx);
   double local_low  = iLow(_Symbol, _Period, low_idx);
   double close_1    = iClose(_Symbol, _Period, 1);
   double ema        = ema_bus[1];

   // === FILTRO DE INTENCIÓN: Pendiente EMA ===
   double slope = MathAbs((ema_bus[1] - ema_bus[InpSlopeLookback]) / atr);
   if(slope < InpSlopeMin) return 0;

   // === FILTRO DE VELA MUERTA ===
   // Evita micro-rupturas sin intención real (velas planas disfrazadas de breakout)
   double candle_range = MathAbs(iHigh(_Symbol, _Period, 1) - iLow(_Symbol, _Period, 1));
   if(candle_range < atr * 0.3) return 0;

   // Compra: Rompe Fractal + ATR + Tendencia alcista
   if(close_1 > (local_high + (atr * InpATRMultiplier)) && close_1 > ema) {
      return 1;
   }
   
   // Venta: Rompe Fractal - ATR + Tendencia bajista
   if(close_1 < (local_low - (atr * InpATRMultiplier)) && close_1 < ema) {
      return -1;
   }
   
   return 0;
}


//================ AUDITORÍA IA =================//

void AuditTrade(double profit) {
   if(!InpWriteAudit) return;
   
   string fileName = "Audit_Apex_V2_" + _Symbol + ".csv";
   int handle = FileOpen(fileName, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
   
   if(handle != INVALID_HANDLE) {
      if(FileSize(handle) == 0) {
         FileWrite(handle, "Ticket", "Dir", "Profit", "Duration_Sec", "Max_MFE_Pips", "Max_MAE_Pips", "EMA_Entry", "ATR_Entry", "Fractal_H", "Fractal_L", "Exit_State");
      }
      FileSeek(handle, 0, SEEK_END);
      
      long duration = TimeCurrent() - trade_start_time;
      string state_name = (cycle_state == STATE_SNIPER) ? "SNIPER" : "MAXIMIZER";
      
      FileWrite(handle, 
         active_ticket, 
         (active_dir == 1 ? "BUY" : "SELL"), 
         profit, 
         duration,
         NormalizeDouble(trade_max_mfe, 1),
         NormalizeDouble(trade_max_mae, 1),
         entry_ema,
         entry_atr,
         entry_f_high,
         entry_f_low,
         state_name
      );
      FileClose(handle);
   }
}

void VisualDebug() {
   if(!InpVisualDebug) return;
   
   if(CopyBuffer(emaHandle, 0, 0, 1, ema_bus) < 1) return;
   
   int high_idx = iHighest(_Symbol, _Period, MODE_HIGH, InpFractalBars, 2);
   int low_idx  = iLowest(_Symbol, _Period, MODE_LOW, InpFractalBars, 2);
   
   if(high_idx < 0 || low_idx < 0) return;

   double local_high = iHigh(_Symbol, _Period, high_idx);
   double local_low  = iLow(_Symbol, _Period, low_idx);

   ObjectCreate(0, "DB_EMA", OBJ_HLINE, 0, 0, ema_bus[0]);
   ObjectSetInteger(0, "DB_EMA", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "DB_EMA", OBJPROP_STYLE, STYLE_DOT);

   ObjectCreate(0, "DB_F_HIGH", OBJ_HLINE, 0, 0, local_high);
   ObjectSetInteger(0, "DB_F_HIGH", OBJPROP_COLOR, clrTomato);
   
   ObjectCreate(0, "DB_F_LOW", OBJ_HLINE, 0, 0, local_low);
   ObjectSetInteger(0, "DB_F_LOW", OBJPROP_COLOR, clrTomato);

   
   string msg = StringFormat("STATE: %s | T: %d s", EnumToString(cycle_state), (trade_start_time > 0 ? TimeCurrent()-trade_start_time : 0));
   ObjectCreate(0, "DB_INFO", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "DB_INFO", OBJPROP_TEXT, msg);
   ObjectSetInteger(0, "DB_INFO", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "DB_INFO", OBJPROP_YDISTANCE, 20);
}

//================ TICK =================//

void OnTick() {
   // 1. Verificar si la posición sigue activa
   bool is_pos_active = false;
   if(active_ticket > 0) {
      if(PositionSelectByTicket(active_ticket)) {
         is_pos_active = true;
      } else {
         // La posición se cerró
         CheckClosedPosition();
         active_ticket = 0;
         is_pos_active = false;
      }
   }

   // 2. Auditoría en tiempo real
   if(is_pos_active) {
      double price = (active_dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double pips = (active_dir == 1 ? (price - entry) : (entry - price)) / _Point / 10.0;
      
      if(pips > trade_max_mfe) trade_max_mfe = pips;
      if(pips < trade_max_mae) trade_max_mae = pips;
      
      // Monitor de Estancamiento y Cierre por Tiempo
      long active_sec = TimeCurrent() - trade_start_time;
      if(!hanging_notified && active_sec > (InpHangingHours * 3600)) {
         Log(StringFormat("!!! ALERTA DE ESTANCAMIENTO: Trade lleva %d horas. MFE: %.1f", InpHangingHours, trade_max_mfe));
         hanging_notified = true;
      }
      
      int current_tm_limit = (cycle_state == STATE_SNIPER) ? InpTimeOutSniper : InpTimeOutMaximizer;
      if(current_tm_limit > 0 && active_sec > (current_tm_limit * 3600)) {
         Log(StringFormat("Cerrando por TIEMPO (%s Limit reached)", (cycle_state == STATE_SNIPER ? "SNIPER" : "MAXIMIZER")));
         trade.PositionClose(active_ticket);
         return;
      }
   }

   // 3. Visual Debug
   VisualDebug();

   // 4. Gestión segun estado
   switch(cycle_state) {
      
      case STATE_IDLE:
      {
         int sig = GetSignal();
         if(sig != 0) {
            active_dir = sig;
            
            // Primero capturamos el ATR para calcular el lote dinámico
            if(CopyBuffer(atrHandle, 0, 0, 1, atr_bus) > 0) entry_atr = atr_bus[0];
            else entry_atr = 10 * _Point * 10;
            
            double lot = CalcLot(InpRiskSniper, entry_atr * InpSL_Mult);
            
            double min_dist = GetMinStopDist();
            double sl_dist = MathMax(entry_atr * InpSL_Mult, min_dist);

            if(sig == 1) {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double sl_price = NormalizeDouble(ask - sl_dist, _Digits);
               if(trade.Buy(lot, _Symbol, ask, sl_price, 0, "SNIPER")) {
                  active_ticket = trade.ResultOrder();
                  cycle_state = STATE_SNIPER;
                  CaptureEntryAudit();
                  Log("SNIPER Entry (Universal Mode). Lot: " + DoubleToString(lot, 2));
               }
            } else {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double sl_price = NormalizeDouble(bid + sl_dist, _Digits);
               if(trade.Sell(lot, _Symbol, bid, sl_price, 0, "SNIPER")) {
                  active_ticket = trade.ResultOrder();
                  cycle_state = STATE_SNIPER;
                  CaptureEntryAudit();
                  Log("SNIPER Entry (Universal Mode). Lot: " + DoubleToString(lot, 2));
               }
            }
         }
         break;
      }

      case STATE_SNIPER:
         if(is_pos_active) {
            ManageSniper();
         }
         break;

      case STATE_WAITING_MAXIMIZER:
      {
         // Guard: si ya hay una posición abierta (nuestra), no duplicar. Compatible con Hedge.
         if(PositionSelectByTicket(active_ticket)) { cycle_state = STATE_IDLE; break; }
         
         // Para la segunda fase necesitamos capturar el ATR actual
         if(CopyBuffer(atrHandle, 0, 0, 1, atr_bus) > 0) entry_atr = atr_bus[0];
         else entry_atr = 10 * _Point * 10;
         
         double lot_max = CalcLot(InpRiskMaximizer, entry_atr * InpSL_Mult);
         double min_dist = GetMinStopDist();
         double sl_dist_max = MathMax(entry_atr * InpSL_Mult, min_dist);
         
         if(active_dir == 1) {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double sl_p = NormalizeDouble(ask - sl_dist_max, _Digits);
            if(trade.Buy(lot_max, _Symbol, ask, sl_p, 0, "MAXIMIZER")) {
               active_ticket = trade.ResultOrder();
               cycle_state = STATE_MAXIMIZER;
               CaptureEntryAudit();
               Log("MAXIMIZER Entry (Universal Mode). Lot: " + DoubleToString(lot_max, 2));
            }
         } else {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double sl_p = NormalizeDouble(bid + sl_dist_max, _Digits);
            if(trade.Sell(lot_max, _Symbol, bid, sl_p, 0, "MAXIMIZER")) {
               active_ticket = trade.ResultOrder();
               cycle_state = STATE_MAXIMIZER;
               CaptureEntryAudit();
               Log("MAXIMIZER Entry (Universal Mode). Lot: " + DoubleToString(lot_max, 2));
            }
         }
         break;
      }

      case STATE_MAXIMIZER:
         if(is_pos_active) {
            ManageMaximizer();
         }
         break;
   }
}

//================ GESTIÓN FASE 1 =================//

void ManageSniper() {
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double price = (active_dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double current_pips = MathAbs(price - entry) / _Point / 10.0;
   
   // Inicializar SL Dinámico (si no tiene)
   if(sl == 0) {
      double min_d = GetMinStopDist();
      double dynamic_sl = MathMax(dynamic_sl_dist, min_d);
      double initial_sl = (active_dir == 1) ? entry - dynamic_sl : entry + dynamic_sl;
      trade.PositionModify(active_ticket, NormalizeDouble(initial_sl, _Digits), 0);
      return;
   }

   // Mover a Break Even Dinámico
   double be_trigger_pips = (entry_atr * InpBE_Trigger_Mult) / _Point / 10.0;
   if(current_pips >= be_trigger_pips) {
      double cur_dist = MathAbs(price - entry);
      if(cur_dist > GetMinStopDist()) { // Solo mueve a BE si estamos lejos del precio actual
         if((active_dir == 1 && sl < entry) || (active_dir == -1 && sl > entry)) {
            trade.PositionModify(active_ticket, NormalizeDouble(entry, _Digits), 0);
            Log("SNIPER (Dynamic): Moved to BE.");
         }
      }
   }
   
   // Cierre por TP Imaginario Dinámico
   if((active_dir == 1 && price >= dynamic_tp_price) || (active_dir == -1 && price <= dynamic_tp_price)) {
      trade.PositionClose(active_ticket);
      Log("SNIPER (Dynamic): Closed by ATR TP.");
   }
}

//================ GESTIÓN FASE 2 =================//

void ManageMaximizer() {
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double price = (active_dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Trailing Stop Dinámico por ATR
   double new_sl;
   double trail_dist = entry_atr * InpTrailing_Mult;
   double min_dist = GetMinStopDist();

   if(active_dir == 1) { // BUY
      new_sl = price - trail_dist;
      if(price - new_sl < min_dist) new_sl = price - min_dist;
      if(new_sl >= price) return; // Guard: SL no puede cruzar el precio
      
      if(sl == 0 || new_sl > sl + (_Point * 10)) {
         trade.PositionModify(active_ticket, NormalizeDouble(new_sl, _Digits), 0);
      }
   } else { // SELL
      new_sl = price + trail_dist;
      if(new_sl - price < min_dist) new_sl = price + min_dist;
      if(new_sl <= price) return; // Guard: SL no puede cruzar el precio

      if(sl == 0 || new_sl < sl - (_Point * 10)) {
         trade.PositionModify(active_ticket, NormalizeDouble(new_sl, _Digits), 0);
      }
   }
}

//================ CIERRE =================//

void CheckClosedPosition() {
   if(HistorySelect(0, TimeCurrent())) {
      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--) {
         ulong deal = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagic) {
            double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
            
            // Auditoría al cerrar
            AuditTrade(profit);
            ResetAudit();

            if(cycle_state == STATE_SNIPER) {
               if(profit > 0) {
                  cycle_state = STATE_WAITING_MAXIMIZER;
                  Log("Cycle State: SNIPER WON -> WAITING MAXIMIZER");
               } else {
                  cycle_state = STATE_IDLE;
                  Log("Cycle State: SNIPER LOST -> IDLE");
               }
            } else if(cycle_state == STATE_MAXIMIZER) {
               cycle_state = STATE_IDLE;
               Log("Cycle State: MAXIMIZER CLOSED -> IDLE. Profit: " + DoubleToString(profit, 2));
            }
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Custom Fitness - Modelo CAZADOR (Sequential Cycles)              |
//+------------------------------------------------------------------+
double OnTester()
{
   // --- 1. Captura de Datos ---
   const int    trades    = (int)TesterStatistics(STAT_TRADES);
   const double profit    = TesterStatistics(STAT_PROFIT);
   const double pf        = MathMax(0.1, TesterStatistics(STAT_PROFIT_FACTOR));
   const double rf        = MathMax(0.01, TesterStatistics(STAT_RECOVERY_FACTOR));
   const double dd_rel    = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT) / 100.0);
   const double winrate   = 100.0 * (double)TesterStatistics(STAT_PROFIT_TRADES) / MathMax(1.0, (double)trades);

   // --- 2. Filtros de Robustez "Depredador Institucional V3" ---
   
   // A. Guillotina de Muestra Crítica
   if(trades < 40) return 0.0;
   
   // B. Suavizado de Profit (Antifragilidad)
   // Usamos Logaritmo para que curvas explosivas no engañen al GA.
   double profit_smooth = MathLog(1.0 + MathMax(0.0, profit));
   double risk_efficiency = profit_smooth / (1.0 + dd_rel * 120.0);
   if(profit <= 0) risk_efficiency = 0.01;

   // C. Factor PF Pesado por Muestra
   // El PF solo "brilla" si hay suficientes trades para validarlo.
   double pf_weight = MathMin(1.0, (double)trades / 100.0);
   double pf_factor = 1.0 + (MathMin(2.0, pf) - 1.0) * pf_weight;

   // D. Estabilidad Agresiva (Winrate ^ 1.5)
   double stability = MathPow(winrate / 100.0, 1.5);
   if(winrate < 35.0) stability *= 0.5; // Penalización por WR "suicida"

   // E. Factor de Actividad Temporal
   double activity = MathMin(1.0, (double)trades / 120.0);

   // --- 3. Cálculo de Fitness Final (El Depredador) ---
   double fitness = (rf * activity * stability * risk_efficiency * pf_factor) / (1.0 + dd_rel);

   // F. Muros de Drawdown (Corte de Seguridad Institucional)
   if(dd_rel > 0.25) fitness *= 0.3;
   if(dd_rel > 0.35) fitness *= 0.1;
   if(dd_rel > 0.50) fitness = 0.0001; // Muerte súbita

   // --- 4. Log de Optimización ---
   if(InpDebug) {
      PrintFormat("DEPREDADOR-V3: Fit=%.4f | Trades=%d | WR=%.1f%% | RF=%.2f | PF=%.2f | DD=%.2f%%",
                  fitness, trades, winrate, rf, pf, dd_rel * 100.0);
   }

   return fitness;
}
