# Apex Kraken V1 - El Depredador de Regímenes

## 💎 Visión
El **Apex Kraken** no es un robot de indicadores; es un **algoritmo de estados de mercado**. Mientras que los EAs convencionales (como los que Codex suele ensamblar) fallan cuando el mercado cambia de tendencia a rango, el Kraken utiliza la **Volatilidad Fractal** para decidir si entra en modo *Breakout* o se queda en el fondo esperando liquidez.

## 📈 Lógica de Ejecución (El "Edge")
### 1. Filtro de Contexto (Hull Moving Average - HMA)
Usamos una HMA de 200 períodos. A diferencia de la EMA, la HMA reduce casi a cero el lag, permitiéndonos estar posicionados en la tendencia antes de que el resto del mercado la vea.
- **Trend UP**: HMA(t) > HMA(t-1)
- **Trend DOWN**: HMA(t) < HMA(t-1)

### 2. Gatillo de Entrada (Donchian Breakout + Confirmación de Volumen)
No entramos por cruces. Entramos por la ruptura del máximo/mínimo de las últimas **N velas** (Canal de Donchian).
- **Entrada Long**: El precio rompe el máximo de 20 velas Y estamos en Trend UP.
- **Entrada Short**: El precio rompe el mínimo de 20 velas Y estamos en Trend DOWN.

### 3. Filtro de Volatilidad (ATR Ratio)
El Kraken mide el ATR actual frente a su media de largo plazo. Si la volatilidad es demasiado baja (mercado muerto) o demasiado alta (caos), el EA entra en modo "Shadow" y cancela operaciones para proteger el capital de $100.

## 🛡️ Gestión de Riesgo "Tiburón"
- **Stop Loss Dinámico**: Se coloca en el mínimo/máximo de la vela de ruptura. Si la ruptura es genuina, el precio no debe volver ahí.
- **Trailing Stop "Kraken"**: A medida que el precio avanza, el SL se mueve usando un multiplicador de ATR que se ajusta según la fuerza del ADX. Si la tendencia es muy fuerte, le damos aire; si se debilita, apretamos el cuello a la posición.
- **Breakeven Inteligente**: Protege la entrada en cuanto el profit cubre los costes de swap y spread, moviendo el SL a +1 pip.

## 📊 OnTester (Fitness de Grado Institucional)
El optimizador no busca solo dinero. Busca el **Ratio de Calmar**:
`Fitness = (Net Profit / Max Equity Drawdown) * (Recovery Factor^2)`
Esto castiga severamente los 'flukes' (golpes de suerte) y premia la consistencia matemática.

## 🚀 Misión 10x
Diseñado para ser el caballo de batalla principal. Si un activo tiene liquidez, el Kraken encontrará el flujo de dinero.
