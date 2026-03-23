# Teoría: Momentum Ranger

## Estrategia
- **Lógica:** Detector de rupturas de rangos con confirmación de momentum. Opera cuando el mercado sale de períodos de consolidación utilizando Bollinger Bands como detector de rangos, RSI para confirmar momentum y ATR para filtrar rupturas significativas.
- **Símbolos / timeframes:** Multi-símbolo (EURUSD, GBPUSD, XAUUSD). Timeframe óptimo: M15 para entradas, H1 para análisis.
- **Condiciones de entrada:**
    - **Compra:** Precio cierra fuera de banda superior de Bollinger + RSI > 60 + ATR > umbral mínimo (ruptura con volumen implícito)
    - **Venta:** Precio cierra fuera de banda inferior de Bollinger + RSI < 40 + ATR > umbral mínimo
- **Condiciones de salida:**
    - TP fijo en relación al ATR (2.5x ATR)
    - SL dinámico basado en el punto de ruptura
    - Salida por trailing stop después de TP parcial

## Parámetros clave
- **BB_Period / Deviation:** Periodo y desviación estándar de Bollinger Bands (20, 2)
- **RSI_Period / Levels:** Periodo RSI y niveles de confirmación (14, 60/40)
- **ATR_Period / MinLevel:** Periodo ATR y nivel mínimo para considerar ruptura válida (14, 0.0005)
- **Risk_Percent:** % de riesgo por operación (1.0%)
- **TP_Multiplier:** Multiplicador del TP respecto al ATR (2.5)

## Gestión de riesgo
- **Risk per trade:** 1.0% del balance por defecto
- **Stop/TP:**
    - Stop Loss: 1x ATR desde el punto de entrada
    - Take Profit: 2.5x ATR
    - Trailing activado después de alcanzar 1x ATR de ganancia
- **Filtros:** Spread máximo, hora de operación, filtro de volatilidad

## Expectativa demo/vivo
- **PF objetivo:** 1.8-2.2
- **RF objetivo:** 2.5-3.0
- **Winrate esperado:** 65-75%
- **Payoff esperado:** >1.5
- **DD% esperado (peak-to-valley):** 8-15%
- **Trades/mes estimados:** 15-25 operaciones
- **Horizonte de evaluación:** 3 meses mínimo
- **Rachas negativas esperables:** Máximo 3-4 operaciones consecutivas

## Ventajas competitivas
- **Alta frecuencia:** Más operaciones que estrategias de tendencia pura
- **Filtros robustos:** Múltiples confirmaciones evitan falsas rupturas
- **Complementariedad:** Opera bien en mercados laterales donde ApexTrendTracker podría tener menos señales
- **Risk/Reward balanceado:** TP 2.5x SL proporciona buen ratio

## Riesgos conocidos
- **Whipsaws:** Rupturas falsas en mercados volátiles
- **Sobreoptimización:** Necesita parametrización cuidadosa
- **Dependencia de ATR:** Mercados de baja volatilidad pueden generar pocas señales