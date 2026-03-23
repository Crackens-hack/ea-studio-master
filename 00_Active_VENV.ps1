# -----------------------------------------------------
# SCRIPT: 00_Active_VENV.ps1
# PROPÓSITO: Activación rápida del entorno virtual Python
# USO: Arrastrar a la terminal de VS Code y presionar Enter
# -----------------------------------------------------

Write-Host ">>> ACTIVANDO ENTORNO VIRTUAL (.VENV) <<<" -ForegroundColor Cyan

$venvScript = Join-Path $PSScriptRoot ".venv\Scripts\Activate.ps1"

if (Test-Path $venvScript) {
    # Ejecutamos con dot-sourcing para que la activación persista en la terminal actual
    . $venvScript
    Write-Host "[OK] Python VENV activado. Ya podés ejecutar herramientas de Metrics & DuckDB." -ForegroundColor Green
} else {
    Write-Host "[ERROR] No se encontró la carpeta .venv o el script de activación." -ForegroundColor Red
    Write-Host "Asegurate de haber instalado las dependencias primero." -ForegroundColor Yellow
}
