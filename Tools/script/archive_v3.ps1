$dir = "BUILD\1_BUILDING\03_PORTAFOLIO\Apex_S_Cycles_V3"
New-Item -ItemType Directory -Force -Path $dir
Move-Item -Path "BUILD\1_BUILDING\01_ea_construccion\Apex_S_Cycles_V3.mq5" -Destination $dir -Force -ErrorAction SilentlyContinue
Move-Item -Path "BUILD\1_BUILDING\01_ea_construccion\Apex_S_Cycles_V3_teoria.md" -Destination $dir -Force -ErrorAction SilentlyContinue
Copy-Item -Path "00_setup\Instancias\roboforex-demo-5k\MQL5\Experts\Ea_Studio\Apex_S_Cycles_V3.ex5" -Destination $dir -Force -ErrorAction SilentlyContinue
Copy-Item -Path "BUILD\1_BUILDING\05_METRICAS_ELITES\Apex_S_Cycles_V3\*.set" -Destination $dir -Force -ErrorAction SilentlyContinue
Write-Host "PORTAFOLIO ARCHIVADO."
