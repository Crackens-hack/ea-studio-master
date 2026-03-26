"""
B_Master_Filter_Post_Forward.py
==============================
Orquestador Maestro del Pipeline de Trading (Protocolo Fénix).
Coordina el Filtrado (A), Cruce (B), Clustering (C) y Rescate (D) en un solo flujo.
"""

import os
import subprocess
import sys

# ==============================================================================
# CONFIGURACIÓN DE RUTAS
# ==============================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR   = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
PYTHON_EXE = sys.executable 
MODE_FOLDER  = 'genetica70_fw30_OPTIMIZACION_GENETICA_FW'
INPUT_BASE   = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados', MODE_FOLDER)

# Scripts en orden de ejecución
SCRIPT_A = os.path.join(SCRIPT_DIR, 'Pipe-Post-Forward', 'A_Filtrador_Post_Forward.py')
SCRIPT_B = os.path.join(SCRIPT_DIR, 'Pipe-Post-Forward', 'B_Cruce_Filter.py')
SCRIPT_C = os.path.join(SCRIPT_DIR, 'Pipe-Post-Forward', 'C_Clustering_Elite.py')
SCRIPT_D = os.path.join(SCRIPT_DIR, 'Pipe-Post-Forward', 'D_Rescate_Forward.py')

def list_ea_folders():
    if not os.path.isdir(INPUT_BASE):
        print(f"[ERROR] No existe la carpeta: {INPUT_BASE}")
        sys.exit(1)
    folders = [f for f in os.listdir(INPUT_BASE) if os.path.isdir(os.path.join(INPUT_BASE, f))]
    return folders

def choose_ea(folders):
    if not folders:
        print("[ERROR] No se encontraron carpetas de EA en Reportes-Normalizados.")
        sys.exit(1)
    if len(folders) == 1: 
        return folders[0]
    print("\nEAs disponibles para procesar:")
    for i, f in enumerate(folders, 1):
        print(f"  [{i}] {f}")
    sel = input("Elegí EA (número): ").strip()
    try:
        return folders[int(sel) - 1]
    except:
        print("[ERROR] Selección inválida.")
        sys.exit(1)

def run_step(command_list, step_name):
    print(f"\n" + "="*68)
    print(f"🚀 EJECUTANDO: {step_name}")
    print("="*68)
    try:
        subprocess.run(command_list, check=True)
    except subprocess.CalledProcessError:
        print(f"\n[ERROR] El paso '{step_name}' falló. Deteniendo el pipeline.")
        sys.exit(1)

def main():
    print("=" * 68)
    print("👑 ORQUESTADOR MAESTRO - PROTOCOLO FÉNIX 👑")
    print("=" * 68)

    # --- MODO HÍBRIDO: Detección de Argumentos CLI ---
    if len(sys.argv) >= 5:
        # Modo Inyectado (Automatizado)
        ea_name   = sys.argv[1]
        bt_years  = sys.argv[2]
        fw_years  = sys.argv[3]
        timeframe = sys.argv[4].upper()
        
        # Validación rápida de existencia de carpeta
        ea_path = os.path.join(INPUT_BASE, ea_name)
        if not os.path.isdir(ea_path):
            print(f"\n[ERROR CLI] No existe la carpeta del EA en Reportes-Normalizados: {ea_name}")
            sys.exit(1)
            
        print(f"\n📡 MODO SELECCIONADO: INYECCIÓN EXTERNA (CLI)")
        print(f"   EA Detectado: {ea_name}")
        print(f"   Filtro BT   : {bt_years} años")
        print(f"   Filtro FW   : {fw_years} años")
        print(f"   Timeframe   : {timeframe}")
    else:
        # Modo Humano (Interactivo)
        ea_folders = list_ea_folders()
        ea_name = choose_ea(ea_folders)

        print("\n📝 CONFIGURACIÓN DE TIEMPOS Y FILTROS:")
        bt_years  = input("   Años de Backtest/Genético (ej: 4): ").strip()
        fw_years  = input("   Años de Forward (ej: 2): ").strip()
        timeframe = input("   Timeframe (M15, H1, H4, D1): ").strip().upper()

    print("\n" + "🏁" * 34)
    print("📦 INICIANDO PIPELINE AUTOMATIZADO...")
    print("🏁" * 34)

    # PASO A: Filtrador (Quirúrgico con argumentos)
    run_step([PYTHON_EXE, SCRIPT_A, ea_name, bt_years, fw_years, timeframe], "A - FILTRADOR POST-FORWARD")

    # PASO B: Cruce de ADN (Autónomo)
    run_step([PYTHON_EXE, SCRIPT_B], "B - CRUCE DE ADN")

    # PASO C: Clustering Elite (Autónomo)
    run_step([PYTHON_EXE, SCRIPT_C], "C - CLUSTERING ELITE")

    # PASO D: Rescate Forward (Quirúrgico si hay fragilidad)
    run_step([PYTHON_EXE, SCRIPT_D, ea_name, timeframe], "D - ESCUADRÓN DE RESCATE")

    print("\n" + "=" * 68)
    print("🏆 PIPELINE FINALIZADO CON ÉXITO")
    print(f"   EA: {ea_name}")
    print(f"   Status: Consultar carpetas 1_CLUSTERS_ELITE y RESCATE_CLUSTER")
    print("=" * 68)

if __name__ == '__main__':
    main()
