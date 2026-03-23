//+------------------------------------------------------------------+
//|                        APEX S-CYCLES V1                          |
//|                    "The Symmetry Protocol"                       |
//|           Diseñado para Escalabilidad 5000 -> 100,000            |
//+------------------------------------------------------------------+
#property strict
#property copyright "Ezequiel - Antigravity"
#property version   "1.00"

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

input group "=== Fase 1: Sniper (Supervivencia) ==="
input double InpRiskSniper       = 1.8;   // % de riesgo Phoenix (Agresivo)
input int    InpSL_Pips          = 42;    // SL inicial robusto
input int    InpImaginaryTP      = 86;    // TP de referencia interna
input double InpTrailingTrigger  = 0.40;  // Nivel de BE optimizado

input group "=== Fase 2: Maximizer (Explosión) ==="
input double InpRiskMaximizer    = 0.5;   // % de riesgo Maximizer (Explosivo)
input int    InpTrailingStep     = 34;    // Trailing step (Aumentado para dejar respirar)

input group "=== Sistema ==="
input int    InpMagic            = 2026312;
input bool   InpDebug            = true;

input group "=== Filtros Técnicos (Edge) ==="
input int    InpEMAPeriod        = 140;   // Tendencia definida por clúster
input int    InpFractalBars      = 85;    // Rango de ruptura robusto
input int    InpATRPeriod        = 14;    
input double InpATRMultiplier    = 0.4;   // Umbral de volatilidad maestro

//================ GLOBALS =================//

ENUM_CYCLE_STATE cycle_state = STATE_IDLE;
int    active_dir = 0; // 1=Buy, -1=Sell
double last_profit = 0;
ulong  active_ticket = 0;

int    emaHandle;
int    atrHandle;
double ema_bus[];
double atr_bus[];

void Log(string msg) { if(InpDebug) Print("[S-CYCLES-V1] ", msg); }

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

double CalcLot(double risk_percent, int sl_pips) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_usd = balance * (risk_percent / 100.0);
   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_val <= 0) tick_val = 1.0; 
   
   double lot = risk_usd / (sl_pips * 10 * tick_val);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   return NormalizeDouble(MathMin(MathMax(lot, min_lot), max_lot), 2);
}

//================ SIGNAL (PLACEHOLDER) =================//

int GetSignal() {
   if(CopyBuffer(emaHandle, 0, 0, 2, ema_bus) < 2) return 0;
   if(CopyBuffer(atrHandle, 0, 0, 2, atr_bus) < 2) return 0;
   
   int high_idx = iHighest(_Symbol, _Period, MODE_HIGH, InpFractalBars, 2);
   int low_idx  = iLowest(_Symbol, _Period, MODE_LOW, InpFractalBars, 2);
   
   double local_high = iHigh(_Symbol, _Period, high_idx);
   double local_low  = iLow(_Symbol, _Period, low_idx);
   double close_1    = iClose(_Symbol, _Period, 1);
   double ema        = ema_bus[1]; // Valor al cierre de la vela 1
   double atr        = atr_bus[1]; // Valor al cierre de la vela 1
   
   // Compra: Cierre de vela 1 rompe Fractal (2 a 46) + Filtro ATR
   if(close_1 > (local_high + (atr * InpATRMultiplier)) && close_1 > ema) {
      return 1;
   }
   
   // Venta: Cierre de vela 1 rompe Fractal (2 a 46) - Filtro ATR
   if(close_1 < (local_low - (atr * InpATRMultiplier)) && close_1 < ema) {
      return -1;
   }
   
   return 0;
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

   // 2. Gestión segun estado
   switch(cycle_state) {
      
      case STATE_IDLE:
      {
         int sig = GetSignal();
         if(sig != 0) {
            double lot = CalcLot(InpRiskSniper, InpSL_Pips);
            active_dir = sig;
            if(sig == 1) {
               if(trade.Buy(lot, _Symbol, 0, 0, 0, "SNIPER")) {
                  active_ticket = trade.ResultOrder();
                  cycle_state = STATE_SNIPER;
                  Log("SNIPER Entry. Lot: " + DoubleToString(lot, 2));
               }
            } else {
               if(trade.Sell(lot, _Symbol, 0, 0, 0, "SNIPER")) {
                  active_ticket = trade.ResultOrder();
                  cycle_state = STATE_SNIPER;
                  Log("SNIPER Entry. Lot: " + DoubleToString(lot, 2));
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
         // En este estado, la primera ya cerró en profit.
         // Podríamos esperar una nueva señal o entrar directo. 
         // Según el documento de Ezequiel: "La segunda orden abre DESPUÉS que la primera cierra en ganancia".
         // Vamos a entrar directo a favor del momentum inicial.
         double lot_max = CalcLot(InpRiskMaximizer, InpSL_Pips);
         if(active_dir == 1) {
            if(trade.Buy(lot_max, _Symbol, 0, 0, 0, "MAXIMIZER")) {
               active_ticket = trade.ResultOrder();
               cycle_state = STATE_MAXIMIZER;
               Log("MAXIMIZER Entry. Lot: " + DoubleToString(lot_max, 2));
            }
         } else {
            if(trade.Sell(lot_max, _Symbol, 0, 0, 0, "MAXIMIZER")) {
               active_ticket = trade.ResultOrder();
               cycle_state = STATE_MAXIMIZER;
               Log("MAXIMIZER Entry. Lot: " + DoubleToString(lot_max, 2));
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
   
   // Inicializar SL si no tiene
   if(sl == 0) {
      double initial_sl = (active_dir == 1) ? entry - (InpSL_Pips * _Point * 10) : entry + (InpSL_Pips * _Point * 10);
      trade.PositionModify(active_ticket, NormalizeDouble(initial_sl, _Digits), 0);
      return;
   }

   // Mover a Break Even
   if(current_pips >= (InpImaginaryTP * InpTrailingTrigger)) {
      if((active_dir == 1 && sl < entry) || (active_dir == -1 && sl > entry)) {
         trade.PositionModify(active_ticket, NormalizeDouble(entry, _Digits), 0);
         Log("SNIPER: Moved to BE.");
      }
   }
   
   // Cierre por TP Imaginario
   if(current_pips >= InpImaginaryTP) {
      trade.PositionClose(active_ticket);
      Log("SNIPER: Closed by Imaginary TP.");
   }
}

//================ GESTIÓN FASE 2 =================//

void ManageMaximizer() {
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double price = (active_dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Trailing Stop agresivo
   double new_sl;
   if(active_dir == 1) {
      new_sl = price - (InpTrailingStep * _Point * 10);
      if(sl == 0 || new_sl > sl + (_Point * 10)) {
         trade.PositionModify(active_ticket, NormalizeDouble(new_sl, _Digits), 0);
      }
   } else {
      new_sl = price + (InpTrailingStep * _Point * 10);
      if(sl == 0 || new_sl < sl - (_Point * 10)) {
         trade.PositionModify(active_ticket, NormalizeDouble(new_sl, _Digits), 0);
      }
   }
}

//================ CIERRE =================//

void CheckClosedPosition() {
   if(HistorySelect(TimeCurrent() - 60, TimeCurrent())) {
      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--) {
         ulong deal = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(deal, DEAL_MAGIC) == InpMagic) {
            double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
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
   const double pf        = MathMax(0.5, TesterStatistics(STAT_PROFIT_FACTOR));
   const double rf        = MathMax(0.01, TesterStatistics(STAT_RECOVERY_FACTOR));
   const double dd_rel    = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT) / 100.0);
   const double g_loss    = MathAbs(TesterStatistics(STAT_GROSS_LOSS));
   const double g_profit  = TesterStatistics(STAT_GROSS_PROFIT);
   const double payoff    = g_loss < 0.0001 ? g_profit : g_profit / g_loss;
   const double winrate   = 100.0 * (double)TesterStatistics(STAT_PROFIT_TRADES) / MathMax(1.0, (double)trades);

   // --- 2. Filtro de Seguridad Mínimo ---
   // Si no hay trades, no hay nada que evaluar.
   if(trades < 10) return 0.0;

   // --- 3. Cálculo de Fitness Progresivo ---
   // Rampa de trades: mas suave para que el GA tenga "hambre" de mas trades
   double rampa = MathMin(1.0, (double)trades / 150.0);
   
   // Multiplicador de profit: si es perdedor, penaliza pero deja ver el gradiente
   double p_mult = (profit > 0) ? 1.0 : 0.5; 
   
   // Fitness: (Payoff * RF * Rampa) / (1 + Drawdown)
   // Agregamos un pequeño valor base basado en trades para que el GA se mueva
   double fitness = (payoff * rf * rampa * p_mult) / (1.0 + dd_rel);

   // --- 4. Log de Optimización ---
   if(InpDebug) {
      PrintFormat("CAZADOR-OPT: Fit=%.4f | PF=%.2f RF=%.2f Trades=%d DD=%.2f%%",
                  fitness, pf, rf, trades, dd_rel * 100.0);
   }

   return fitness;
}
