# T-Shark V1 - Teoría de Estrategia

## 💎 Visión
Estrategia de **Reversión a la Media** diseñada para el "Modo Tiburón". Busca capturar agotamientos de tendencia en marcos temporales de H1 para escalar cuentas pequeñas ($100-$1000) mediante una gestión de riesgo precisa y objetivos de beneficio dinámicos.

## 📈 Lógica de Entrada
- **Compra (Long)**:
    - El precio toca o traspasa la **Banda de Bollinger Inferior** (20, 2).
    - El **RSI (14)** está por debajo de 30 (sobreventa).
    - Confirmación: El RSI cruza hacia arriba el nivel 30 o el precio cierra dentro de las bandas.
- **Venta (Short)**:
    - El precio toca o traspasa la **Banda de Bollinger Superior** (20, 2).
    - El **RSI (14)** está por encima de 70 (sobrecompra).
    - Confirmación: El RSI cruza hacia abajo el nivel 70 o el precio cierra dentro de las bandas.

## 🛡️ Gestión de Riesgo
- **Stop Loss (SL)**: Basado en ATR (1.5 * ATR). Protege contra volatilidad extrema.
- **Take Profit (TP)**: Basado en ATR (2.0 - 3.0 * ATR) o retorno a la Media Móvil central (BB).
- **Riesgo Dinámico**: `InpRiskPercent` (2% - 10% según bitácora de urgencia).
- **Breakeven**: Se activa cuando el beneficio alcanza 1.0 * ATR.

## 📊 Métricas de Optimización (OnTester)
El fitness se calcula buscando el equilibrio entre:
1. **Profit Factor**: Eficiencia de la estrategia.
2. **Drawdown Máximo**: Supervivencia del capital de $100.
3. **Recovery Factor**: Capacidad de salir de rachas negativas.

## 🚀 Objetivo 10x
Diseñado para operar en símbolos con spread bajo (EURUSD, GBPUSD). Se recomienda testear con $1,000 para validar el "Edge" y luego aterrizar a $100 bajando el riesgo si el DD es superior al 20%.
