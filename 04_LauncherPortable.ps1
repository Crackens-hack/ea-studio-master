# Lanza la instancia activa (según credencial_en_uso.json) en modo portable.

$expectedRoot   = $PSScriptRoot
$instanciasRoot = Join-Path $expectedRoot '00_setup/Instancias'
$activePath     = Join-Path $instanciasRoot 'credencial_en_uso.json'

if(-not (Test-Path $activePath)){
    Write-Host "No existe credencial_en_uso.json. Ejecutá CAPITAN-Change.ps1 primero." -ForegroundColor Yellow
    exit 1
}

try { $active = Get-Content $activePath -Raw | ConvertFrom-Json } catch { Write-Host "No se pudo leer credencial_en_uso.json"; exit 1 }
$instDir = $active.ruta_instancia
$terminal = $active.terminal_exe
if(-not $terminal -or -not (Test-Path $terminal)){
    $terminal = Get-ChildItem -Path $instDir -Filter 'terminal*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if($terminal){ $terminal = $terminal.FullName }
}
if(-not $terminal -or -not (Test-Path $terminal)){
    Write-Host "No se encontró terminal*.exe en la instancia activa." -ForegroundColor Red
    exit 1
}

Write-Host ("Lanzando {0} en /portable" -f $terminal) -ForegroundColor Cyan
Start-Process -FilePath $terminal -ArgumentList '/portable' -WorkingDirectory $instDir
