# Recompila EAs en BUILD/1_BUILDING/02_ea_mejorar usando la instancia activa.
# Usa el mismo flujo y carpeta de logs que 01_Compilador.ps1.

$ErrorActionPreference = 'Stop'

$repoRoot   = $PSScriptRoot
$credPath   = Join-Path $repoRoot '00_setup/Instancias/credencial_en_uso.json'
$sourceDir  = Join-Path $repoRoot 'BUILD/1_BUILDING/02_ea_mejorar'
$archiveBase = Join-Path $repoRoot 'BUILD/1_BUILDING/04_ARCHIVADOS'
$logDir     = Join-Path $repoRoot '00_setup/resources/Compiler'

if (-not (Test-Path $credPath)) { throw "No existe $credPath. Ejecutá .\\00_Jefe-Activa.ps1 para seleccionar instancia activa." }
$cred = Get-Content $credPath -Raw | ConvertFrom-Json
if (-not $cred.metaeditor_exe) { throw "El JSON activo no tiene metaeditor_exe. Reejecutá .\\00_setup\\Instalador.ps1." }
if (-not (Test-Path $cred.metaeditor_exe)) { throw "No se encontró MetaEditor en: $($cred.metaeditor_exe)" }
if (-not $cred.ruta_instancia) { throw "El JSON activo no tiene ruta_instancia. Reejecutá .\\00_setup\\Instalador.ps1." }
$eaStudioDir = Join-Path $cred.ruta_instancia 'MQL5/Experts/Ea_Studio'
if (-not (Test-Path $eaStudioDir)) { New-Item -ItemType Directory -Path $eaStudioDir -Force | Out-Null }
$metaLogSrc  = Join-Path $cred.ruta_instancia 'Logs/metaeditor.log'

if (-not (Test-Path $sourceDir)) { throw "No existe el directorio fuente: $sourceDir" }
$files = @()
$files += Get-ChildItem -Path $sourceDir -File -Filter '*.mq5'  -ErrorAction SilentlyContinue
$files += Get-ChildItem -Path $sourceDir -File -Filter '*.mql5' -ErrorAction SilentlyContinue
if (-not $files) { Write-Host "No hay archivos .mq5/.mql5 en $sourceDir" -ForegroundColor Yellow; exit 0 }

# Si hay más de un EA, conservar solo el más reciente y archivar los demás.
if ($files.Count -gt 1) {
    if (-not (Test-Path $archiveBase)) { New-Item -ItemType Directory -Path $archiveBase -Force | Out-Null }
    $latest      = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $latestBase  = $latest.BaseName
    $keep        = $files | Where-Object { $_.BaseName -eq $latestBase }
    $archive     = $files | Where-Object { $_.BaseName -ne $latestBase }

    foreach ($f in $archive) {
        # Crear subfolder con el nombre del EA dentro de 04_ARCHIVADOS
        $eaArchiveDir = Join-Path $archiveBase $f.BaseName
        if (-not (Test-Path $eaArchiveDir)) { New-Item -ItemType Directory -Path $eaArchiveDir -Force | Out-Null }
        
        $dest = Join-Path $eaArchiveDir $f.Name
        Move-Item -Path $f.FullName -Destination $dest -Force
        $ex5 = Join-Path $sourceDir ($f.BaseName + '.ex5')
        if (Test-Path $ex5) { Move-Item -Path $ex5 -Destination (Join-Path $eaArchiveDir ([IO.Path]::GetFileName($ex5))) -Force }
        $theory = Join-Path $sourceDir ($f.BaseName + '_teoria.md')
        if (Test-Path $theory) {
            $theoryDest = Join-Path $eaArchiveDir ([IO.Path]::GetFileName($theory))
            Move-Item -Path $theory -Destination $theoryDest -Force
        }
    }
    $files = $keep
    $keepList = ($keep | Select-Object -ExpandProperty Name -Unique) -join ', '
    Write-Host ("Se archivaron {0} EA(s) antiguos en subcarpetas de {1}. Se recompila solo: {2}" -f $archive.Count, $archiveBase, $keepList) -ForegroundColor DarkYellow
}

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
Get-ChildItem -Path $logDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
if (Test-Path $metaLogSrc) { Remove-Item $metaLogSrc -Force -ErrorAction SilentlyContinue }
foreach ($f in $files) {
    $logFile = Join-Path $logDir ("{0}.log" -f $f.BaseName)
    if (Test-Path $logFile) { Remove-Item $logFile -Force }

    Write-Host ("Compilando {0} ..." -f $f.Name) -ForegroundColor Cyan
    $args = @(
        '/portable'
        ("/compile:`"{0}`"" -f $f.FullName)
        ("/log:`"{0}`"" -f $logFile)
    )
    $proc = Start-Process -FilePath $cred.metaeditor_exe -ArgumentList $args -NoNewWindow -Wait -PassThru

    $status = 'sin log'
    $fg     = 'Yellow'
    if (Test-Path $logFile) {
        $status = 'OK'
        $fg     = 'Green'
        $resultLine = Select-String -Path $logFile -Pattern '^Result:\s+(\d+)\s+errors?,\s+(\d+)\s+warnings?' | Select-Object -First 1
        if ($resultLine) {
            $errCount  = [int]$resultLine.Matches[0].Groups[1].Value
            $warnCount = [int]$resultLine.Matches[0].Groups[2].Value
            if ($errCount -gt 0) { $status = "con errores ($errCount)"; $fg = 'Red' }
            elseif ($warnCount -gt 0) { $status = "con warnings ($warnCount)"; $fg = 'Yellow' }
        } else {
            $status = 'log sin línea Result'
            $fg     = 'Yellow'
        }
    }
    Write-Host ("Resultado {0}: {1}" -f $status, $logFile) -ForegroundColor $fg

    $ex5Source = [IO.Path]::ChangeExtension($f.FullName, '.ex5')
    if (Test-Path $ex5Source) {
        $dest = Join-Path $eaStudioDir ([IO.Path]::GetFileName($ex5Source))
        Copy-Item -Path $ex5Source -Destination $dest -Force
        Write-Host ("Binario copiado a {0}" -f $dest) -ForegroundColor DarkCyan
    } else {
        Write-Host "No se encontró binario .ex5 para copiar (¿falló la compilación?)." -ForegroundColor Yellow
    }
}

if (Test-Path $metaLogSrc) {
    $metaLogDest = Join-Path $logDir 'metaeditor.log'
    Copy-Item -Path $metaLogSrc -Destination $metaLogDest -Force
    Write-Host ("metaeditor.log guardado en {0}" -f $metaLogDest) -ForegroundColor DarkGray
}

Write-Host "Terminó la recompilación. Revisá los logs en $logDir" -ForegroundColor Green
