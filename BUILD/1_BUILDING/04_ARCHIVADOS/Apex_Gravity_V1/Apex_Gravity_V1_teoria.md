# 📊 Apex_Gravity_V1: Documentación Teórica y Mecánica

## 1. El Concepto Funcional (Mean Reversion)
A diferencia de los EAs tendenciales que buscan "subirse a la ola", `Gravity V1` se comporta como una banda elástica. Su premisa estadística básica dice que **el precio siempre debe volver a su media local**. 
Si sube o baja de forma desproporcionada y violentísima (rompiendo la Banda de Bollinger exterior) con un impulso que se queda sin fuerza de golpe (RSI Extremo), el precio cederá a la gravedad.

## 2. La Arquitectura de Riesgo Asimétrico (Phoenix Scaling)
Este EA no busca "no perder de a poquito". Busca "Ganar a lo grande rápido".
*   **Apalancamiento Agresivo:** Puesto por defecto para arriesgar el 5% del Balance en cada swing. 
*   **Asimetría Invertida Controlada:** Los Mean Reversion EAs suelen exigir un límite de pérdida `InpSL_ATR_Mult` mayor que su ganancia `InpTP_ATR_Mult`. Es decir, arriesgamos 3 de ATR para ganar apenas 1.5 de ATR (Risk/Reward Negativo), **PERO** el sistema acierta casi el 90% de las veces. Al multiplicarse con un riesgo tan gigante, la curva de ganancia mensual explota por matemática simple.

## 3. Gatillos (Sensórica Exclusiva)
*   **SELL (Caída Rápida):** El precio estalla hacia arriba cerrando fuera del techo de la Banda de Bollinger (`InpBandsDev = 2.5`), y el indicador de Momentum grita sobrecompra irracional (`RSI > 85`). Al primer milímetro de retroceso para confirmar la gravedad, se abre el corto.
*   **BUY (Rebote Rápido):** El precio se estrella contra el suelo, rompe el piso de Bollinger, la fuerza de caída marca sobreventa irracional (`RSI < 15`). A la primera resistencia natural en el gráfico, abrimos el largo brutal y vamos a buscar ese 1.5 ATR de corrección natural.

## 4. Juez Estadístico (Fitness Titan/Depredador)
Utilizamos el motor "Depredador Institucional V3" adaptado. La Genética del EA va a buscar activamente la máxima ganancia combinada con la menor probabilidad histórica de un rebote falso. Si el sistema sobreopera, lo liquida. Si tira la cuenta de fondeo al 25% de Drawdown, lo asesina y le da `Fitness = 0`. Muro matemático irrompible.
