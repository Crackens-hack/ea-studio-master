"""
D_Auto_Cargador.py (SELECTOR DE MUNICIÓN - PROTOCOLO FÉNIX)
==========================================================
1. Recibe 'ea_name' por argumento.
2. Prioridad 1: BUSCAR EN RESCATE_CLUSTER/CARGADOR.
3. Prioridad 2: BUSCAR EN 1_CLUSTERS_ELITE/CARGADOR.
4. Identifica el primer cartucho (CARTUCHO_XX_PXXXX) sin 'carga_realizada.txt'.
5. Limpia carpetas de presets y carga el .set.
6. Firma el cartucho como 'CARGADO'.
7. El M-Tester puede llamar a este script en bucle para testear TODO.
"""

import os
import sys
import shutil
import glob

# ==============================================================================
# RUTAS BASE
# ==============================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR   = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
MODE_NAME  = 'genetica70_fw30_OPTIMIZACION_GENETICA_FW'
ANALIZADOS = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Analizados', MODE_NAME)

# Destinos Master (Los Seters del M-Tester)
PRESETS_DIR = os.path.join(ROOT_DIR, 'BUILD', '0_SETERS', 'PRESETS')
PROFILE_DIR = os.path.join(ROOT_DIR, 'BUILD', '0_SETERS', 'PROFILE_TESTER')

def limpiar_seters():
    """Borra todos los archivos .set y .txt en las carpetas de carga del M-Tester."""
    for d in [PRESETS_DIR, PROFILE_DIR]:
        if not os.path.exists(d): 
            os.makedirs(d, exist_ok=True)
            continue
        # Borrar .set y .txt para evitar fantasmas de ejecuciones previas
        for ext in ["*.set", "*.txt"]:
            files = glob.glob(os.path.join(d, ext))
            for f in files:
                try: os.remove(f)
                except: pass

def cargar_bala(source_set_path, ea_name, pass_id):
    """Copia la bala al cargador master y deja la nota del Pass."""
    limpiar_seters()
    
    # Destinos para el .set
    dest_presets = os.path.join(PRESETS_DIR, f"{ea_name}.set")
    dest_profile = os.path.join(PROFILE_DIR, f"{ea_name}.set")
    
    shutil.copy2(source_set_path, dest_presets)
    shutil.copy2(source_set_path, dest_profile)
    
    # Crear la "Nota" del Pass (ej: 3242.txt)
    with open(os.path.join(PRESETS_DIR, f"{pass_id}.txt"), "w") as f:
        f.write(str(pass_id))
    with open(os.path.join(PROFILE_DIR, f"{pass_id}.txt"), "w") as f:
        f.write(str(pass_id))
        
    print(f"   🔋 BALA CARGADA: {ea_name}.set (PASS: {pass_id})")
    print(f"      -> Note: {pass_id}.txt created in Seters.")

def buscar_y_cargar(ea_name):
    print("=" * 68)
    print(f"🔋  C_Auto_Cargador_Fragmentado  |  EA: {ea_name}")
    print("=" * 68)

    ea_base_dir = os.path.join(ANALIZADOS, ea_name)
    if not os.path.isdir(ea_base_dir):
        print(f"[ERROR] No existe la carpeta del EA analizado: {ea_base_dir}")
        sys.exit(1)

    # 1. Definir rutas de búsqueda por prioridad (RESCATE primero)
    rutas_cargadores = [
        os.path.join(ea_base_dir, "RESCATE_CLUSTER", "CARGADOR"),
        os.path.join(ea_base_dir, "1_CLUSTERS_ELITE", "CARGADOR")
    ]

    for c_dir in rutas_cargadores:
        if not os.path.isdir(c_dir): continue
        
        print(f"🔍 Escaneando Cargador: {os.path.basename(os.path.dirname(c_dir))}")
        
        # Obtener cartuchos ordenados alfanuméricamente
        cartuchos = sorted([d for d in os.listdir(c_dir) if os.path.isdir(os.path.join(c_dir, d))])
        
        for cart in cartuchos:
            cart_path = os.path.join(c_dir, cart)
            # ¿Ya fue disparado?
            if os.path.exists(os.path.join(cart_path, "carga_realizada.txt")):
                continue
            
            # 🎯 EXTRAER PASS ID (De CARTUCHO_XX_PXXXX)
            import re
            match_pass = re.search(r"_P(\d+)", cart)
            pass_id = match_pass.group(1) if match_pass else "0000"

            # ENCONTRAMOS EL SIGUIENTE CARTUCHO DISPONIBLE
            set_files = glob.glob(os.path.join(cart_path, "*.set"))
            if not set_files:
                print(f"   [WARN] El cartucho {cart} está vacío. Saltando.")
                continue
                
            source_set = set_files[0] 
            print(f"   🎯 Cartucho Seleccionado: {cart} (ID: {pass_id})")
            
            # --- ACCION DE CARGA ---
            cargar_bala(source_set, ea_name, pass_id)
            
            # --- FIRMA DE CARGA (En la carpeta del cartucho) ---
            with open(os.path.join(cart_path, "carga_realizada.txt"), "w") as f:
                f.write("CARGADO")
            
            print(f"   ✅ Cartucho {cart} marcado como DISPARADO en repositorio.")
            print("=" * 68)
            return True 

    print("⚠️  No hay cartuchos disponibles para cargar (todos disparados o ausentes).")
    print("=" * 68)
    return False

    print("⚠️  No hay cartuchos disponibles para cargar (todos disparados o ausentes).")
    print("=" * 68)
    return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("[ERROR] Uso: python D_Auto_Cargador.py <EA_NAME>")
        sys.exit(1)
        
    ea_target = sys.argv[1]
    exito = buscar_y_cargar(ea_target)
    
    if exito:
        sys.exit(0) # Se cargó una bala con éxito
    else:
        sys.exit(1) # No quedan balas en la recámara
