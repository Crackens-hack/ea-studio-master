# 🚀 Apex Breakout V1: Sniper Volatility

> **ESTADO: CONSTRUCCIÓN (BUILDING)**
> **VERSIÓN: 1.0**
> **ESTÁNDAR: PROTOCOLO FÉNIX ($50 / 5000)**

## 🛡️ 1. Filosofía de Inversión
El **Apex Breakout V1** está diseñado para capturar movimientos explosivos tras periodos de compresión. No busca "cazar todos los pips", sino entrar con precisión quirúrgica cuando el mercado rompe una estructura con volumen y tendencia confirmada.

## 🎯 2. Lógica de Entrada (The Sniper)
1. **Estructura**: Usa un canal de **Donchian** (o consolidación de N periodos).
2. **Disparador (Trigger)**: Cierre de vela por fuera del canal.
3. **Filtro Pendular (Trend Slope)**: Calcula la pendiente de una Regresión Lineal o Media Móvil desplazada. Si la pendiente no tiene una inclinación clara (> Umbral), se descarta el breakout por considerarse "ruido de rango".
4. **Filtro de Fuerza (ADX)**: El ADX debe estar por encima de un nivel base (ej. 25) para confirmar que el breakout tiene inercia institucional.
5. **Filtro de Volatilidad (ATR)**: El breakout debe ocurrir con un ATR mayor al promedio de los últimos X periodos para filtrar falsos rompimientos en baja volatilidad.

## 📐 3. Gestión de Riesgo (Protocolo de Simetría)
- **Modo ProCent**: Optimizado para balance **5000** ($50 reales).
- **Riesgo 1:1**: Stop Loss y Take Profit simétricos basados en volatilidad.
- **SL/TP Adaptativo**: 
  - `SL = ATR(14) * Multiplicador`
  - `TP = ATR(14) * Multiplicador`
- **Volumen**: Lote fijo inicial (0.01 - 0.10) para validación de la curva de Win Rate. Preparado para escalado por % de balance (Compounding) en V2.
- **Restricción**: Solo un trade abierto a la vez (`Single Trade Mode`).

## 📊 4. Fitness Adaptativo (Hedge Fund V5.4)
Se integra el motor `OnTester()` mandatario para penalizar curvas de "martingala" o de baja consistencia temporal. El optimizador genético buscará la combinación que maximice el **Profit Smooth** y la **Estabilidad Mensual/Anual**.

---

## 📅 5. Expectativa Demo/Vivo
- **Balance Inicial**: 5000.
- **Objetivo**: Escalamiento progresivo hacia 100,000.
- **Drawdown Máximo**: < 25% relativo.
- **Win Rate Esperado**: > 55% para ratio 1:1.
