//+------------------------------------------------------------------+
//|                                            ApexTrendTracker.mq5  |
//|                                     Copyright 2026, EA Studio    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, EA Studio"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- Incluir clases estándar
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Parámetros de Entrada
input group "--- Configuración de Estrategia ---"
input int      InpADXPeriod      = 28;          // Periodo ADX
input int      InpADXMinLevel    = 25;          // Nivel mínimo ADX (fuerza tendencia)
input int      InpEMAFast        = 90;          // Periodo EMA Rápida
input int      InpEMASlow        = 250;         // Periodo EMA Lenta
input int      InpRSIPeriod      = 17;          // Periodo RSI
input int      InpRSILowLevel    = 30;          // Nivel RSI Sobreventa (Retroceso compra)
input int      InpRSILowLevel2   = 20;          // Nivel RSI Sobreventa extremo (OPCIONAL)
input int      InpRSIHighLevel   = 70;          // Nivel RSI Sobrecompra (Retroceso venta)

input group "--- Gestión de Riesgo ---"
input double   InpRiskPercent    = 1.0;         // % de Riesgo por Trade
input int      InpATRPeriod      = 19;          // Periodo ATR para Stop Loss
input double   InpATRMultiplier  = 1.5;         // Multiplicador ATR para Stop Loss
input double   InpTPMultiplier   = 6.0;         // Multiplicador del Riesgo para TP (Reward/Risk)

input group "--- Protecciones ---"
input bool     InpUseBreakeven   = true;        // Usar Breakeven
input double   InpBELevel        = 0.5;         // Ratio R/R para activar Breakeven
input bool     InpUseTrailing    = false;       // Usar Trailing Stop
input double   InpTrailingStep   = 0.3;         // Paso de Trailing (en unidades de ATR)

input group "--- Filtros Adicionales ---"
input int      InpMaxSpread      = 20;          // Spread máximo permitido (pips)
input int      InpMagicNumber    = 123456;      // Número Mágico

//--- Variables Globales
int      handleADX, handleEMAFast, handleEMASlow, handleRSI, handleATR;
CTrade   trade;
CSymbolInfo symInfo;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Inicializar SymbolInfo
   if(!symInfo.Name(_Symbol)) return(INIT_FAILED);
   symInfo.Refresh();

   //--- Inicializar Handlers de Indicadores
   handleADX      = iADX(_Symbol, _Period, InpADXPeriod);
   handleEMAFast  = iMA(_Symbol, _Period, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   handleEMASlow  = iMA(_Symbol, _Period, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleATR      = iATR(_Symbol, _Period, InpATRPeriod);

   if(handleADX == INVALID_HANDLE || handleEMAFast == INVALID_HANDLE || 
      handleEMASlow == INVALID_HANDLE || handleRSI == INVALID_HANDLE || 
      handleATR == INVALID_HANDLE)
   {
      Print("Error inicializando indicadores");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagicNumber);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleADX);
   IndicatorRelease(handleEMAFast);
   IndicatorRelease(handleEMASlow);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleATR);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Actualizar info del símbolo
   if(!symInfo.RefreshRates()) return;

   //--- Gestionar posiciones abiertas (Trailing / Breakeven)
   ManageOpenPositions();

   //--- Solo operar en apertura de barra para evitar ruido excesivo
   if(!IsNewBar()) return;

   //--- Verificar Spread
   if(symInfo.Spread() > InpMaxSpread * 10) return;

   //--- Verificar si ya hay una posición abierta con este Magic
   if(PositionSelectByMagic(InpMagicNumber)) return;

   //--- Obtener valores de indicadores
   double adx[], emaFast[], emaSlow[], rsi[], atr[];
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(handleADX, 0, 0, 3, adx) < 3) return;
   if(CopyBuffer(handleEMAFast, 0, 0, 3, emaFast) < 3) return;
   if(CopyBuffer(handleEMASlow, 0, 0, 3, emaSlow) < 3) return;
   if(CopyBuffer(handleRSI, 0, 0, 3, rsi) < 3) return;
   if(CopyBuffer(handleATR, 0, 0, 3, atr) < 3) return;

   //--- Lógica de Tendencia
   bool isTrendUp   = (emaFast[1] > emaSlow[1]) && (adx[1] > InpADXMinLevel);
   bool isTrendDown = (emaFast[1] < emaSlow[1]) && (adx[1] > InpADXMinLevel);

   double currentATR = atr[1];
   double slDistance = currentATR * InpATRMultiplier;
   
   //--- Lógica de Entrada
   if(isTrendUp && rsi[2] < InpRSILowLevel && rsi[1] > rsi[2])
   {
      double buyPrice = symInfo.Ask();
      double sl = buyPrice - slDistance;
      double tp = buyPrice + (slDistance * InpTPMultiplier);
      double lot = CalculateLot(slDistance);
      
      if(lot > 0)
         trade.Buy(lot, _Symbol, buyPrice, sl, tp, "Apex Buy");
   }
   else if(isTrendDown && rsi[2] > InpRSIHighLevel && rsi[1] < rsi[2])
   {
      double sellPrice = symInfo.Bid();
      double sl = sellPrice + slDistance;
      double tp = sellPrice - (slDistance * InpTPMultiplier);
      double lot = CalculateLot(slDistance);
      
      if(lot > 0)
         trade.Sell(lot, _Symbol, sellPrice, sl, tp, "Apex Sell");
   }
}

//+------------------------------------------------------------------+
//| Gestión de Posiciones Abiertas                                   |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         double atrValue = GetCurrentATR();
         if(atrValue <= 0) continue;

         //--- Breakeven
         if(InpUseBreakeven)
         {
            double risk = MathAbs(openPrice - currentSL);
            if(type == POSITION_TYPE_BUY && bid >= openPrice + (risk * InpBELevel))
            {
               if(currentSL < openPrice)
                  trade.PositionModify(PositionGetTicket(i), openPrice, currentTP);
            }
            else if(type == POSITION_TYPE_SELL && ask <= openPrice - (risk * InpBELevel))
            {
               if(currentSL > openPrice || currentSL == 0)
                  trade.PositionModify(PositionGetTicket(i), openPrice, currentTP);
            }
         }

         //--- Trailing Stop
         if(InpUseTrailing)
         {
            double trailDist = atrValue * InpTrailingStep;
            if(type == POSITION_TYPE_BUY)
            {
               double newSL = bid - (atrValue * InpATRMultiplier);
               if(newSL > currentSL && bid > openPrice)
                  trade.PositionModify(PositionGetTicket(i), NormalizeDouble(newSL, _Digits), currentTP);
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double newSL = ask + (atrValue * InpATRMultiplier);
               if((newSL < currentSL || currentSL == 0) && ask < openPrice)
                  trade.PositionModify(PositionGetTicket(i), NormalizeDouble(newSL, _Digits), currentTP);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cálculo de Lote Dinámico                                         |
//+------------------------------------------------------------------+
double CalculateLot(double slDistance)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(slDistance <= 0 || tickValue <= 0) return 0;
   
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
   double lotStep    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double lot = riskAmount / (slDistance / tickSize * tickValue);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Utilidades                                                       |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBar;
   datetime currentBar = iTime(_Symbol, _Period, 0);
   if(currentBar != lastBar)
   {
      lastBar = currentBar;
      return true;
   }
   return false;
}

double GetCurrentATR()
{
   double atr[];
   if(CopyBuffer(handleATR, 0, 0, 1, atr) < 1) return 0;
   return atr[0];
}

bool PositionSelectByMagic(long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| OnTester: Modelo Robusto Balanceado                              |
//+------------------------------------------------------------------+
double OnTester()
{
   const int trades    = (int)TesterStatistics(STAT_TRADES);
   const double profit = TesterStatistics(STAT_PROFIT);
   const double pf     = TesterStatistics(STAT_PROFIT_FACTOR);
   const double rf     = TesterStatistics(STAT_RECOVERY_FACTOR);
   const double dd_rel = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT) / 100.0);
   const double gross_loss = MathAbs(TesterStatistics(STAT_LOSS_TRADES));
   const double payoff = (gross_loss < 0.0001) ? 0.0 : TesterStatistics(STAT_PROFIT_TRADES) / gross_loss;

   if(trades < 50 || pf <= 1.0 || profit <= 0) return 0.0;

   // Modelo balanceado: (PF * RF * Payoff) * Penalti de muestra / (1 + Drawdown)
   double fitness = (pf * rf * payoff) * MathMin(1.0, trades / 200.0) / (1.0 + dd_rel);

   PrintFormat("PF=%.2f RF=%.2f Payoff=%.2f Winrate=%.1f%% Trades=%d DDrel=%.2f Fitness=%.4f",
               pf, rf, payoff,
               (trades > 0) ? (100.0 * TesterStatistics(STAT_PROFIT_TRADES) / trades) : 0,
               trades, dd_rel, fitness);

   return fitness;
}
