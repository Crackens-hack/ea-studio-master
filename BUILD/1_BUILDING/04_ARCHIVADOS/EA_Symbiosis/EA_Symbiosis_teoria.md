# EA_Symbiosis ? Teor?a

## L?gica
- Timeframe configurable (por defecto M15).
- Se?al: cruce SMA r?pida (InpFastPeriod) sobre/under SMA lenta (InpSlowPeriod) usando velas cerradas (shift 1 y 2) para evitar lookahead.
- Filtro de calma: se exige ATR (InpATRPeriod) >= InpMinRangePips para evitar rangos ultra estrechos.
- Gesti?n de posiciones: solo una posici?n activa; al cambio de se?al se cierra y revierte.
- SL/TP fijos en pips; trailing opcional (start/step en pips).

## Entradas principales (prefijo Inp*)
- InpLotFixed: lote fijo (0.01 step ProCent).
- InpFastPeriod / InpSlowPeriod: per?odos SMA (Fast < Slow).
- InpATRPeriod, InpMinRangePips: filtro de rango m?nimo.
- InpSL_Pips / InpTP_Pips: distancia de stop / take profit.
- InpUseTrailing, InpTrailStartPips, InpTrailStepPips: trailing sencillo.
- InpTF: timeframe de trabajo.

## Gesti?n de riesgo
- Lote fijo pensado para balance 5000 (simetr?a ProCent). Ajustar seg?n riesgo deseado.
- SL/TP en pips; trailing reduce exposici?n en runs favorables.

## OnTester (modelo Robusto)
- Umbral: trades >=50, PF>1.0, Profit>0.
- Fitness = (PF * RecoveryFactor * Payoff) * rampa(trades/200) / (1 + DDrel).
- Log imprime PF/RF/Payoff/WR/Trades/DD/Fit para auditor?a en DuckDB.

## Sugerencias de uso
- Par: EURUSD o majors con spread bajo.
- Timeframe: M15/H1.
- Balance tester: 5000 (ProCent sim?trico), apalancamiento 1:2000, lot 0.01.

## Pr?ximos pasos
1. Compilar con `01_Compilador.ps1` (si autoriz?s).
2. Generar preset base `.set` en la instancia activa (dos carpetas: Presets y Profiles/Tester).
3. Smoke test r?pido con `Tools-Agents/02_M-Tester-AutoAgents.ps1 single_logic`.
