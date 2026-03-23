# Selecciona la instancia activa y genera credencial_en_uso.json.
# Además crea el hub .000_<instancia>_hub_000 con enlaces útiles.

param()

$expectedRoot   = $PSScriptRoot
$instanciasRoot = Join-Path $expectedRoot '00_setup/Instancias'
$outPath        = Join-Path $instanciasRoot 'credencial_en_uso.json'
$resultadosRoot = Join-Path $expectedRoot 'BUILD/RESULTADOS'
$buildSeters    = Join-Path $expectedRoot 'BUILD/0_SETERS'
$compilerLogs   = Join-Path $expectedRoot '00_setup/resources/Compiler'
$activePath     = Join-Path $instanciasRoot 'credencial_en_uso.json'

function New-LinkForce {
    param($Path, $Target)
    if (Test-Path $Path) { Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue }
    try { New-Item -ItemType SymbolicLink -Path $Path -Target $Target -ErrorAction Stop | Out-Null }
    catch { New-Item -ItemType Junction -Path $Path -Target $Target -ErrorAction SilentlyContinue | Out-Null }
}

function Load-Cred($instPath){
    $credPath = Join-Path $instPath 'credenciales.json'
    if(-not (Test-Path $credPath)){ return $null }
    try { return Get-Content $credPath -Raw | ConvertFrom-Json } catch { return $null }
}

function Collect-Instances {
    $dirs = Get-ChildItem -Path $instanciasRoot -Directory -ErrorAction SilentlyContinue
    $items = @()
    foreach($d in $dirs){
        $cred = Load-Cred $d.FullName
        $valid = ($cred -and $cred.validada -eq $true)
        $term = Get-ChildItem -Path $d.FullName -Filter 'terminal*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        $meta = Get-ChildItem -Path $d.FullName -Filter 'metaeditor*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        $items += [pscustomobject]@{
            Nombre   = $d.Name
            Ruta     = $d.FullName
            Cred     = $cred
            Valida   = $valid
            Terminal = $term
            Meta     = $meta
        }
    }
    return $items
}

function Build-Hub {
    param($instName,$instPath)
    if(-not $instName -or -not $instPath){ return }

    # limpiar hubs previos
    Get-ChildItem -Path $expectedRoot -Filter ".000_*_hub_000" -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    $hubPath = Join-Path $expectedRoot (".000_{0}_hub_000" -f $instName)
    New-Item -ItemType Directory -Path $hubPath -Force | Out-Null

    $setersRoot = Join-Path $hubPath '0_SETERS'
    if (-not (Test-Path $setersRoot)) { New-Item -ItemType Directory -Path $setersRoot -Force | Out-Null }

    # Enlace adicional en BUILD/0_SETERS apuntando a los mismos targets
    if (-not (Test-Path $buildSeters)) { New-Item -ItemType Directory -Path $buildSeters -Force | Out-Null }

    $credPath    = Join-Path $instPath 'credenciales.json'
    $mqlDir      = Join-Path $instPath 'MQL5'
    $testerDir   = Join-Path $instPath 'Tester'
    if (-not (Test-Path $testerDir)) { New-Item -ItemType Directory -Path $testerDir -Force | Out-Null }

    $links = @(
        @{ name='credencial.json';                target=$credPath },
        @{ name='Asesores_Expertos(En Terminal)'; target=Join-Path $mqlDir 'Experts/Ea_Studio' },
        @{ name='PRESETS';                        target=Join-Path $mqlDir 'Presets'; rootLink=$true },
        @{ name='PROFILE_TESTER';                 target=Join-Path $mqlDir 'Profiles/Tester'; rootLink=$true },
        @{ name='LOGS_Terminal';                  target=Join-Path $mqlDir 'Logs' },
        @{ name='LOGS_Editor';                    target=Join-Path $instPath 'Logs' },
        @{ name='LOGS_TESTER';                    target=$testerDir }
    )
    foreach($l in $links){
        $basePath = if($l.rootLink){ $setersRoot } else { $hubPath }
        $p = Join-Path $basePath $l.name
        New-LinkForce -Path $p -Target $l.target
        if($l.rootLink){
            $p2 = Join-Path $buildSeters $l.name
            New-LinkForce -Path $p2 -Target $l.target
        }
    }

    # RESULTADOS links/carpetas
    foreach($d in @('Reportes-Analizados','Reportes-Normalizados')){
        $full = Join-Path $resultadosRoot $d
        if(-not (Test-Path $full)){ New-Item -ItemType Directory -Path $full -Force | Out-Null }
    }
    $linkReportes = Join-Path $resultadosRoot 'Reportes-SinProcesar'
    if (Test-Path $linkReportes) { Remove-Item -Path $linkReportes -Force -Recurse -ErrorAction SilentlyContinue }
    New-LinkForce -Path $linkReportes -Target (Join-Path $instPath 'report')
}

# --- Ejecución principal ---
$instancesAll = Collect-Instances | Where-Object { $_.Valida -eq $true }
if(-not $instancesAll){
    Write-Host "No hay instancias con credenciales validadas. Primero valida con Instalador.ps1." -ForegroundColor Yellow
    exit 1
}

$activeName = $null
if(Test-Path $activePath){
    try{
        $act = Get-Content $activePath -Raw | ConvertFrom-Json
        $activeName = $act.instancia
        if($activeName){
            Write-Host ("Instancia actualmente activa: {0} (cuenta {1}, servidor {2})" -f $activeName,$act.credencial.cuenta,$act.credencial.servidor) -ForegroundColor DarkCyan
        }
    }catch{}
}

$instances = $instancesAll
if($activeName){
    $instances = $instancesAll | Where-Object { $_.Nombre -ne $activeName }
}

if(-not $instances){
    Write-Host "Ya estás usando la única instancia validada disponible: $activeName. No hay otras para seleccionar." -ForegroundColor Yellow
    exit 0
}

# Si solo queda una opción, seleccionarla automáticamente
if($instances.Count -eq 1){
    $chosen = $instances[0]
    Write-Host ("Seleccion automática: {0} (cuenta {1}, servidor {2})" -f $chosen.Nombre,$chosen.Cred.cuenta,$chosen.Cred.servidor) -ForegroundColor Cyan
} else {
    Write-Host "`nInstancias con credenciales validadas (excluida la activa):" -ForegroundColor Cyan
    $i=1
    foreach($it in $instances){
        $cuenta = if($it.Cred){ $it.Cred.cuenta } else { '(sin cuenta)' }
        $srv    = if($it.Cred){ $it.Cred.servidor } else { '(sin servidor)' }
        Write-Host ("[{0}] {1} -> cuenta {2}, servidor {3}" -f $i, $it.Nombre, $cuenta, $srv)
        $i++
    }
    $selRaw = Read-Host "Elige numero de instancia activa (ENTER cancela)"
    $selTrim = $selRaw.Trim()
    if([string]::IsNullOrWhiteSpace($selTrim)){ exit 0 }
    $selInt = 0
    if(-not [int]::TryParse($selTrim, [ref]$selInt)){
        Write-Host "Seleccion invalida." -ForegroundColor Red
        exit 1
    }
    if($selInt -lt 1 -or $selInt -gt $instances.Count){
        Write-Host "Seleccion invalida." -ForegroundColor Red
        exit 1
    }
    $chosen = $instances[$selInt-1]
}

$instalacionDir = $chosen.Ruta
$mqlDir         = Join-Path $instalacionDir 'MQL5'
$expertsDir     = Join-Path $mqlDir 'Experts'
$eaStudioDir    = Join-Path $expertsDir 'Ea_Studio'
$presetsDir     = Join-Path $mqlDir 'Presets'
$profilesTester = Join-Path $mqlDir 'Profiles/Tester'
$reportsDir     = Join-Path $instalacionDir 'report'
$logsTerminal   = Join-Path $mqlDir 'Logs'
$logsEditor     = Join-Path $instalacionDir 'Logs'
$logsTester     = Join-Path $instalacionDir 'Tester/Logs'
$agentsRoot     = Join-Path $instalacionDir 'Tester'

$outObj = [pscustomobject]@{
    instancia      = $chosen.Nombre
    ruta_instancia = $instalacionDir
    credencial     = $chosen.Cred
    terminal_exe   = if($chosen.Terminal){ $chosen.Terminal.FullName } else { $null }
    metaeditor_exe = if($chosen.Meta){ $chosen.Meta.FullName } else { $null }
    rutas = [pscustomobject]@{
        instalacion     = $instalacionDir
        mql5            = $mqlDir
        experts         = $expertsDir
        ea_studio       = $eaStudioDir
        presets         = $presetsDir
        profiles_tester = $profilesTester
        reports         = $reportsDir
        logs_terminal   = $logsTerminal
        logs_editor     = $logsEditor
        logs_tester     = $logsTester
        tester_agents   = $agentsRoot
    }
    fecha_seleccion = (Get-Date).ToString('s')
}

$outObj | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Credencial activa guardada en $outPath" -ForegroundColor Green

Build-Hub -instName $chosen.Nombre -instPath $instalacionDir
Write-Host "Hub actualizado en .000_<inst>_hub_000 y enlaces creados." -ForegroundColor Green
# Limpiar logs de compilacion para no mezclar instancias
if (Test-Path $compilerLogs) {
    Get-ChildItem -Path $compilerLogs -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "Logs de compilacion limpiados en $compilerLogs" -ForegroundColor DarkGray
}

