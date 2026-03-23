//+------------------------------------------------------------------+
//|                      APEX GRAVITY V1                             |
//|               "The Account Compounding Engine"                   |
//|          Diseñado para High-Frequency Mean Reversion             |
//+------------------------------------------------------------------+
#property strict
#property copyright "Ezequiel - Antigravity AI"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade trade;

//================ INPUTS =================//

input group "=== Motor Gravity (Riesgo y Capital) ==="
input double InpRiskPercent      = 5.0;    // % de riesgo muy agresivo por trade
input double InpSL_ATR_Mult      = 3.0;    // Limitador de perdidas agudo
input double InpTP_ATR_Mult      = 1.5;    // Extracción de ganancia ultra rapida (Mean Revert)

input group "=== Sensores de Anomalias ==="
input int    InpBandsPeriod      = 20;     // Periodo Bandas de Bollinger
input double InpBandsDev         = 2.5;    // Desviaciones estandar (Elasticidad)
input int    InpRsiPeriod        = 14;     // Periodo RSI (Exhaustion)
input int    InpRsiOverbought    = 85;     // Nivel extremo de sobrecompra (Rechazo inminente)
input int    InpRsiOversold      = 15;     // Nivel extremo de sobreventa (Rebote inminente)

input group "=== Sistema ==="
input int    InpMagic            = 8888;
input bool   InpDebug            = true;
input int    InpATRPeriod        = 14; 

input group "=== Filtros de Seguridad (Institucional) ==="
input int    InpTrendEMA         = 200;    // EMA de tendencia (0=Off) - Filtra contra-tendencia
input double InpMaxAtrSpike      = 2.5;    // Filtro de noticias (Max dif vs ATR promedio)
input int    InpMaxSpread        = 30;     // Spread máximo permitido (puntos)

//================ GLOBALS =================//

int    bbHandle;
int    rsiHandle;
int    atrHandle;
int    emaHandle;
double bb_upper[], bb_lower[], bb_middle[];
double rsi_bus[];
double atr_bus[];
double ema_bus[];

void Log(string msg) { if(InpDebug) Print("[GRAVITY-V1] ", msg); }

//================ INIT =================//

int OnInit() {
   trade.SetExpertMagicNumber(InpMagic);
   
   bbHandle = iBands(_Symbol, _Period, InpBandsPeriod, 0, InpBandsDev, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, _Period, InpRsiPeriod, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   
   if(bbHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE) {
      Log("Error crítico: Fallo de sensores.");
      return(INIT_FAILED);
   }
   
   if(InpTrendEMA > 0) {
      emaHandle = iMA(_Symbol, _Period, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle == INVALID_HANDLE) return(INIT_FAILED);
      ArraySetAsSeries(ema_bus, true);
   }
   
   ArraySetAsSeries(bb_upper, true); ArraySetAsSeries(bb_lower, true); ArraySetAsSeries(bb_middle, true);
   ArraySetAsSeries(rsi_bus, true);
   ArraySetAsSeries(atr_bus, true);
   
   Log("Gravedad Artificial activada. Filtro Institucional ON.");
   return(INIT_SUCCEEDED);
}

//================ HELPERS =================//

double CalcLot(double risk_percent, double sl_distance) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_usd = balance * (risk_percent / 100.0);
   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_val <= 0) tick_val = 1.0; 
   
   double sl_points = sl_distance / _Point;
   if(sl_points <= 0) return 0.01;

   double lot = risk_usd / (sl_points * tick_val);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   return NormalizeDouble(MathMin(MathMax(lot, min_lot), max_lot), 2);
}

//================ SIGNAL =================//

int GetSignal() {
   if(CopyBuffer(atrHandle, 0, 0, 20, atr_bus) < 20) return 0;
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsi_bus) < 2) return 0;
   if(CopyBuffer(bbHandle, UPPER_BAND, 0, 2, bb_upper) < 2) return 0;
   if(CopyBuffer(bbHandle, LOWER_BAND, 0, 2, bb_lower) < 2) return 0;
   if(CopyBuffer(bbHandle, BASE_LINE, 0, 2, bb_middle) < 2) return 0;

   // 1. Filtro de Spread Institucional
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (ask - bid) / _Point;
   if(spread > InpMaxSpread) return 0;

   // 2. Filtro de Spike / Noticias (Asimetría de Volatilidad)
   double current_atr = atr_bus[0];
   double sum_atr = 0;
   for(int i=1; i<20; i++) sum_atr += atr_bus[i];
   double avg_atr = sum_atr / 19.0;
   if(current_atr > avg_atr * InpMaxAtrSpike) return 0;

   // 3. Filtro Macro-Tendencial (No jugar a los rebotes contra un Tsunami)
   double ema = 0;
   if(InpTrendEMA > 0 && CopyBuffer(emaHandle, 0, 0, 1, ema_bus) > 0) ema = ema_bus[0];

   double close_1 = iClose(_Symbol, _Period, 1);
   double close_0 = iClose(_Symbol, _Period, 0);
   double open_1  = iOpen(_Symbol, _Period, 1);
   double rsi_1   = rsi_bus[1];
   
   // 4. Filtro de "Micro Edge" (Eliminar velitas doji sin intención de reversión real)
   double body = MathAbs(close_1 - open_1);
   if(body < current_atr * 0.2) return 0;
   
   // --- Gatillo Corto (SELL) -> Sube estúpidamente rápido y se agota
   // Precio rompe banda superior y el RSI esta en sobrecompra extrema
   if(close_1 >= bb_upper[1] && rsi_1 > InpRsiOverbought) {
      // Confirmación: Empieza a caer hacia adentro de la banda (Mean Reversion)
      if(close_0 < close_1) {
         if(InpTrendEMA > 0) {
            double dist = MathAbs(close_1 - ema) / current_atr;
            if(close_1 > ema && dist > 1.2) return 0; // Tsunami Alcista muy amplio: Ignorar
         }
         return -1;
      }
   }
   
   // --- Gatillo Largo (BUY) -> Cae estúpidamente rápido y se agota
   // Precio rompe banda inferior y el RSI esta en sobreventa extrema
   if(close_1 <= bb_lower[1] && rsi_1 < InpRsiOversold) {
      // Confirmación: Empieza a subir hacia adentro de la banda (Mean Reversion)
      if(close_0 > close_1) {
         if(InpTrendEMA > 0) {
            double dist = MathAbs(close_1 - ema) / current_atr;
            if(close_1 < ema && dist > 1.2) return 0; // Tsunami Bajista muy amplio: Ignorar
         }
         return 1;
      }
   }
   
   return 0;
}

//================ TICK =================//

void OnTick() {
   // La Alta Frecuencia/Reversión no sobreopera. 1 Posición a la vez.
   if(PositionsTotal() > 0) return; 
   
   int sig = GetSignal();
   if(sig != 0) {
      // Asegurar lecturas frescas
      if(CopyBuffer(atrHandle, 0, 0, 1, atr_bus) <= 0) return;
      double atr = atr_bus[0];
      if(atr <= 0) return;
      
      double sl_dist = atr * InpSL_ATR_Mult;
      double tp_dist = atr * InpTP_ATR_Mult;
      double lot = CalcLot(InpRiskPercent, sl_dist);
      
      if(sig == 1) { // BUY Reversion
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = NormalizeDouble(ask - sl_dist, _Digits);
         double tp = NormalizeDouble(ask + tp_dist, _Digits);
         if(trade.Buy(lot, _Symbol, ask, sl, tp, "GRAVITY REVERT BUY")) {
            Log("Anomalía detectada. BUY " + DoubleToString(lot, 2) + " Lotes.");
         }
      } else if (sig == -1) { // SELL Reversion
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = NormalizeDouble(bid + sl_dist, _Digits);
         double tp = NormalizeDouble(bid - tp_dist, _Digits);
         if(trade.Sell(lot, _Symbol, bid, sl, tp, "GRAVITY REVERT SELL")) {
            Log("Anomalía detectada. SELL " + DoubleToString(lot, 2) + " Lotes.");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Custom Fitness - Depredador Institucional V3 (Puro y duro)       |
//+------------------------------------------------------------------+
double OnTester()
{
   const int    trades    = (int)TesterStatistics(STAT_TRADES);
   const double profit    = TesterStatistics(STAT_PROFIT);
   const double pf        = MathMax(0.1, TesterStatistics(STAT_PROFIT_FACTOR));
   const double rf        = MathMax(0.01, TesterStatistics(STAT_RECOVERY_FACTOR));
   const double dd_rel    = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT) / 100.0);
   const double winrate   = 100.0 * (double)TesterStatistics(STAT_PROFIT_TRADES) / MathMax(1.0, (double)trades);

   // A. Guillotina de Muestra Crítica
   if(trades < 40) return 0.0;
   
   // B. Suavizado de Profit logaritmico (Antifragil)
   double profit_smooth = MathLog(1.0 + MathMax(0.0, profit));
   double risk_efficiency = profit_smooth / (1.0 + dd_rel * 120.0);
   if(profit <= 0) risk_efficiency = 0.01;

   // C. Factor PF Pesado por Muestra
   double pf_weight = MathMin(1.0, (double)trades / 100.0);
   double pf_factor = 1.0 + (MathMin(2.0, pf) - 1.0) * pf_weight;

   // D. Estabilidad Agresiva (Acá se mueren los apostadores)
   double stability = MathPow(winrate / 100.0, 1.5);
   if(winrate < 35.0) stability *= 0.5;

   // E. Factor de Actividad Temporal
   double activity = MathMin(1.0, (double)trades / 120.0);

   // Cálculo de Fitness (El Depredador V3)
   double fitness = (rf * activity * stability * risk_efficiency * pf_factor) / (1.0 + dd_rel);

   // F. Muros de Drawdown (0 piedad ante la varianza)
   if(dd_rel > 0.25) fitness *= 0.3;     // -70% fitness
   if(dd_rel > 0.35) fitness *= 0.1;     // -90% fitness
   if(dd_rel > 0.50) fitness = 0.0001;   // Muerte súbita

   PrintFormat("GRAVITY-ONTESTER: Fit=%.4f | Trades=%d | WR=%.1f%% | RF=%.2f | DD=%.2f%%",
               fitness, trades, winrate, rf, dd_rel * 100.0);

   return fitness;
}
