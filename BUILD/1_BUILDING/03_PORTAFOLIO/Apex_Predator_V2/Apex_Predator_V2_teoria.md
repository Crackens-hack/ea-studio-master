# 🦈 Apex Predator V2: Ghost Hunter (Phoenix Protocol Edition)

## 🎯 Objetivo de Ingeniería
Lograr una curva de equidad con **consistencia anual positiva (12/12 años)** para permitir el uso de **Compounding Agresivo** ($50 -> $1000 en 60 días).

## 🧠 Evolución de la Lógica (V1 vs V2)

| Característica | Predator V1 (Ciego) | Predator V2 (Ghost Hunter) |
|:---|:---|:---|
| **Señal Base** | RSI + BB | RSI + BB (Optimizada) |
| **Filtro Tendencia** | Ninguno | **ADX (Detección de Trend)** |
| **Contexto** | Ninguno | **EMA 200 (Flow Bias)** |
| **Gestión Riesgo** | SL/TP Fijo | **SL Dinámico + Proteccion ProCent** |
| **Compounding** | Inestable | **Optimizado para Crecimiento Geométrico** |

---

## 🏗️ Arquitectura de Señal

1.  **Filtro de Inercia (EMA 200)**:
    - Solo habilitamos **BUY** si `Close[1] > EMA(200)`.
    - Solo habilitamos **SELL** si `Close[1] < EMA(200)`.
    - *Razón*: Evitamos pelear contra la marea institucional.

2.  **Filtro de Peligro (ADX)**:
    - Si `ADX(14) > 30`, el mercado está en tendencia fuerte. **BOT APAGADO**.
    - Solo operamos cuando el mercado está en "Rango" o "Impulso debil".

3.  **El Gatillo (Sniper Entry)**:
    - Rompimiento de Banda de Bollinger Inferior + RSI < 30.
    - Confirmación con **Vela de Rechazo** (Pin Bar o Mecha larga).

## 💰 Gestión de Riesgo (Protocolo Fénix)
- **Depósito de Máquina**: 5000 cent ($50).
- **Riesgo por Operación**: 2% a 10% (Variable según precisión).
- **Meta de Escalamiento**: Duplicar balance cada 15-20 días mediante reinversión total.

## 🏛️ Estándar de Prueba
- **Backtest**: 2014-2026 (12 años).
- **Requisito de Éxito**: Sin años perdedores (Net Profit > 0 en cada fragmento).
