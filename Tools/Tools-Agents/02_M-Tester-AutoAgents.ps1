# ======================================================
# 02_M-Tester-AutoAgents (v1)
# Motor de Pruebas Automatizado para Agentes AI
# NO INTERACTIVO: Disenado para recibir parametros
# ======================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$EAName,              # Nombre del EA (sin .ex5 o con el)

    [Parameter(Mandatory=$false)]
    [string]$Mode = 'single_test', # Modo (debe existir un .ini en Tools/ con este nombre)

    [Parameter(Mandatory=$false)]
    [string]$Symbol = 'EURUSD',

    [Parameter(Mandatory=$false)]
    [string]$TF = 'H1',

    [Parameter(Mandatory=$false)]
    [string]$Range = '_1ano',     # Key del rango en mtester.conf (ej. rango300=300)

    [Parameter(Mandatory=$false)]
    [int]$Model = 1,              # 0=Ticks, 1=OHLC M1

    [Parameter(Mandatory=$false)]
    [switch]$AutoNormalize        # Ignorado en esta version simplificada
)

$root = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$configFile = Join-Path $root 'Tools\Tools-Human\EXEC-INI\mtester.conf'
$credFile   = Join-Path $root '00_setup\Instancias\credencial_en_uso.json'
$iniOutput  = Join-Path $root 'Tools\Tools-Human\EXEC-INI\exec.ini'

# --- FUNCIONES NUCLEO ---
function Parse-Config {
    param($file)
    $cfg=@{}
    foreach($line in Get-Content $file){
        $trim = $line.Trim()
        if([string]::IsNullOrWhiteSpace($trim) -or $trim.StartsWith(";")){continue}
        if($line -match '^\s*([^=]+?)\s*=\s*(.*)$'){
            $key=$matches[1].Trim(); $val=$matches[2].Trim()
            $cfg[$key]=$val
        }
    }
    return $cfg
}

function Compute-FromDate($toDate,$days){
    $td=[datetime]::ParseExact($toDate,"yyyy.MM.dd",$null)
    return $td.AddDays(-$days).ToString("yyyy.MM.dd")
}

# --- VALIDACION DE CREDENCIALES ---
if(!(Test-Path $credFile)){
    Write-Error "ERROR: credencial_en_uso.json no encontrado."
    exit 1
}

$cred = Get-Content $credFile -Raw | ConvertFrom-Json
$terminal = $cred.terminal_exe
$instancia = $cred.ruta_instancia
$eaDir = Join-Path $instancia 'MQL5\Experts\Ea_Studio'
$presetsDir = Join-Path $instancia 'MQL5\Presets'
$testerDir  = Join-Path $instancia 'MQL5\Profiles\Tester'
$reportDir  = Join-Path $instancia 'report'
$templatesDir = Join-Path $root 'Tools\Tools-Human'

# --- CONFIGURACION ---
$config = Parse-Config $configFile
$toDate = $config['ToDate']
$eaCleanName = $EAName.Replace('.ex5','')
$eaPath = Join-Path $eaDir "$eaCleanName.ex5"

if(!(Test-Path $eaPath)){
    Write-Error "ERROR: No se encontro el EA en $eaPath"
    exit 1
}

# --- CALCULO DE FECHAS ---
$daysStr = $config[$Range]
if(!$daysStr){ $daysStr = '365' }
$days = [int]$daysStr
$fromDate = Compute-FromDate $toDate $days

# --- MANEJO DE PRESETS ---
$setName = "$eaCleanName.set"
$presetSrc = Join-Path $presetsDir $setName
$presetDest = Join-Path $testerDir $setName

if(Test-Path $presetSrc){
    Copy-Item $presetSrc $presetDest -Force
    Write-Host 'INFO: Preset copiado para la prueba.'
}

# --- GENERACION DE EXEC.INI ---
$reportPath = "report\$Mode\$eaCleanName`_$Mode"
$reportFullDir = Join-Path $reportDir $Mode
if(!(Test-Path $reportFullDir)){ New-Item $reportFullDir -ItemType Directory | Out-Null }

$ini = @()
$ini += '[Common]'
$ini += "Login=$($cred.credencial.cuenta)"
$ini += "Password=$($cred.credencial.password)"
$ini += "Server=$($cred.credencial.servidor)"
$ini += 'KeepPrivate=1'
$ini += ''
$ini += '[Tester]'
$ini += "Expert=Ea_Studio\$eaCleanName.ex5"
$ini += "Symbol=$Symbol"
$ini += "Period=$TF"
$ini += "Model=$Model"
$ini += "Spread=$($config['Spread'])"
$ini += 'UseDate=1'
$ini += "FromDate=$fromDate"
$ini += "ToDate=$toDate"
$ini += "Report=$reportPath"
$ini += 'ReplaceReport=1'
$ini += 'ShutdownTerminal=1' 
$ini += "Deposit=$($config['Deposit'])"
$ini += "Currency=$($config['Currency'])"
$ini += "Leverage=$($config['Leverage'])"

$tplFile = Join-Path $templatesDir "$Mode.ini"
if(Test-Path $tplFile){
    $ini += ''
    $ini += "; --- Plantilla del Modo: $Mode ---"
    $ini += Get-Content $tplFile
}

$ini | Set-Content $iniOutput -Encoding UTF8

# --- EJECUCION DEL TESTER ---
Write-Host ">>> AGENTE INICIANDO TEST: $eaCleanName"
Start-Process -FilePath $terminal -ArgumentList @('/portable', "/config:$iniOutput") -Wait

Write-Host '>>> OPERACION FINALIZADA.'
