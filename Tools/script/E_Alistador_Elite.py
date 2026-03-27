"""
E_Alistador_Elite.py - PROTOCOLO FÉNIX
=======================================
Consolida todos los sentencia-juez.csv del Portafolio de un EA
en un único archivo 'Escuadron-Elite.csv' suelto en la raíz del EA.

Uso:
    python E_Alistador_Elite.py <EA_NAME>
"""

import os
import sys
import csv
import glob
from datetime import datetime

# ==============================================================================
# RUTAS BASE
# ==============================================================================
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR     = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
PORTAFOLIO   = os.path.join(ROOT_DIR, 'BUILD', '1_BUILDING', '03_PORTAFOLIO')
OUTPUT_NAME  = 'Escuadron-Elite.csv'

def main():
    if len(sys.argv) < 2:
        print("[ERROR] Uso: python E_Alistador_Elite.py <EA_NAME>")
        sys.exit(1)

    ea_name = sys.argv[1]
    ea_dir  = os.path.join(PORTAFOLIO, ea_name)

    print("=" * 60)
    print(f"🏆  E_Alistador_Elite  |  EA: {ea_name}")
    print("=" * 60)

    if not os.path.isdir(ea_dir):
        print(f"[ERROR] No se encontró la carpeta del EA: {ea_dir}")
        sys.exit(1)

    # Buscar todas las carpetas PASS_*
    pass_folders = sorted([
        d for d in os.listdir(ea_dir)
        if os.path.isdir(os.path.join(ea_dir, d)) and d.startswith("PASS")
    ])

    if not pass_folders:
        print("[WARN] No se encontraron carpetas PASS_* en el Portafolio.")
        sys.exit(0)

    print(f"📂 Escaneando {len(pass_folders)} cartuchos Élite...")

    all_rows    = []
    header      = None
    found_count = 0

    for folder in pass_folders:
        csv_path = os.path.join(ea_dir, folder, 'sentencia-juez.csv')

        if not os.path.exists(csv_path):
            print(f"   ⚠️  Sin sentencia en {folder}. Saltando.")
            continue

        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.reader(f, delimiter=';')
            rows   = list(reader)

        if len(rows) < 2:
            print(f"   ⚠️  Sentencia vacía en {folder}. Saltando.")
            continue

        # Cabecera solo del primero
        if header is None:
            header = rows[0]

        all_rows.append(rows[1])  # Solo la fila de datos
        found_count += 1
        print(f"   ✅ {folder} → cargado")

    if not all_rows:
        print("[ERROR] No se pudo consolidar ningún cartucho.")
        sys.exit(1)

    # Escribir el Escuadrón
    output_path = os.path.join(ea_dir, OUTPUT_NAME)

    with open(output_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f, delimiter=';')
        writer.writerow(header)
        for row in all_rows:
            writer.writerow(row)

    print("")
    print(f"🚀 Escuadrón consolidado: {found_count} Élites")
    print(f"📄 Guardado en: {output_path}")

    # --- FASE 2: Organizar PASS_* dentro de PASS-SETS ---
    pass_sets_dir = os.path.join(ea_dir, "PASS-SETS")
    os.makedirs(pass_sets_dir, exist_ok=True)
    moved = 0

    for folder in pass_folders:
        src = os.path.join(ea_dir, folder)
        dst = os.path.join(pass_sets_dir, folder)
        if os.path.isdir(src):
            import shutil
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.move(src, dst)
            moved += 1

    print(f"📦 {moved} carpetas PASS_* organizadas en PASS-SETS/")
    print("=" * 60)

if __name__ == '__main__':
    main()
