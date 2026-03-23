# Desinstala una instancia MT en 00_setup/Instancias sin tocar otras.
# Limpia hub y credencial_en_uso si la instancia era la activa.
# Rehabilita la disposición en .env (USABLE=True) basada en CUENTA/SERVIDOR de la instancia.

$expectedRoot   = Split-Path -Parent $PSScriptRoot
$instanciasRoot = Join-Path $expectedRoot '00_setup/Instancias'
$credFile       = Join-Path $instanciasRoot 'credencial_en_uso.json'
$resultadosRoot = Join-Path $expectedRoot 'RESULTADOS'
$linkReportes   = Join-Path $resultadosRoot 'Reportes-SinProcesar'

function Set-EnvDisposUsable($cuenta,$servidor){
    $envPath = Join-Path $expectedRoot '.env'
    if(-not (Test-Path $envPath)){ return }
    $blocks = [regex]::Split((Get-Content $envPath -Raw), "(\r?\n){2,}")
    $new=@(); $changed=$false
    foreach($blk in $blocks){
        if([string]::IsNullOrWhiteSpace($blk)){ continue }
        $lines = $blk -split '\r?\n'
        $cu=$null;$sv=$null
        foreach($ln in $lines){
            if($ln -match '^\s*CUENTA\s*=\s*(.*)$'){ $cu=$matches[1].Trim() }
            elseif($ln -match '^\s*SERVIDOR\s*=\s*(.*)$'){ $sv=$matches[1].Trim() }
        }
        if($cu -eq $cuenta -and $sv -eq $servidor){
            $lines = $lines | ForEach-Object { if($_ -match '^\s*USABLE\s*='){ "USABLE=True" } else { $_ } }
            if(-not ($lines -match '^\s*USABLE\s*=')){ $lines += "USABLE=True" }
            $new += ($lines -join "`n"); $changed=$true
        } else { $new += $blk }
    }
    if($changed){ Set-Content -Path $envPath -Value ($new -join "`n`n") -Encoding ASCII }
}

function Assert-Location {
    $here = (Get-Location).ProviderPath
    if ($here -ne $expectedRoot) {
        Write-Host "TIP: Ejecuta desde $expectedRoot" -ForegroundColor Gray
    }
}

Assert-Location

if (-not (Test-Path $instanciasRoot)) {
    Write-Host "No existe 00_setup/Instancias. Nada que desinstalar." -ForegroundColor Yellow
    exit 0
}

$instDirs = Get-ChildItem -Path $instanciasRoot -Directory -ErrorAction SilentlyContinue
if (-not $instDirs) {
    Write-Host "No hay carpetas de instancia en $instanciasRoot." -ForegroundColor Yellow
    exit 0
}

Write-Host ("Instancias encontradas en {0}:`n" -f $instanciasRoot) -ForegroundColor Cyan
$i=1; foreach($d in $instDirs){ Write-Host ("[{0}] {1}" -f $i, $d.Name) ; $i++ }
$sel = Read-Host "Elegí número de instancia a desinstalar"
if(-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $instDirs.Count){
    Write-Host "Selección inválida." -ForegroundColor Red
    exit 1
}

$chosen = $instDirs[[int]$sel - 1]
Write-Host "Vas a desinstalar: $($chosen.FullName)" -ForegroundColor Yellow
$confirm = Read-Host "Escribe el nombre exacto de la carpeta para confirmar (o ENTER para cancelar)"
if($confirm -ne $chosen.Name){
    Write-Host "Confirmación incorrecta. Abortando." -ForegroundColor Red
    exit 1
}

# cargar credencial de la instancia para marcar disposición y detectar activa
$credJson = $null
$credPathInst = Join-Path $chosen.FullName 'credenciales.json'
if(Test-Path $credPathInst){ try{ $credJson = Get-Content $credPathInst -Raw | ConvertFrom-Json } catch {} }

$isActiveInstance = $false
if(Test-Path $credFile){
    try{
        $activeJson = Get-Content $credFile -Raw | ConvertFrom-Json
        $activePath = $activeJson.ruta_instancia
        if($activePath -and [string]::Equals($activePath.TrimEnd('\'), $chosen.FullName.TrimEnd('\'), [System.StringComparison]::InvariantCultureIgnoreCase)){
            $isActiveInstance = $true
        }
    } catch {}
}

# Ejecutar uninstaller si existe
$uninstaller = Get-ChildItem -Path $chosen.FullName -Recurse -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match 'unins.*\.exe$' -or $_.Name -match 'uninstall.*\.exe$' } |
               Select-Object -First 1
if($uninstaller){
    Write-Host "Ejecutando desinstalador: $($uninstaller.FullName)" -ForegroundColor Cyan
    try { Start-Process -FilePath $uninstaller.FullName -ArgumentList '/S' -Wait -ErrorAction Stop } catch { Write-Host "Desinstalador falló: $($_)" -ForegroundColor Yellow }
}

# eliminar carpeta (si ya no existe, no es error)
if(Test-Path $chosen.FullName){
    try { Remove-Item -Path $chosen.FullName -Recurse -Force -ErrorAction Stop; Write-Host "Instancia eliminada: $($chosen.FullName)" -ForegroundColor Green }
    catch { Write-Host "No se pudo eliminar la carpeta: $($_)" -ForegroundColor Yellow }
} else {
    Write-Host "La carpeta ya no existe tras el uninstall (OK)." -ForegroundColor Gray
}

# marcar disposición como usable de nuevo
if($credJson){
    Set-EnvDisposUsable -cuenta $credJson.cuenta -servidor $credJson.servidor
}

# limpiar hub de la instancia
$hubPath = Join-Path $expectedRoot (".000_{0}_hub_000" -f $chosen.Name)
if(Test-Path $hubPath){ try { Remove-Item -Path $hubPath -Recurse -Force -ErrorAction Stop } catch {} }

# si era la activa, limpiar credencial_en_uso y enlace de reportes
if($isActiveInstance){
    if(Test-Path $credFile){ try{ Remove-Item $credFile -Force -ErrorAction SilentlyContinue } catch {} }
    if(Test-Path $linkReportes){ try{ Remove-Item $linkReportes -Force -Recurse -ErrorAction SilentlyContinue } catch {} }
}

Write-Host "Desinstalación finalizada." -ForegroundColor Green
