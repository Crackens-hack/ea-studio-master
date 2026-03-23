# 🎯 Estrategia de Ciclos Secuenciales (Concepto de Ezequiel)

> **Fecha de conceptualización:** 2026-03-12  
> **Estado:** Concepto documentado, pendiente de implementación como EA separado.  
> **Diferencia clave vs Apex Sniper V1:** Ordenes SECUENCIALES (no simultáneas). La segunda orden abre DESPUÉS que la primera cierra en ganancia.

---

## Estructura de cada ciclo

Cada ciclo consiste en **dos operaciones consecutivas**, con roles distintos:

| Operación | Función principal       | Riesgo                                      | Take Profit                                    | Stop Loss                      | Trailing                                                                                   |
| --------- | ----------------------- | ------------------------------------------- | ---------------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------ |
| 1ra       | Sniper / base del ciclo | % fijo del capital (ej. 20%)                | No se define, solo TP imaginario de referencia | Sí, calculado en % del capital | Se activa después de cubrir spread o mitad del TP imaginario, moviendo SL a break even     |
| 2da       | Maximizar ganancias     | % fijo o variable según capital (ej. 15%)   | Ninguno                                        | Ninguno fijo                   | Trailing stop desde break even de primera operación o nivel que cubre ganancia mínima      |

---

## Detalle de la primera operación

- **Apertura:** solo cuando el sistema da señal clara ("sniper").
- **Stop Loss:** calculado en porcentaje del capital. Es el **seguro de vida**.
- **Take Profit imaginario:**
  - No se coloca en MT como TP real. Solo sirve como referencia de nivel de cierre programático.
  - Se usa para activar el trailing stop (cuando precio avanza la mitad de este TP imaginario).
- **Trailing stop:**
  - Se activa cuando el precio supera el punto de cobertura de spread o mitad del TP imaginario.
  - Mueve el SL a **break even** y sigue el precio.
  - Peor escenario desde este momento: cero ganancia/pérdida.

---

## Detalle de la segunda operación

- Se abre **solo si la primera cerró ganando**.
- **Riesgo:** mismo monto absoluto o % menor del capital (ej. 15%) para proteger la ganancia.
- **SL:** no fijo. Trailing stop desde el nivel de break even de la primera operación.
- **TP:** no se define. La operación crece libremente hasta donde el mercado permita.
- **Objetivo:** capturar todo el movimiento restante a favor. Ganancia exponencial.

---

## Conceptos técnicos clave para implementación

1. **Take Profit imaginario:** Nivel de referencia programático. No se coloca en MT5. Se usa para decisiones lógicas del EA (cuándo activar trailing, cuándo cerrar).

2. **Break Even:** Punto de entrada + spread mínimo cubierto. Protege la primera operación cuando el precio avanzó suficiente.

3. **Trailing Stop dinámico:** Mueve SL automáticamente detrás del precio con distancia mínima configurable para evitar cierres prematuros.

4. **Gestión de riesgo por operación:**
   - Primera operación: asegura la base.
   - Segunda operación: explota ganancias sin comprometer capital inicial.
   - Base filosófica: **controlar pérdidas, dejar correr ganancias**.

5. **Compounding progresivo (opcional):** Recalcular tamaño de segunda operación según capital actualizado → crecimiento exponencial.

---

## Flujo de cada ciclo

```
1. Señal sniper → abrir primera operación
2. SL calculado en % del capital
3. Precio avanza → activar trailing stop
   → Mover SL a break even → seguir precio
4. Cierre de primera operación:
   → Automático si alcanza TP imaginario o trailing stop la cierra
5. Si primera operación GANÓ → abrir segunda operación
   → Trailing stop desde nivel BE de primera operación
   → Sin TP fijo → crece hasta donde el mercado permita
6. Recalcular riesgo y lote según capital (si se quiere compounding)
7. Ciclo completo → capital actualizado → repetir
```

---

## Comparación vs Apex Sniper V1

| Característica | Apex Sniper V1 | Esta Estrategia |
|---|---|---|
| **Tipo de entrada** | Piramidación simultánea | Escalada secuencial |
| **Salida** | Trailing Stop global | TP imaginario + Trailing |
| **Lotaje** | Fijo | Compuesto progresivo |
| **Riesgo** | Global sobre todas las posiciones | Individual por operación |
| **Segunda entrada** | Mientras sube (pirámide) | Solo si primera cerró en profit |

---

## Estado de implementación

- [ ] Diseñar lógica de "TP imaginario" en MQL5 (variable interna, no orden real)
- [ ] Implementar trailing por % del capital (no por pips fijos)
- [ ] Programar condición: segunda orden solo si primera cerró en verde
- [ ] Parámetro: porcentaje de riesgo por operación (1ra y 2da independientes)
- [ ] Parámetro: distancia del trailing (optimizable)
- [ ] Parámetro: espera entre primera y segunda orden (velas de confirmación)
