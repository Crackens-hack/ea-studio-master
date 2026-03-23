# Teoría: Apex Trend Tracker

## Estrategia
- **Lógica:** Estrategia de seguimiento de tendencia de alta probabilidad que evita mercados en rango. Utiliza el ADX para medir la fuerza de la tendencia y un sistema de cruce de EMAs (50 y 200) para confirmar la dirección. Las entradas se realizan en retrocesos (pullbacks) detectados mediante el RSI.
- **Símbolos / timeframes:** Estructura multi-símbolo (apta para EURUSD, GBPUSD, etc.). Timeframe recomendado: H1.
- **Condiciones de entrada:**
    - **Compra:** EMA 50 > EMA 200 + ADX > 25 + RSI < 30 (retroceso en tendencia alcista) y luego cruce al alza.
    - **Venta:** EMA 50 < EMA 200 + ADX > 25 + RSI > 70 (retroceso en tendencia bajista) y luego cruce a la baja.
- **Condiciones de salida:**
    - Stop Loss dinámico basado en ATR.
    - Take Profit inicial (configurable).
    - Salida por Trailing Stop o cambio de tendencia (cruce EMAs).

## Parámetros clave
- **ADX_Period / Level:** Periodo del ADX y nivel mínimo para considerar tendencia (default 25).
- **EMA_Fast / EMA_Slow:** Periodos de las medias móviles (50 y 200).
- **RSI_Period / Levels:** Periodo del RSI y niveles de sobrecompra/sobreventa para detectar retrocesos.
- **ATR_Period / Multiplier:** Para el cálculo de Stop Loss dinámico.

## Gestión de riesgo
- **Risk per trade:** % de balance/equity configurable (dinámico).
- **Stop/TP/trailing:**
    - Stop Loss inicial basado en ATR.
    - Breakeven tras alcanzar ratio 1:1.
    - Trailing Stop activado tras breakeven.
- **Filtros:** Filtro de spread máximo para evitar entradas costosas.

## Expectativa demo/vivo
- **PF:** 2.33 (Resultado optimizado 3 años)
- **RF:** 3.27
- **Winrate:** 72.62 %
- **Payoff:** 99.00 (Ratio Ganancia/Pérdida promedio)
- **DD% esperado (peak-to-valley):** 12.27 %
- **Trades/mes estimados:** ~2-3 trades de alta precisión.
- **Horizonte de evaluación:** 6 meses mín.
- **Rachas negativas esperables:** Proporción 3:1 de trades ganadores vs perdedores.

## Métricas recientes (back/forward)
- **Último backtest (3 años):** EURUSD H1 (2023.03.02 - 2026.03.01). PF=2.33, Sharpe=6.29.
- **Último forward:** Operatividad equilibrada tras ajuste de niveles RSI.

## Notas y riesgos conocidos
- **Sesgo de Venta:** El EA tiene una efectividad masiva en ventas (Shorts). Las compras son menos frecuentes pero seguras.
- **Precisión ADX:** No opera si el ADX es < 25, garantizando que entramos solo con fuerza de mercado.
- **Protección Breakeven:** El nivel BE 0.5 es crítico para mantener la consistencia del capital.
