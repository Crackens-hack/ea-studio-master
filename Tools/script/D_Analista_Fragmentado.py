import os
import sys
import shutil
import pandas as pd
import configparser
import argparse
from datetime import datetime

# ==============================================================================
# CONFIGURACIÓN DE RUTAS
# ==============================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR   = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
CONF_FILE  = os.path.join(SCRIPT_DIR, 'Config-Filters', 'criterios-analisis-fragmentado.conf')
MODE_NAME  = 'single_mode_fragmentado_VALIDACION_STRESS_ANUALIZADO'
NORMALIZED = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados', MODE_NAME)
ANALIZADOS = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Analizados')
CONSTRUCCION = os.path.join(ROOT_DIR, 'BUILD', '1_BUILDING', '01_ea_construccion')
PORTAFOLIO   = os.path.join(ROOT_DIR, 'BUILD', '1_BUILDING', '03_PORTAFOLIO')

def load_filters() -> dict:
    cfg = configparser.ConfigParser()
    cfg.read(CONF_FILE, encoding='utf-8')
    if 'FILTROS_DUROS' not in cfg:
        return {'ft_min_profit': 0.0, 'ft_min_pf': 1.1, 'ft_max_dd': 15.0, 'max_y_loss': 150.0, 'max_y_dd': 20.0}
    
    return {
        'ft_min_profit': float(cfg['FILTROS_DUROS'].get('full_time_min_profit', 0.0)),
        'ft_min_pf': float(cfg['FILTROS_DUROS'].get('full_time_min_pf', 1.1)),
        'ft_max_dd': float(cfg['FILTROS_DUROS'].get('full_time_max_dd_pct', 15.0)),
        'max_y_loss': float(cfg['CONSISTENCIA'].get('max_yearly_loss_usd', 150.0)),
        'max_y_dd': float(cfg['CONSISTENCIA'].get('max_yearly_dd_pct', 20.0)),
    }

def normalize_cols(df):
    new_cols = []
    for c in df.columns:
        clean = c.lower().strip()
        clean = clean.replace('á', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o').replace('ú', 'u')
        clean = clean.replace(' ', '_').replace('%', '').replace('(', '').replace(')', '').replace(',', '').replace('$', '')
        clean = clean.replace('__', '_').rstrip('_')
        new_cols.append(clean)
    df.columns = new_cols
    return df

def clean_val(val):
    if pd.isna(val): return 0.0
    if isinstance(val, str):
        val = val.replace('%', '').replace('$', '').replace(',', '').replace(' ', '').strip()
    try: return float(val)
    except: return 0.0

def find_cartucho_folder(ea_name, pass_id):
    """Localiza la carpeta del cartucho original en los reportes analizados."""
    opt_mode = 'genetica70_fw30_OPTIMIZACION_GENETICA_FW'
    search_root = os.path.join(ANALIZADOS, opt_mode, ea_name, '1_CLUSTERS_ELITE', 'CARGADOR')
    if os.path.exists(search_root):
        for folder in os.listdir(search_root):
            if f"P{pass_id}" in folder:
                return os.path.join(search_root, folder)
    return None

def main():
    parser = argparse.ArgumentParser(description="Juez Forense - Analista Fragmentado")
    parser.add_argument("--ea", required=True, help="Nombre del EA")
    parser.add_argument("--pass_id", required=True, help="ID del Pass a auditar")
    args = parser.parse_args()

    ea_name = args.ea
    pass_id = str(args.pass_id)

    # Construir ruta al resumen
    pass_folder_name = f"{ea_name}___discrecional"
    pass_dir = os.path.join(NORMALIZED, pass_folder_name, pass_id)
    resumen_path = os.path.join(pass_dir, '1_RESUMEN', 'resumen-fragmentacion.csv')

    log_path = os.path.join(pass_dir, "resumen-auditacion-jueza.txt")
    veredicto = "No"
    razon_final = ""

    print(f"\n👨‍⚖️  AUDITORÍA DE ÉLITE: {ea_name} (Pass {pass_id})")
    print("-" * 40)

    if not os.path.exists(resumen_path):
        razon_final = f"Error: No existe el resumen consolidado."
    else:
        try:
            df = pd.read_csv(resumen_path)
            df = normalize_cols(df)
            filters = load_filters()

            if df.empty:
                razon_final = "Error: El CSV esta vacio."
            else:
                ft = df.iloc[0]
                fragments = df.iloc[1:]

                profit_total = clean_val(ft.get('beneficio_neto', 0.0))
                pf_total     = clean_val(ft.get('factor_de_beneficio', 0.0))
                dd_total     = clean_val(ft.get('dd_equidad_maximo', 0.0))

                # --- Auditoria Sangrienta ---
                if profit_total < filters['ft_min_profit']:
                    razon_final = f"Rechazado: Profit FT Negativo ({profit_total:.2f})"
                elif pf_total < filters['ft_min_pf']:
                    razon_final = f"Rechazado: PF FT Bajo ({pf_total:.2f})"
                elif dd_total > filters['ft_max_dd']:
                    razon_final = f"Rechazado: DD FT Excesivo ({dd_total:.2f}%)"
                else:
                    fail_frag = False
                    for i, row in fragments.iterrows():
                        y_profit = clean_val(row.get('beneficio_neto', 0.0))
                        y_dd     = clean_val(row.get('dd_equidad_maximo', 0.0))
                        periodo  = row.get('periodo', 'N/A')

                        if y_profit < -abs(filters['max_y_loss']) or y_dd > filters['max_y_dd']:
                            razon_final = f"Rechazado: Ruina/DD en fragmento {periodo}"
                            fail_frag = True
                            break
                    
                    if not fail_frag:
                        veredicto = "Yes"
                        razon_final = "SUPERVIVENCIA ÉLITE CONFIRMADA."

        except Exception as e:
            razon_final = f"Error Analisis: {str(e)}"

    # Finalizar Veredicto en Texto
    with open(log_path, 'w', encoding='utf-8') as f:
        f.write(f"ea={ea_name}\npass={pass_id}\nseleccionado={veredicto}\nresumenn={razon_final}\n")

    print(f"VEREDICTO: {veredicto}")
    print(f"MOTIVO: {razon_final}")

    # ======================================================================
    # PROMOCIÓN AL PORTAFOLIO 🏆 (Solo si el veredicto es Yes)
    # ======================================================================
    if veredicto == "Yes":
        ea_portfolio_dir = os.path.join(PORTAFOLIO, ea_name)
        os.makedirs(ea_portfolio_dir, exist_ok=True)
        
        # 1. Extraer Cartucho Completo (Renombrando a PASS_ELITE_XXXX)
        dest_pass_dir = os.path.join(ea_portfolio_dir, f"PASS_ELITE_{pass_id}")
        source_cartucho = find_cartucho_folder(ea_name, pass_id)
        
        if source_cartucho and os.path.exists(source_cartucho):
            if os.path.exists(dest_pass_dir): shutil.rmtree(dest_pass_dir)
            shutil.copytree(source_cartucho, dest_pass_dir)
            
            # Copiar también el resumen-fragmentacion.csv y el acta del Juez dentro de la carpeta Elite
            shutil.copy2(resumen_path, os.path.join(dest_pass_dir, "resumen-fragmentacion-verificado.csv"))
            shutil.copy2(log_path, os.path.join(dest_pass_dir, "sentencia-juez.txt"))
            
            print(f"   🚀 Cartucho extraído y promovido a PASS_ELITE_{pass_id}")
        else:
            print(f"   ⚠️  Advertencia: No se encontró el cartucho original en CARGADOR.")

        # 2. Salvaguarda de ADN (Archivos base de construcción)
        # Copia todos los archivos que coincidan con el nombre del EA desde construcción
        if os.path.exists(CONSTRUCCION):
            for file in os.listdir(CONSTRUCCION):
                if file.startswith(ea_name):
                    src_file = os.path.join(CONSTRUCCION, file)
                    dest_file = os.path.join(ea_portfolio_dir, file)
                    shutil.copy2(src_file, dest_file)
            print(f"   🧬 ADN Base sincronizado en la raíz del Portafolio.")

    print("-" * 40)

if __name__ == '__main__':
    main()
