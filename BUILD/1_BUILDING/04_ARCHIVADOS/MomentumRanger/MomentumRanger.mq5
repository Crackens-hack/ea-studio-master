#property copyright "MomentumRanger EA"
#property version   "1.00"
#property description "EA de rupturas de rangos con confirmación de momentum"

#include <Trade/Trade.mqh>
CTrade trade;

//--- Parámetros de entrada
input group "=== Configuración Principal ==="
input double RiskPercent    = 1.0;    // % de riesgo por operación
input int    MagicNumber    = 202403; // Número mágico

input group "=== Parámetros Bollinger Bands ==="
input int    BB_Period      = 20;     // Periodo Bollinger Bands
input double BB_Deviation   = 2.0;    // Desviación estándar

input group "=== Parámetros RSI ==="
input int    RSI_Period     = 14;     // Periodo RSI
input int    RSI_Upper      = 65;     // Nivel superior RSI
input int    RSI_Lower      = 35;     // Nivel inferior RSI

input group "=== Parámetros ATR ==="
input int    ATR_Period     = 14;     // Periodo ATR
input double ATR_MinLevel   = 0.00001; // Nivel mínimo ATR para ruptura

input group "=== Gestión de Riesgo ==="
input double TP_Multiplier  = 3.0;    // Multiplicador TP (x ATR)
input int    MaxSpread      = 30;     // Spread máximo permitido (puntos)

input group "=== Filtros Adicionales ==="
input bool   UseTimeFilter  = true;   // Usar filtro horario
input int    StartHour      = 2;      // Hora inicio operaciones
input int    EndHour        = 22;     // Hora fin operaciones

//--- Variables globales
int bb_handle, rsi_handle, atr_handle;
double bb_upper[], bb_lower[], rsi_buffer[], atr_buffer[];
MqlTick current_tick;
datetime last_candle_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Crear handles de indicadores
   bb_handle = iBands(_Symbol, _Period, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   atr_handle = iATR(_Symbol, _Period, ATR_Period);
   
   if(bb_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE)
   {
      Print("Error creando handles de indicadores");
      return INIT_FAILED;
   }
   
   //--- Configurar trade
   trade.SetExpertMagicNumber(MagicNumber);
   
   Print("MomentumRanger EA iniciado correctamente");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Liberar handles
   IndicatorRelease(bb_handle);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(atr_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Verificar si es nueva vela
   datetime current_time = iTime(_Symbol, _Period, 0);
   if(current_time == last_candle_time) 
   {
      ManagePosition();
      return;
   }
   last_candle_time = current_time;
   
   //--- Verificar spread
   if(!CheckSpread()) return;
   
   //--- Verificar filtro horario
   if(UseTimeFilter && !CheckTradingTime()) return;
   
   //--- Obtener datos actuales
   if(!GetIndicatorData()) return;
   
   //--- Verificar si hay posición abierta de ESTE EA
   if(!PositionSelectByMagic(MagicNumber))
   {
      //--- Buscar señales de entrada
      CheckForEntry();
   }
   else
   {
      //--- Gestionar posición abierta
      ManagePosition();
   }
}

//+------------------------------------------------------------------+
//| Verificar spread actual                                          |
//+------------------------------------------------------------------+
bool CheckSpread()
{
   SymbolInfoTick(_Symbol, current_tick);
   int spread = (int)((current_tick.ask - current_tick.bid) / _Point);
   return (spread <= MaxSpread);
}

//+------------------------------------------------------------------+
//| Verificar horario de operación                                   |
//+------------------------------------------------------------------+
bool CheckTradingTime()
{
   MqlDateTime time_now;
   TimeCurrent(time_now);
   
   int current_hour = time_now.hour;
   return (current_hour >= StartHour && current_hour <= EndHour);
}

//+------------------------------------------------------------------+
//| Obtener datos de indicadores                                     |
//+------------------------------------------------------------------+
bool GetIndicatorData()
{
   //--- Copiar datos Bollinger Bands
   if(CopyBuffer(bb_handle, 1, 0, 3, bb_upper) < 3) return false;
   if(CopyBuffer(bb_handle, 2, 0, 3, bb_lower) < 3) return false;
   
   //--- Copiar datos RSI
   if(CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer) < 3) return false;
   
   //--- Copiar datos ATR
   if(CopyBuffer(atr_handle, 0, 0, 3, atr_buffer) < 3) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Buscar señales de entrada                                        |
//+------------------------------------------------------------------+
void CheckForEntry()
{
   double atr_current = atr_buffer[0];
   
   //--- Verificar si ATR supera mínimo requerido
   if(atr_current < ATR_MinLevel) return;
   
   //--- Obtener datos históricos de precio para consistencia
   double close_prev = iClose(_Symbol, _Period, 1);  // Cierre del periodo anterior
   
   //--- Debug: Mostrar valores actuales para diagnóstico
   Print("DEBUG: Close=", close_prev, " BB_Upper=", bb_upper[1], " BB_Lower=", bb_lower[1], " RSI=", rsi_buffer[1], " ATR=", atr_current);
   
   //--- Señal de COMPRA: Precio CIERRA arriba de banda superior + RSI > nivel
   if(close_prev > bb_upper[1] && rsi_buffer[1] > RSI_Upper)
   {
      Print("SEÑAL COMPRA detectada: Close=", close_prev, " > BB_Upper=", bb_upper[1], " RSI=", rsi_buffer[1]);
      OpenPosition(ORDER_TYPE_BUY, atr_current);
      return;
   }
   
   //--- Señal de VENTA: Precio CIERRA abajo de banda inferior + RSI < nivel
   if(close_prev < bb_lower[1] && rsi_buffer[1] < RSI_Lower)
   {
      Print("SEÑAL VENTA detectada: Close=", close_prev, " < BB_Lower=", bb_lower[1], " RSI=", rsi_buffer[1]);
      OpenPosition(ORDER_TYPE_SELL, atr_current);
      return;
   }
}

//+------------------------------------------------------------------+
//| Abrir posición                                                   |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE type, double atr_value)
{
   double volume = CalculateVolume();
   if(volume == 0) return;
   
   double sl = CalculateSL(type, atr_value);
   double tp = CalculateTP(type, atr_value);
   
   if(type == ORDER_TYPE_BUY)
   {
      if(trade.Buy(volume, _Symbol, 0, sl, tp, "MomentumRanger BUY"))
         Print("Posición COMPRA abierta. SL: ", sl, " TP: ", tp);
   }
   else
   {
      if(trade.Sell(volume, _Symbol, 0, sl, tp, "MomentumRanger SELL"))
         Print("Posición VENTA abierta. SL: ", sl, " TP: ", tp);
   }
}

//+------------------------------------------------------------------+
//| Calcular volumen de operación                                    |
//+------------------------------------------------------------------+
double CalculateVolume()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * RiskPercent / 100.0;  // $10 con RiskPercent=1.0
   
   SymbolInfoTick(_Symbol, current_tick);
   
   //--- Calcular distancia SL basada en ATR
   double atr_value = atr_buffer[0];
   double sl_distance_pips = atr_value * 10000;  // Convertir a pips (aproximado)
   
   if(sl_distance_pips == 0) return 0;
   
   //--- Volumen simplificado: $10 de riesgo / (distancia_SL * valor_por_pip)
   // Para EURUSD, 1 pip ≈ $10 por lote
   double volume = risk_amount / (sl_distance_pips * 10);  // 10 = valor aproximado por pip
   
   //--- Normalizar volumen
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   volume = MathFloor(volume / volume_step) * volume_step;
   
   //--- Verificar límites y asegurar volumen razonable
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume = 0.1;  // Máximo 0.1 lote para cuenta pequeña
   
   volume = MathMax(volume, min_volume);
   volume = MathMin(volume, max_volume);
   
   Print("Volumen: ", volume, " lotes | Riesgo: $", risk_amount, " | ATR: ", atr_value, " | SL_pips: ", sl_distance_pips);
   
   return volume;
}

//+------------------------------------------------------------------+
//| Calcular Stop Loss                                               |
//+------------------------------------------------------------------+
double CalculateSL(ENUM_ORDER_TYPE type, double atr_value)
{
   SymbolInfoTick(_Symbol, current_tick);
   
   if(type == ORDER_TYPE_BUY)
      return NormalizeDouble(current_tick.bid - atr_value, _Digits);
   else
      return NormalizeDouble(current_tick.ask + atr_value, _Digits);
}

//+------------------------------------------------------------------+
//| Calcular Take Profit                                             |
//+------------------------------------------------------------------+
double CalculateTP(ENUM_ORDER_TYPE type, double atr_value)
{
   SymbolInfoTick(_Symbol, current_tick);
   double tp_distance = atr_value * TP_Multiplier;
   
   if(type == ORDER_TYPE_BUY)
      return NormalizeDouble(current_tick.ask + tp_distance, _Digits);
   else
      return NormalizeDouble(current_tick.bid - tp_distance, _Digits);
}

//+------------------------------------------------------------------+
//| Gestionar posición abierta                                       |
//+------------------------------------------------------------------+
void ManagePosition()
{
   //--- Verificar si realmente hay posición abierta de este EA
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            has_position = true;
            break;
         }
      }
   }
   
   if(!has_position)
   {
      // No hay posición abierta de este EA
      return;
   }
   
   //--- Aquí irá la lógica de trailing stop más adelante
   // Por ahora, simplemente monitorear
   Print("Posición activa siendo monitoreada");
}

//+------------------------------------------------------------------+
//| Función OnTester para métricas                                  |
//+------------------------------------------------------------------+
double OnTester()
{
   //--- Métricas clave para optimización
   double profit_factor = TesterStatistics(STAT_PROFIT_FACTOR);
   double recovery_factor = TesterStatistics(STAT_RECOVERY_FACTOR);
   double sharpe_ratio = TesterStatistics(STAT_SHARPE_RATIO);
   
   Comment("MomentumRanger - PF: ", profit_factor, " | RF: ", recovery_factor, " | Sharpe: ", sharpe_ratio);
   
   //--- Función fitness para optimización
   return profit_factor * recovery_factor * (sharpe_ratio > 0 ? sharpe_ratio : 0.1);
}

//+------------------------------------------------------------------+
//| Helper para verificar posición por Magic Number                |
//+------------------------------------------------------------------+
bool PositionSelectByMagic(long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            return true;
         }
      }
   }
   return false;
}