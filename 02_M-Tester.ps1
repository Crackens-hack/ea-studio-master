# ======================================================
# 02_M-Tester (v4) - PROTOCOLO FÉNIX
# Strategy Tester Engine con Derivación Automática
# ======================================================

# Forzar Encoding UTF-8 para evitar problemas con 'años' y acentos
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = $PSScriptRoot

$configFile = Join-Path $root "Tools\\Tools-Human\EXEC-INI\mtester.conf"
$credFile   = Join-Path $root "00_setup\Instancias\credencial_en_uso.json"
$iniOutput  = Join-Path $root "Tools\\Tools-Human\\EXEC-INI\\exec.ini"

# -----------------------------------------------------
# FUNCIONES
# -----------------------------------------------------

function Parse-Config {

    param($file)

    $cfg=@{}

    foreach($line in Get-Content $file){

        $trim = $line.Trim()
        if([string]::IsNullOrWhiteSpace($trim) -or $trim.StartsWith(";")){
            continue
        }

        if($line -match '^\s*([^=]+?)\s*=\s*(.*)$'){

            $key=$matches[1].Trim()
            $val=$matches[2].Trim()

            $cfg[$key]=$val
        }
    }

    return $cfg
}

function Get-Modes {

    param($cfg)

    $modes=@()

    foreach($k in $cfg.Keys){

        if($k -match "^posicion(\d+)"){

            $pos=[int]$matches[1]

            $raw=$cfg[$k]
            $parts=$raw.Split(",")

            $name=$parts[0]
            $desc=""

            if($parts.Count -gt 1){
                $desc=$parts[1].Replace('"','')
            }

            $ranges=@()
            $preset=$false
            $autoNormalizer=$false
            $fragmentation=$false
            $autoCargador=$false
            $autoFilterPostFW=$false
            $filterNumerator=0
            $filterDenominator=1
            $derivaPos=""
            $derivaRange=""

            foreach($p in $parts){

                if($p -match "^_"){
                    
                    if($p -match "^_Auto_N(ZER)?_$"){
                        $autoNormalizer=$true
                    }
                    elseif($p -match "^_AutoCargador_$"){
                        $autoCargador=$true
                    }
                    elseif($p -match "^_Auto_Filter_Gen_For\[(\d+)/(\d+)\]_$"){
                        $autoFilterPostFW=$true
                        $filterNumerator=[int]$matches[1]
                        $filterDenominator=[int]$matches[2]
                    }
                    else {
                        $ranges+=$p
                    }
                }

                # Regex para {posicionN} o {posicionN:_rango}
                if($p -match "^\{posicion(\d+)(?::(.+))?\}$"){
                    $derivaPos=$matches[1]
                    $derivaRange=$matches[2] # Captura el rango si existe (_12años)
                }

                if($p -eq "preset"){
                    $preset=$true
                }

                if($p -eq "Fragmentacion"){
                    $fragmentation=$true
                }
            }

            $modes+=[PSCustomObject]@{
                pos=$pos
                name=$name
                desc=$desc
                ranges=$ranges
                preset=$preset
                autoNormalizer=$autoNormalizer
                fragmentation=$fragmentation
                autoCargador=$autoCargador
                autoFilterPostFW=$autoFilterPostFW
                filterNumerator=$filterNumerator
                filterDenominator=$filterDenominator
                derivaPos=$derivaPos
                derivaRange=$derivaRange
                fullTime=($parts -contains "Full_time")
            }
        }
    }

    return $modes | Sort pos
}

function Choose-FromList($items,$title){

    Write-Host ""
    Write-Host $title

    if(-not $items -or $items.Count -eq 0){
        Write-Host "No hay elementos para elegir."
        exit 1
    }

    $i=1

    foreach($it in $items){

        if($it.desc){
            Write-Host "[$i] $($it.name) - $($it.desc)"
        }
        else{
            Write-Host "[$i] $($it.name)"
        }

        $i++
    }

    $sel=Read-Host "Elegí número"
    $num=0

    if(-not [int]::TryParse($sel,[ref]$num) -or $num -lt 1 -or $num -gt $items.Count){
        Write-Host "Selección inválida."
        exit 1
    }

    return $items[$num-1]
}

function Compute-FromDate($toDate,$days){

    $td=[datetime]::ParseExact($toDate,"yyyy.MM.dd",$null)

    return $td.AddDays(-$days).ToString("yyyy.MM.dd")
}

# -----------------------------------------------------
# CREDENCIAL ACTIVA
# -----------------------------------------------------

if(!(Test-Path $credFile)){
Write-Host "credencial_en_uso.json no encontrado"
exit
}

$cred=Get-Content $credFile -Raw | ConvertFrom-Json

$terminal=$cred.terminal_exe
$instancia=$cred.ruta_instancia

$eaDir = Join-Path $instancia "MQL5\Experts\Ea_Studio"
$presetsDir = Join-Path $instancia "MQL5\Presets"
$testerDir  = Join-Path $instancia "MQL5\Profiles\Tester"
$reportDir  = Join-Path $instancia "report"
$templatesDir = Join-Path $root "Tools\\Tools-Human"

# -----------------------------------------------------
# CONFIG
# -----------------------------------------------------

$config=Parse-Config $configFile
$toDate=$config["ToDate"]

if(-not $toDate){
    Write-Host "ToDate no está definido en $configFile"
    exit 1
}

$modes=Get-Modes $config

# Variables de Memoria de Sesión (Persistence)
$sess_ea = $null
$sess_mode = $null
$sess_range = $null
$sess_symbol = $null
$sess_tf = $null
$sess_model = $null

while($true){

    # -----------------------------------------------------
    # SELECCION DE EA (SI NO HAY SESION)
    # -----------------------------------------------------
    if($null -eq $sess_ea){
        $eas=Get-ChildItem $eaDir -Filter *.ex5
        if(-not $eas -or $eas.Count -eq 0){
            Write-Host "No se encontraron EAs (.ex5) en $eaDir"
            exit 1
        }
        Write-Host ""
        Write-Host "EAs disponibles"
        $i=1
        foreach($ea in $eas){
            Write-Host "[$i] $($ea.Name)"
            $i++
        }
        $sel=Read-Host "Elegí EA"
        $eaIndex=0
        if(-not [int]::TryParse($sel,[ref]$eaIndex) -or $eaIndex -lt 1 -or $eaIndex -gt $eas.Count){
            Write-Host "Selección de EA inválida."
            exit 1
        }
        $sess_ea=$eas[$eaIndex-1]
    }

    $ea = $sess_ea
    $eaName=[System.IO.Path]::GetFileNameWithoutExtension($ea.Name)

    # -----------------------------------------------------
    # MODO (SI NO HAY SESION POR DERIVACION)
    # -----------------------------------------------------
    if($null -eq $sess_mode){
        $sess_mode = Choose-FromList $modes "Modos disponibles"
    }
    $mode = $sess_mode

    # -----------------------------------------------------
    # RANGO (SI NO HAY SESION)
    # -----------------------------------------------------
    if($null -eq $sess_range){
        $ranges=@()
        foreach($r in $mode.ranges){
            $ranges+=[PSCustomObject]@{
                name=$r
                days=$config[$r]
            }
        }
        Write-Host ""
        Write-Host "Rangos disponibles para $($mode.name)"
        $i=1
        foreach($r in $ranges){
            Write-Host "[$i] $($r.name) ($($r.days) días)"
            $i++
        }
        $rsel=Read-Host "Elegí rango (número)"
        $rangeIndex=0
        if(-not [int]::TryParse($rsel,[ref]$rangeIndex) -or $rangeIndex -lt 1 -or $rangeIndex -gt $ranges.Count){
            Write-Host "Selección de rango inválida."
            exit 1
        }
        $sess_range = $ranges[$rangeIndex-1]
    }
    $range = $sess_range

    $days=0
    if(-not [int]::TryParse($range.days,[ref]$days) -or $days -le 0){
        Write-Host "Valor de días inválido para el rango $($range.name): '$($range.days)'"
        exit 1
    }
    $fromDate=Compute-FromDate $toDate $days


    # -----------------------------------------------------
    # INPUT USUARIO (SI NO HAY SESION)
    # -----------------------------------------------------
    if($null -eq $sess_symbol){
        $defaultSymbol = $config["DefaultSymbol"]
        if ([string]::IsNullOrWhiteSpace($defaultSymbol)) { $defaultSymbol = "EURUSD" }
        $sess_symbol=Read-Host "Symbol (Enter $defaultSymbol)"
        if(!$sess_symbol){$sess_symbol=$defaultSymbol}
    }
    $symbol = $sess_symbol

    if($null -eq $sess_tf){
        $sess_tf = Read-Host "Timeframe (Enter H1)"
        if(!$sess_tf){$sess_tf="H1"}
    }
    $tf = $sess_tf

    if($null -eq $sess_model){
        $sess_model = Read-Host "Model 0=tick 1=ohlc (Enter=1)"
        if(!$sess_model){$sess_model=1}
    }
    $model = $sess_model

    # -----------------------------------------------------
    # PRESET
    # -----------------------------------------------------
    $set=""
    if($mode.preset){
        $set="$eaName.set"
        $preset=Join-Path $presetsDir $set
        $tester=Join-Path $testerDir $set

        if(Test-Path $preset){
            $presetContent = Get-Content $preset
            if(-not ($presetContent | Select-String -SimpleMatch ";archivo de configuracion")){
                Write-Host "El preset en Presets/$set no contiene ';archivo de configuracion'. Abortando."
                exit 1
            }
            $txt=$presetContent -join "`n"
            Set-Content $tester (";archivo movido por M-Tester`n"+$txt)
            Remove-Item $preset
        }
        elseif(-not (Test-Path $tester)){
            Write-Host "Modo requiere preset y no se encontró $set ni en Presets ni en Profiles/Tester. Abortando."
            exit 1
        }
        else {
            $testerLines = Get-Content $tester
            if($testerLines[0].Trim() -like "; saved automatically on*"){
                Write-Host "Se halló $set en Profiles/Tester pero es un autosave ('; saved automatically on ...'). Abortando."
                exit 1
            }
            if(-not ($testerLines | Select-String -SimpleMatch ";archivo de configuracion")){
                Write-Host "Se halló $set en Profiles/Tester pero no contiene ';archivo de configuracion'. Abortando."
                exit 1
            }
        }
    }

# -----------------------------------------------------
# REPORTE
# -----------------------------------------------------

$reportSub=Join-Path $reportDir ($mode.name + "_" + $mode.desc)

if(!(Test-Path $reportSub)){
New-Item $reportSub -ItemType Directory | Out-Null
}

$report="report\" + $mode.name + "_" + $mode.desc + "\" + $eaName + "_" + $mode.name + "_" + $mode.desc

# -----------------------------------------------------
# GENERAR INI
# -----------------------------------------------------

$iniDir = Split-Path $iniOutput -Parent
if(-not (Test-Path $iniDir)){
    Write-Host "No existe la carpeta para escribir el ini: $iniDir"
    exit 1
}

$ini=@()

# 1) secciones generadas primero (prevalecen)
$ini+="[Common]"
$ini+="Login=$($cred.credencial.cuenta)"
$ini+="Password=$($cred.credencial.password)"
$ini+="Server=$($cred.credencial.servidor)"
$ini+="KeepPrivate=$($config["KeepPrivate"])"
$ini+=""

$ini+="[Tester]"
$ini+="Expert=Ea_Studio\$eaName.ex5"
$ini+="ExpertParameters=$set"
$ini+="Symbol=$symbol"
$ini+="Period=$tf"
$ini+="Model=$model"
$ini+="Spread=$($config["Spread"])"
$ini+="UseDate=$($config["UseDate"])"
$ini+="FromDate=$fromDate"
$ini+="ToDate=$toDate"
$ini+="Report=$report"
$ini+="Deposit=$($config["Deposit"])"
$ini+="Currency=$($config["Currency"])"
$ini+="Leverage=$($config["Leverage"])"

# 2) agregar plantilla del modo al final, filtrando solo las claves que generamos
$templateIni = Join-Path $templatesDir ($mode.name + ".ini")
if(Test-Path $templateIni){
    $tplLines = Get-Content $templateIni
    $current=""
    $skipTesterKeys=@("Expert","ExpertParameters","Symbol","Period","Model","Spread","UseDate","FromDate","ToDate","Report","Deposit","Currency","Leverage")
    foreach($l in $tplLines){
        if($l -match '^\\s*\\[(.+?)\\]\\s*$'){
            $current=$matches[1]
        }
        if($current -eq "Common"){
            continue
        }
        if($current -eq "Tester"){
            if($l -match '^\s*([^=]+)\s*='){
                $k=$matches[1].Trim()
                if($skipTesterKeys -contains $k){
                    continue
                }
            }
        }
        $ini += $l
    }
}

$ini | Set-Content $iniOutput

# -----------------------------------------------------
# RESUMEN
# -----------------------------------------------------

Write-Host ""
Write-Host "CONFIG FINAL"
Write-Host "EA: $eaName"
Write-Host "Modo: $($mode.name)"
Write-Host "Symbol: $symbol"
Write-Host "TF: $tf"
Write-Host "Rango: $fromDate -> $toDate"
Write-Host "Reporte: $report"

# -----------------------------------------------------
# EJECUCION
# -----------------------------------------------------

$isAutoCargador = ($config["AutoCargador"] -eq "True" -and $mode.autoCargador)
$cargadorPath = Join-Path $root "Tools\script\C_Auto_Cargador_Fragmentado.py"
$pyExe = "python"
$venvPython = Join-Path $root ".venv\Scripts\python.exe"
if(Test-Path $venvPython){ $pyExe = $venvPython }

while($true){
    
    $currentPassId = "0000"

    if($isAutoCargador){
        Write-Host ""
        Write-Host ">>> [AUTO-CARGADOR] Buscando siguiente cartucho para $eaName..." -ForegroundColor Magenta
        & $pyExe $cargadorPath $eaName
        if($LASTEXITCODE -ne 0){
            Write-Host ">>> [AUTO-CARGADOR] No quedan más cartuchos en la recámara. Deteniendo bucle." -ForegroundColor Yellow
            break
        }
        
        # Extraer Pass ID de la 'nota' .txt en presets
        $note = Get-ChildItem -Path $presetsDir -Filter *.txt | Select-Object -First 1
        if($note){
            $currentPassId = $note.BaseName
            Write-Host ">>> [AUTO-CARGADOR] Cartucho ID $currentPassId detectado y listo." -ForegroundColor Green
        }
    }

    if($mode.fragmentation){
        
        Write-Host ""
        Write-Host ">>> ACTIVADA FRAGMENTACION TEMPORAL (Auditoria Anual)" -ForegroundColor Yellow
        
        # Extraer años del rango (ej. _10años -> 10)
        $yearsNum = 1
        if($range.name -match "(\d+)años") { $yearsNum = [int]$matches[1] }
        elseif($range.name -match "(\d+)año") { $yearsNum = [int]$matches[1] }

        $baseToDate = [datetime]::ParseExact($config["ToDate"],"yyyy.MM.dd",$null)

        for($i=0; $i -lt $yearsNum; $i++){
            
            $iterTo = $baseToDate.AddYears(-$i).ToString("yyyy.MM.dd")
            $iterFrom = $baseToDate.AddYears(-($i+1)).ToString("yyyy.MM.dd")
            
            $iterYear = $baseToDate.AddYears(-$i).Year
            $iterReport = $report + "_ANYO_" + $iterYear
            
            # Clonar INI con fechas e informe de la iteración
            $iterIni = $ini
            $iterIni = $iterIni | ForEach-Object {
                if($_ -match "^FromDate="){ "FromDate=$iterFrom" }
                elseif($_ -match "^ToDate="){ "ToDate=$iterTo" }
                elseif($_ -match "^Report="){ "Report=$iterReport" }
                else { $_ }
            }
            
            $iterIni | Set-Content $iniOutput -Encoding UTF8
            
            Write-Host ">>> DISPARANDO FRAGMENTO: $iterYear ($iterFrom -> $iterTo)" -ForegroundColor Cyan
            Start-Process -FilePath $terminal -ArgumentList @("/portable", "/config:$iniOutput") -Wait
            Write-Host ">>> FRAGMENTO $iterYear COMPLETADO." -ForegroundColor Green
        }

        if($mode.fullTime){
            Write-Host ""
            Write-Host ">>> DISPARANDO CORRIDA FULL-TIME ($fromDate -> $toDate)" -ForegroundColor Magenta
            
            $fullIni = $ini
            $fullIni = $fullIni | ForEach-Object {
                if($_ -match "^FromDate="){ "FromDate=$fromDate" }
                elseif($_ -match "^ToDate="){ "ToDate=$toDate" }
                elseif($_ -match "^Report="){ "Report=$report" }
                else { $_ }
            }
            $fullIni | Set-Content $iniOutput -Encoding UTF8
            Start-Process -FilePath $terminal -ArgumentList @("/portable", "/config:$iniOutput") -Wait
            Write-Host ">>> CORRIDA FULL-TIME COMPLETADA." -ForegroundColor Green
        }
    }
    else {
        # Ejecución Estándar (Bloque Único)
        $ini | Set-Content $iniOutput -Encoding UTF8
        Start-Process -FilePath $terminal -ArgumentList @("/portable", "/config:$iniOutput") -Wait
    }

    # --- NORMALIZACION POR CADA CARGA ---
    $globalAuto = $config["Autonormalizer"] -eq "True"

    if($globalAuto -and $mode.autoNormalizer){
        
        Write-Host ""
        Write-Host ">>> Iniciando Normalizador Automático..." -ForegroundColor Cyan
        
        $normalizerPath = Join-Path $root "Tools\script\A_Normalizador_Master.py"
        
        if(Test-Path $normalizerPath){
            if($isAutoCargador){
                & $pyExe $normalizerPath --ea $eaName --pass_id $currentPassId
            }
            else {
                & $pyExe $normalizerPath
            }
            Write-Host ">>> Normalización completada." -ForegroundColor Green
        }
    }

    # --- AUTO-FILTER GENÉTICO POST-FORWARD (Puente al Orquestador) ---
    $globalFilter = $config["AutoFilter_Genetico_Post_Forward"] -eq "True"
    if($globalFilter -and $mode.autoFilterPostFW){
        
        Write-Host ""
        Write-Host ">>> [AUTO-FILTER] Calculando tiempos para Orquestación..." -ForegroundColor Magenta
        
        # Extraer total de años del rango (el numerito de _6años)
        $totalY = 1
        if($range.name -match "(\d+)años") { $totalY = [int]$matches[1] }
        elseif($range.name -match "(\d+)año") { $totalY = [int]$matches[1] }

        # Cálculo: Forward = Total * (Num/Denom). Backtest = Total - Forward.
        $fwY = [math]::Truncate($totalY * ($mode.filterNumerator / $mode.filterDenominator))
        $btY = $totalY - $fwY

        Write-Host ">>> [AUTO-FILTER] Inyectando Orquestador Maestro (EA: $eaName | BT: $btY | FW: $fwY | TF: $tf)..." -ForegroundColor Cyan
        
        $masterOrchestrator = Join-Path $root "Tools\script\B_Master_Filter_Post_Forward.py"
        if(Test-Path $masterOrchestrator){
            & $pyExe $masterOrchestrator $eaName $btY $fwY $tf
            Write-Host ">>> [AUTO-FILTER] Orquestación completada." -ForegroundColor Green
        }
    }

    # --- AUTO-FILTER MODO FRAGMENTADO (El Juez) ---
    $globalFragFilter = $config["AutoFilter_MODO_FRAGMENTADO"] -eq "True"
    if($globalFragFilter -and $mode.fragmentation){
        
        Write-Host ""
        Write-Host ">>> [AUTO-FILTER-FRAG] Invocando al Juez Forense (Analista Fragmentado)..." -ForegroundColor Magenta
        
        $juezForense = Join-Path $root "Tools\script\D_Analista_Fragmentado.py"
        if(Test-Path $juezForense){
            & $pyExe $juezForense
            Write-Host ">>> [AUTO-FILTER-FRAG] Auditoría completada." -ForegroundColor Green
        }
    }

    # Si NO es modo autocargador, terminamos el bucle interno tras la primera vuelta
    if(-not $isAutoCargador){
        break
    }
} # Fin del while($true) interno (Munición)

# --- ¿CONTINUAR CON MODO DERIVADO (Eslabón)? ---
$globalDeriva = $config["MODOS_AUTOMATICOS_DERIBADOS"] -eq "True"
if($globalDeriva -and $mode.derivaPos){
    $nextPosNum = $mode.derivaPos
    Write-Host ""
    Write-Host ">>> [DERIVACION] Detectado modo encadenado: Posicion $nextPosNum" -ForegroundColor Magenta
    
    # Buscar el objeto de modo correspondiente a esa posición
    $nextMode = $modes | Where-Object { $_.pos -eq [int]$nextPosNum }
    
    if($nextMode){
        $sess_mode = $nextMode
        
        # Reseteamos el rango para que tome el del nuevo modo (o el primero por defecto)
        $sess_range = $null 
        
        # ¿Tiene un rango objetivo sugerido? (ej. {posicion5:_12años})
        if($mode.derivaRange){
            $target = $mode.derivaRange
            if($sess_mode.ranges -contains $target){
                $sess_range = [PSCustomObject]@{
                    name=$target
                    days=$config[$target]
                }
                Write-Host ">>> [DERIVACION] Aplicando Rango Objetivo: $target" -ForegroundColor Cyan
            }
        }

        # Fallback: Si no hay sugerencia o no existe el rango objetivo, tomamos el primero
        if($null -eq $sess_range -and $sess_mode.ranges.Count -gt 0){
            $firstRangeTag = $sess_mode.ranges[0]
            $sess_range = [PSCustomObject]@{
                name=$firstRangeTag
                days=$config[$firstRangeTag]
            }
            Write-Host ">>> [DERIVACION] Inyectando Rango automatico (Primer slot): $firstRangeTag" -ForegroundColor Cyan
        }

        Write-Host ">>> [DERIVACION] Reiniciando ciclo con el nuevo eslabon..." -ForegroundColor Green
        continue # Reinicia el while($true) maestro
    }
    else {
        Write-Host "[ERROR] No se encontro la posicion $nextPosNum para la derivacion." -ForegroundColor Red
    }
}

# Si llega aqui es porque no hay mas derivaciones, salimos del bucle maestro
break 
} # Fin del while($true) maestro



