# 🦈 Apex Predator V1: Fundamentos Teóricos

**El Asesino de Rangos**

En contraposición a los modelos de Breakout que tienden a fallar en entornos ineficientes (donde gran parte del mercado moderno opera), Apex Predator V1 capitaliza sobre las *estiradas elásticas* del precio (Mean Reversion).

## Confluencia Mecánica (The Edge)
La arquitectura está montada sobre la tesis de **"El resorte estirado"**:
1.  **Bollinger Bands**: Capturan estadísticamente el ~95% del movimiento del precio dentro de la "Campana de Gauss" del mercado. Si el precio cierra por fuera de 2.0 a 3.0 Desviaciones Estándar (Dilation), estamos ante una anomalía.
2.  **RSI (Oscilador de Agotamiento)**: Se utiliza como confirmador. El cierre anómalo fuera de las bandas debe estar acompañado de pánico extremo (RSI < 30) o euforia extrema (RSI > 70).

Para que se abra un trade, **las dos condiciones deben converger** en el mismo milisegundo al cierre de la vela (Vela 1).

## Adaptabilidad Simétrica (Risk / Protocolo Fénix)
El Apex Predator se niega a usar Stops fijos de "20 pips" empíricos. Usa el ATR para ajustar dinámicamente sus Stop Loss y Take Profit. Jamás ejecuta una posición sin cobertura matemática adaptada a la volatilidad real del día.

## El Oxígeno del Trailing (Activador)
Introdujimos el input `InpTrailingTrigger`. Un Breakout se asfixia si lo persiguen rápido. Un trade de Reversión necesita aún más aire para madurar. El bot dejará operar a la reversión y SOLO moverá el Stop Loss a protección dinámica cuando el bot reporte una ganancia mínima equivalente a `X` veces el ATR (Ejemplo: 1 ATR). Si el precio rebota pero muere antes del Trigger, asume la pérdida completa (Win or Loss limpio).
