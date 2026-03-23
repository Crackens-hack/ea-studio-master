# 🤖 GUÍA DE OPERACIÓN: 02_M-Tester-AutoAgents.ps1

Este script es el **brazo ejecutor autónomo** de la fábrica `.eastudio`. Está diseñado para eliminar la fricción de la interactividad manual, permitiendo que un Agente de IA (o el Fundador) dispare pruebas masivas de validación con un solo comando.

---

## 📍 UBICACIÓN DEL MOTOR
*   **Script**: `Tools-Agents\02_M-Tester-AutoAgents.ps1`
*   **Configuración Base**: Se apoya en `Tools\EXEC-INI\mtester.conf` para fechas y balance.
*   **Modos de Prueba**: Utiliza los archivos `.ini` en `Tools\` (ej. `single_test.ini`, `single_logic.ini`).

---

## 🚀 CÓMO EJECUTARLO (Comando Maestro)

Desde la raíz del proyecto `.eastudio` y con el `.venv` activado:

```powershell
.\Tools-Agents\02_M-Tester-AutoAgents.ps1 -EAName "NOMBRE_DEL_EA" -Symbol "EURUSD" -TF "H1" -Range "rango300" -Mode "single_logic" -AutoNormalize
```

### **Parámetros Clave:**
| Parámetro | Descripción | Ejemplo |
| :--- | :--- | :--- |
| `-EAName` | Nombre del EA en `BUILD/01_ea_construccion` (sin el .ex5). | `"Apex_Kraken_V1"` |
| `-Symbol` | Símbolo para el backtest. | `"EURUSD"`, `"XAUUSD"` |
| `-TF` | Timeframe del gráfico. | `"H1"`, `"M15"`, `"M1"` |
| `-Range` | Key del rango de días definido en `mtester.conf`. | `"rango300"`, `"rango100"` |
| `-Mode` | Nombre del archivo `.ini` en `Tools/` (sin el .ini). | `"single_logic"`, `"single_test"` |
| `-AutoNormalize` | **(Switch)** Si se incluye, corre el normalizador Python al terminar. | (Solo añadir el flag) |

---

## 📊 DÓNDE BUSCAR LOS RESULTADOS

El flujo de salida está diseñado para el análisis inmediato. Los resultados se guardan siguiendo esta jerarquía:

### 1. Reportes Crudos (MT5)
Se generan dentro de la carpeta de la instancia activa (Ejemplos: `RoboForex`, `Deriv`, o cualquier instancia configurada):
*   `00_setup\Instancias\<INSTANCIA>\instalacion\report\ <MODO>\<EA>_<MODO>.htm`

### 2. Reportes Normalizados (Para Humanos y Agentes)
Si usaste el flag `-AutoNormalize`, los encontrarás aquí:
*   **Markdown (.md)** (Lectura rápida): `RESULTADOS\Reportes-Normalizados\<MODO>\<EA>_<MODO>.md`
*   **JSON (.json)** (Para DuckDB/Agentes): `RESULTADOS\Reportes-Normalizados\<MODO>\<EA>_<MODO>.json`
*   **Copia HTM**: `RESULTADOS\Reportes-Normalizados\<MODO>\<EA>_<MODO>.htm`

---

## 🛡️ REGLAS DE ORO PARA EL FUNDADOR

1.  **Compilación Previa**: El script busca el binario `.ex5`. Asegúrate de haber compilado el EA con `01_Compilador.ps1` antes de lanzar el test.
2.  **Uso de Presets**: Si el modo requiere un `.set` (como `single_logic`), debes tener el archivo `<NOMBRE_EA>.set` en la carpeta `MQL5/Presets` de la instancia. El script lo moverá automáticamente al lugar correcto.
3.  **No Interrupción**: No abras la terminal de MetaTrader manualmente mientras el AutoAgent está corriendo, ya que el script usa el flag `/shutdown` y cerrará la terminal en cuanto termine su tarea.

---
*Documentación generada por el Agente para la Fábrica de Supervivencia .eastudio (2026).*
