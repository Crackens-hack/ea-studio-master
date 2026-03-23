# Instalador simplificado y blindado: selecciona disposición (.env), crea instancia, instala MT5 en silencio,
# valida credenciales automáticamente y marca la disposición como usada solo si valida.

param([string]$InstallerPath)

$expectedRoot   = Split-Path -Parent $PSScriptRoot
$instanciasRoot = Join-Path $expectedRoot '00_setup/Instancias'
$installerDir   = Join-Path $expectedRoot '00_setup/bin'

function Assert-Location {
    $here = (Get-Location).ProviderPath
    if ($here -ne $expectedRoot) {
        Write-Host "TIP: Ejecutá desde $expectedRoot (terminal integrada VS Code/Cursor/Antigravity)." -ForegroundColor Yellow
        exit 1
    }
}

function Get-NextInstanceName {
    $dirs = Get-ChildItem -Path $instanciasRoot -Directory -ErrorAction SilentlyContinue
    $nums = @()
    foreach($d in $dirs){ if($d.Name -match '^instancia_(\d+)$'){ $nums += [int]$matches[1] } }
    if(-not $nums){ return 'instancia_01' }
    $next = ([int]($nums | Measure-Object -Maximum).Maximum) + 1
    return ('instancia_{0:D2}' -f $next)
}

function Get-EnvDispositions {
    $envPath = Join-Path $expectedRoot '.env'
    if (-not (Test-Path $envPath)) { return @() }
    $blocks = [regex]::Split((Get-Content $envPath -Raw), "(\r?\n){2,}")
    $items = @()
    foreach($blk in $blocks){
        if([string]::IsNullOrWhiteSpace($blk)){ continue }
        $obj = @{Disposicion=$null;Cuenta=$null;Servidor=$null;Pass=$null;Descripcion=$null;Usable=$false}
        foreach($line in ($blk -split '\r?\n')){
            if($line -match '^\s*DISPOSICION___\s*=\s*(.+)$'){ $obj.Disposicion = $matches[1].Trim() }
            elseif($line -match '^\s*CUENTA\s*=\s*(.*)$'){ $obj.Cuenta = $matches[1].Trim() }
            elseif($line -match '^\s*SERVIDOR\s*=\s*(.*)$'){ $obj.Servidor = $matches[1].Trim() }
            elseif($line -match '^\s*PASS_NOINDEX\s*=\s*(.*)$'){ $obj.Pass = $matches[1] }
            elseif($line -match '^\s*DESCRIPCION\s*=\s*(.*)$'){ $obj.Descripcion = $matches[1] }
            elseif($line -match '^\s*USABLE\s*=\s*(.+)$'){ $obj.Usable = $matches[1].Trim() -match '^(?i:true|1|yes|y)$' }
        }
        $items += [pscustomobject]$obj
    }
    return $items
}

function Set-EnvDisposUsable($disposicion, $usable){
    $envPath = Join-Path $expectedRoot '.env'
    if (-not (Test-Path $envPath)) { return }
    $blocks = [regex]::Split((Get-Content $envPath -Raw), "(\r?\n){2,}")
    $new = @()
    foreach($blk in $blocks){
        if([string]::IsNullOrWhiteSpace($blk)){ continue }
        if($blk -match '(?m)^\s*DISPOSICION___\s*=\s*'+[regex]::Escape($disposicion)+'\s*$'){
            $lines = $blk -split '\r?\n'
            $found=$false
            $flag = if($usable){ "True" } else { "False" }
            $lines = $lines | ForEach-Object {
                if($_ -match '^\s*USABLE\s*='){ $found=$true; "USABLE="+$flag }
                else { $_ }
            }
            if(-not $found){ $lines += ("USABLE="+$flag) }
            $new += ($lines -join "`n")
        } else { $new += $blk }
    }
    Set-Content -Path $envPath -Value ($new -join "`n`n") -Encoding ASCII
}

function Choose-Installer {
    param($cli)
    if ($cli -and (Test-Path $cli)) { return $cli }
    if (-not (Test-Path $installerDir)){
        Write-Host "No hay instaladores en $installerDir" -ForegroundColor Red
        return $null
    }
    $exeList = Get-ChildItem -Path $installerDir -Filter '*.exe' -File | Sort-Object Name
    if(-not $exeList){ Write-Host "No se encontraron instaladores." -ForegroundColor Red; return $null }
    Write-Host "Instaladores encontrados:" -ForegroundColor Cyan
    $i=1; foreach($f in $exeList){ $mark = if($f.Name -ieq 'mt5setup.exe'){'(recomendado)'}else{''}; Write-Host ("[{0}] {1} {2}" -f $i,$f.Name,$mark); $i++ }
    $sel = Read-Host "Elegí número de instalador (ENTER cancela)"
    if([string]::IsNullOrWhiteSpace($sel)){ return $null }
    if(-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $exeList.Count){ Write-Host "Selección inválida." -ForegroundColor Red; return $null }
    return $exeList[[int]$sel-1].FullName
}

function Silent-InstallMT($installerPath,$instalacionDir){
    Write-Host "Instalando MT5 en modo silencioso hacia: $instalacionDir" -ForegroundColor Yellow
    foreach($d in @($instalacionDir)){ if(-not (Test-Path $d)){ New-Item -ItemType Directory -Path $d -Force | Out-Null } }
    $args = @("/auto","/path:`"$instalacionDir`"")
    $p = Start-Process -FilePath $installerPath -ArgumentList $args -WindowStyle Hidden -Wait -PassThru
    Write-Host ("Instalador finalizado con código {0}" -f $p.ExitCode) -ForegroundColor DarkGray
    $terminal = Get-ChildItem -Path $instalacionDir -Filter 'terminal*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if(-not $terminal){ throw "terminal*.exe no encontrado en $instalacionDir" }
    Set-Content -Path (Join-Path $instalacionDir 'installer_used.txt') -Value (Split-Path $installerPath -Leaf) -Encoding ASCII
    return $terminal
}

function Validate-And-Mark($instalacionDir,$credObj,$disp){
    $credPath = Join-Path $instalacionDir 'credenciales.json'
    $credObj | ConvertTo-Json | Set-Content -Path $credPath -Encoding UTF8
    $terminal = Get-ChildItem -Path $instalacionDir -Filter 'terminal*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if(-not $terminal){ throw "terminal*.exe no encontrado para validar" }
    Write-Host "`nLanzando MT en modo portable para validar..." -ForegroundColor Cyan
    Write-Host ("Cuenta: {0}" -f $credObj.cuenta)
    Write-Host ("Servidor: {0}" -f $credObj.servidor)
    Start-Process -FilePath $terminal.FullName -ArgumentList '/portable' -WorkingDirectory $instalacionDir | Out-Null

    Start-Sleep -Seconds 3 # dar tiempo a que arranque y cree archivos
    $logsDirs = @(
        (Join-Path $instalacionDir 'logs'),
        (Join-Path $instalacionDir 'Logs'),
        (Join-Path $instalacionDir 'Tester/Logs'),
        (Join-Path $instalacionDir 'MQL5/Logs')
    )
    $commonPath   = Join-Path $instalacionDir 'Config/common.ini'
    $terminalIni  = Join-Path $instalacionDir 'Config/terminal.ini'
    $deadline = (Get-Date).AddMinutes(5)
    $validated=$false;$failed=$false;$detalle=$null;$commonOk=$false
    while((Get-Date) -lt $deadline -and -not ($validated -or $failed)){
        $logFile=$null
        foreach($ld in $logsDirs){
            if(Test-Path $ld){
                $cand = Get-ChildItem -Path $ld -Filter '*.log' -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -ne 'metaeditor.log' } |
                        Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if($cand){ $logFile=$cand; break }
            }
        }
        if($logFile){
            try{ $lines = Get-Content -Path $logFile.FullName -Tail 300 -ErrorAction SilentlyContinue } catch { $lines=@() }
            foreach($ln in $lines){
                if($ln -match "(?i)authorized on"){ $validated=$true; $detalle=$ln.Trim(); break }
                if($ln -match "(?i)authorization on .*failed"){ $failed=$true; $detalle=$ln.Trim(); break }
                if($ln -match "(?i)failed \\(Invalid account\\)"){ $failed=$true; $detalle=$ln.Trim(); break }
                if($ln -match "(?i)invalid account"){ $failed=$true; $detalle=$ln.Trim(); break }
                if($ln -match "(?i)invalid password"){ $failed=$true; $detalle=$ln.Trim(); break }
            }
        }
        if(-not $commonOk){
            try{
                foreach($cfg in @($commonPath,$terminalIni)){
                    if(-not (Test-Path $cfg)){ continue }
                    $cl = Get-Content -Path $cfg -ErrorAction SilentlyContinue
                    $loginLine = $cl | Where-Object { $_ -match '^Login=' }
                    $serverLine = $cl | Where-Object { $_ -match '^Server=' }
                    if($loginLine -and $serverLine){
                        $loginVal = ($loginLine -split '=',2)[1]
                        $serverVal = ($serverLine -split '=',2)[1]
                        if($loginVal -eq $credObj.cuenta -and $serverVal -eq $credObj.servidor){ $commonOk=$true }
                    }
                }
            } catch {}
        }
        Start-Sleep -Seconds 2
    }

    if($validated -or $commonOk){
        $credObj.validada=$true
        $credObj.fecha_validacion=(Get-Date).ToString('s')
        $credObj.detalle_validacion=$detalle
        Set-EnvDisposUsable $disp.Disposicion $false
        Write-Host "Credencial validada (log autorizado o config coincide)." -ForegroundColor Green
        # crear estructura mínima post-validación
        foreach($d in @('MQL5','MQL5/Experts','MQL5/Experts/Ea_Studio','report','MQL5/Profiles/Tester','MQL5/Presets','Tester')){
            $path = Join-Path $instalacionDir $d
            if(-not (Test-Path $path)){ New-Item -ItemType Directory -Path $path -Force | Out-Null }
        }
    } else {
        $credObj.validada=$false
        $credObj.fecha_validacion=(Get-Date).ToString('s')
        if($detalle){ $credObj.detalle_validacion=$detalle } else { $credObj.detalle_validacion="pendiente" }
        Write-Host "Validación falló o pendiente ($($credObj.detalle_validacion)). Ejecutando desinstalador oficial de la instancia..." -ForegroundColor Red
        $uninstallExe = Join-Path $instalacionDir 'uninstall.exe'
        if(Test-Path $uninstallExe){
            try {
                $p = Start-Process -FilePath $uninstallExe -ArgumentList '/S' -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
                Write-Host ("Uninstall exit code: {0}" -f $p.ExitCode) -ForegroundColor DarkGray
            } catch {
                Write-Host "Uninstall /S falló, intentando sin argumentos..." -ForegroundColor Yellow
                try { Start-Process -FilePath $uninstallExe -Wait -PassThru | Out-Null } catch {}
            }
        }
        try { Remove-Item -Path $instalacionDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
    if(Test-Path $instalacionDir){
        $credObj | ConvertTo-Json | Set-Content -Path $credPath -Encoding UTF8
        Write-Host "Estado guardado en $credPath" -ForegroundColor DarkGray
    }
}

# --- Ejecución principal ---
Assert-Location

$disps = Get-EnvDispositions | Where-Object { $_.Usable -eq $true }
if(-not $disps){
    Write-Host "No hay disposiciones USABLE=True en .env. No se puede instalar." -ForegroundColor Red
    exit 1
}

Write-Host "`nInstancias detectadas en 00_setup/Instancias:`n" -ForegroundColor Cyan
$instances = Get-ChildItem -Path $instanciasRoot -Directory -ErrorAction SilentlyContinue
foreach($inst in $instances){
    $credPath = Join-Path $inst.FullName 'credenciales.json'
    $validStr = '-'
    if(Test-Path $credPath){
        try{
            $c=Get-Content $credPath -Raw|ConvertFrom-Json
            if($c.validada -eq $true){ $validStr='Sí' }
            elseif($c.validada -eq $false){ $validStr='No' }
            else { $validStr='Pendiente' }
        }catch{}
    }
    $installerMarker = Join-Path $inst.FullName 'installer_used.txt'
    $instUsed = if(Test-Path $installerMarker){ Get-Content $installerMarker -First 1 } else { '(?)' }
    Write-Host ("{0} -> installer={1} cred={2}" -f $inst.Name,$instUsed,$validStr)
}

# Opción de saneamiento automático de instancias fallidas (cred=No)
$failed = @()
foreach($inst in $instances){
    $credPath = Join-Path $inst.FullName 'credenciales.json'
    if(Test-Path $credPath){
        try{
            $c = Get-Content $credPath -Raw | ConvertFrom-Json
            if($c.validada -eq $false){
                $failed += $inst
            }
        } catch {}
    }
}
if($failed.Count -gt 0){
    Write-Host "`nInstancias con credenciales NO validadas detectadas: $($failed.Name -join ', ')" -ForegroundColor Yellow
    $ans = Read-Host "¿Sanear ahora (desinstalar y borrar carpeta)? (s/n, ENTER = no)"
    if($ans -match '^[sS]'){
        foreach($inst in $failed){
            $instalacionDir = $inst.FullName
            $uninstallExe = Join-Path $instalacionDir 'uninstall.exe'
            Write-Host ("Saneando {0}..." -f $inst.Name) -ForegroundColor Cyan
            if(Test-Path $uninstallExe){
                try { Start-Process -FilePath $uninstallExe -ArgumentList '/S' -WindowStyle Hidden -Wait | Out-Null } catch {}
            }
            if(Test-Path $inst.FullName){
                try { Remove-Item -Path $inst.FullName -Recurse -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
        # refrescar lista
        $instances = Get-ChildItem -Path $instanciasRoot -Directory -ErrorAction SilentlyContinue
    }
}

Write-Host "`n=== Crear nueva instancia portable (flujo guiado) ===" -ForegroundColor Cyan
$dispObj = $null
Write-Host "`nDisposiciones disponibles (.env) USABLE=True:" -ForegroundColor Cyan
$i=1; foreach($d in $disps){ Write-Host ("[{0}] {1} -> {2}" -f $i,$d.Disposicion,$d.Descripcion); $i++ }
$sel = Read-Host ("Elegí número de disposición (ENTER usa 1, Q cancela)")
if([string]::IsNullOrWhiteSpace($sel)){ $sel = "1" }
if($sel -match '^[qQ]$'){ exit 0 }
if(-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $disps.Count){
    Write-Host "Selección inválida." -ForegroundColor Red
    exit 1
}
$dispObj = $disps[[int]$sel-1]

$instName = Read-Host ("Nombre para la nueva instancia (ENTER usa {0}, Q para salir)" -f (Get-NextInstanceName))
if([string]::IsNullOrWhiteSpace($instName)){ $instName = Get-NextInstanceName }
if($instName -match '^[qQ]$'){ exit 0 }

$installerPath = Choose-Installer -cli $InstallerPath
if(-not $installerPath){ exit 1 }

$instalacionDir = Join-Path $instanciasRoot $instName
if(Test-Path $instalacionDir){ Write-Host "La instancia ya existe: $instalacionDir" -ForegroundColor Red; exit 1 }
New-Item -ItemType Directory -Path $instalacionDir -Force | Out-Null

try {
    $terminal = Silent-InstallMT -installerPath $installerPath -instalacionDir $instalacionDir
    $credObj = [pscustomobject]@{
        cuenta=$dispObj.Cuenta; password=$dispObj.Pass; servidor=$dispObj.Servidor;
        fecha_guardado=(Get-Date).ToString('s'); validada=$false; fecha_validacion=$null; detalle_validacion=$null
    }
    Validate-And-Mark -instalacionDir $instalacionDir -credObj $credObj -disp $dispObj
} catch {
    Write-Host "Error durante la instalación/validación: $_" -ForegroundColor Red
    try { Remove-Item -Path $instalacionDir -Recurse -Force -ErrorAction Stop } catch {}
}
