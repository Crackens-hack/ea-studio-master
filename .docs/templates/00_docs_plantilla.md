[Common] - Configuración General de la Plataforma
Equivalente a la pestaña "Servidor":

Login: Número de cuenta.
Server: Dirección y puerto del servidor comercial (ej. RoboForex-Pro:443).
Password: Contraseña de la cuenta.
CertPassword: Contraseña del certificado (si se usa autenticación extendida).
ProxyEnable: Permitir (1) o prohibir (0) conexión vía proxy.
ProxyType: Tipo de proxy: 0 (SOCKS4), 1 (SOCKS5), 2 (HTTP).
ProxyAddress: IP y puerto del proxy.
ProxyLogin / ProxyPassword: Credenciales del proxy.
KeepPrivate: Guardar contraseña entre conexiones: 1 (Sí), 0 (No).
NewsEnable: Habilitar (1) o deshabilitar (0) noticias.
CertInstall: Instalar (1) o no (0) nuevos certificados en el sistema.
MQL5Login / MQL5Password: Cuenta y contraseña de MQL5.community.
[Charts] - Configuración de Gráficos
ProfileLast: Nombre del perfil actual.
MaxBars: Número máximo de barras en el gráfico.
PrintColor: Modo de impresión: 1 (Color), 0 (Blanco y negro).
SaveDeleted: Guardar (1) gráfico eliminado para reabrirlo luego.
[Experts] - Configuración de Asesores Expertos (EA)
AllowLiveTrading: Habilitar (1) o deshabilitar (0) el trading algorítmico real.
AllowDllImport: Permitir (1) o no (0) la importación de DLLs externas.
Enabled: Activa o desactiva el uso de EAs a nivel global.
Account: Desactivar (1) EAs al cambiar de cuenta.
Profile: Desactivar (1) EAs al cambiar de perfil activo.
[Objects] - Configuración de Objetos Gráficos
ShowPropertiesOnCreate: Mostrar (1) propiedades al crear un objeto.
SelectOneClick: Seleccionar (1) objetos con un solo clic.
MagnetSens: Sensibilidad del imán para anclar objetos.
[Email] - Configuración de Correo Electrónico
Enable: Habilitar (1) el uso de notificaciones por email.
Server: Servidor SMTP.
Auth: Información de autenticación encriptada.
Login / Password: Credenciales del servidor SMTP.
From / To: Nombre/Dirección del remitente y del destinatario.
[StartUp] - Ejecución Automática al Iniciar la Plataforma
Expert: Nombre del EA que se abrirá automáticamente. Se ejecuta en el símbolo/periodo definido abajo.
Symbol: Símbolo del gráfico adicional que se abrirá al inicio.
Period: Timeframe del gráfico (cualquiera de los 21 periodos). Por defecto H1.
Template: Nombre de la plantilla (.tpl) a aplicar.
ExpertParameters: Nombre del archivo 

.set
 (debe estar en MQL5\Presets).
Script: Nombre del script a ejecutar automáticamente.
ScriptParameters: Parámetros del script (

.set
 en MQL5\Presets).
ShutdownTerminal: Apagar la plataforma al finalizar el script: 1 (Sí), 0 (No).
[Tester] - Parámetros del Probador de Estrategias (Backtesting/Optimización)
IMPORTANTE: Esta sección es el motor de tu fábrica.

Expert: Nombre del archivo del EA (

.ex5
) para probar u optimizar.
ExpertParameters: Nombre del archivo 

.set
. DEBE estar en MQL5\Profiles\Tester.
Symbol: Símbolo principal para la prueba.
Period: Timeframe de la prueba.
Login: Simula que la cuenta tiene este número (para validaciones de código AccountInfoInteger).
Model: Generación de ticks:
0: Cada tick.
1: OHLC de 1 minuto.
2: Solo precios de apertura.
3: Cálculos matemáticos.
4: Cada tick basado en ticks reales.
ExecutionMode: Simulación de retraso (latencia): 0 (Normal), -1 (Aleatorio), >0 (Retraso en ms).
Optimization: Tipo de optimización:
0: Deshabilitada (Single test).
1: Algoritmo completo lento.
2: Algoritmo genético rápido.
3: Todos los símbolos del Market Watch.
OptimizationCriterion: Criterio de éxito:
0: Saldo máximo.
1: Balance * Rentabilidad.
2: Balance * Payoff esperado.
3: (100% - Drawdown) * Balance.
4: Balance * Factor de recuperación.
5: Balance * Ratio de Sharpe.
6: Criterio personalizado (OnTester).
7: Criterio complejo máximo.
FromDate / ToDate: Rango de fechas (YYYY.MM.DD).
ForwardMode: Modo Forward: 0 (Off), 1 (1/2 del periodo), 2 (1/3), 3 (1/4), 4 (Intervalo personalizado).
ForwardDate: Fecha de inicio del Forward si ForwardMode=4.
Report: Nombre del archivo del reporte (ej. reports\mi_backtest.htm).
ReplaceReport: Sobrescribir reporte existente: 1 (Sí), 0 (No).
ShutdownTerminal: Apagar plataforma al terminar la prueba: 1 (Sí), 0 (No).
Deposit: Depósito inicial (en la moneda de la cuenta).
Currency: Moneda del depósito (ej. USD, EUR).
Leverage: Apalancamiento (ej. 1:100).
UseLocal / UseRemote / UseCloud: Habilitar agentes locales, remotos o en la nube (1 o 0).
Visual: Habilitar (1) o deshabilitar (0) el modo visual.
Port: Puerto del agente local para ejecuciones en paralelo.