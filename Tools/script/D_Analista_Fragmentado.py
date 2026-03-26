import os
import sys
import pandas as pd
import configparser
import argparse

# ==============================================================================
# CONFIGURACIÓN DE RUTAS
# ==============================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR   = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
CONF_FILE  = os.path.join(SCRIPT_DIR, 'Config-Filters', 'criterios-analisis-fragmentado.conf')
MODE_NAME  = 'single_mode_fragmentado_VALIDACION_STRESS_ANUALIZADO'
NORMALIZED = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados', MODE_NAME)

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
    """Limpia cabeceras en español y simbolos raros para estandar de ingenieria."""
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

def main():
    parser = argparse.ArgumentParser(description="Juez Forense - Analista Fragmentado")
    parser.add_argument("--ea", required=True, help="Nombre del EA")
    parser.add_argument("--pass_id", required=True, help="ID del Pass a auditar")
    args = parser.parse_args()

    ea_name = args.ea
    pass_id = args.pass_id

    # Construir ruta al resumen
    pass_folder_name = f"{ea_name}___discrecional"
    pass_dir = os.path.join(NORMALIZED, pass_folder_name, str(pass_id))
    resumen_path = os.path.join(pass_dir, '1_RESUMEN', 'resumen-fragmentacion.csv')

    log_path = os.path.join(pass_dir, "resumen-auditacion-jueza.txt")
    veredicto = "No"
    razon_final = ""

    print(f"\n👨‍⚖️  AUDITORÍA DIRIGIDA: {ea_name} (Pass {pass_id})")
    print("-" * 40)

    if not os.path.exists(resumen_path):
        razon_final = f"No se encontro el archivo resumen-fragmentacion.csv en {resumen_path}"
    else:
        try:
            df = pd.read_csv(resumen_path)
            df = normalize_cols(df)
            filters = load_filters()

            if df.empty:
                razon_final = "El archivo de resumen esta vacio."
            else:
                ft = df.iloc[0]
                fragments = df.iloc[1:]

                profit_total = clean_val(ft.get('beneficio_neto', 0.0))
                pf_total     = clean_val(ft.get('factor_de_beneficio', 0.0))
                dd_total     = clean_val(ft.get('dd_equidad_maximo', 0.0))

                # --- Auditoria Full Time ---
                if profit_total < filters['ft_min_profit']:
                    razon_final = f"Falla Full-Time: Profit Negativo (${profit_total:.2f})"
                elif pf_total < filters['ft_min_pf']:
                    razon_final = f"Falla Full-Time: PF Bajo ({pf_total:.2f})"
                elif dd_total > filters['ft_max_dd']:
                    razon_final = f"Falla Full-Time: DD Excesivo ({dd_total:.2f}%)"
                else:
                    fail_frag = False
                    for i, row in fragments.iterrows():
                        y_profit = clean_val(row.get('beneficio_neto', 0.0))
                        y_dd     = clean_val(row.get('dd_equidad_maximo', 0.0))
                        periodo  = row.get('periodo', f'Fragmento_{i}')

                        if y_profit < -abs(filters['max_y_loss']):
                            razon_final = f"Falla Consistencia: Ruina en {periodo} (${y_profit:.2f})"
                            fail_frag = True
                            break
                        if y_dd > filters['max_y_dd']:
                            razon_final = f"Falla Consistencia: DD de Quiebra en {periodo} ({y_dd:.2f}%)"
                            fail_frag = True
                            break
                    
                    if not fail_frag:
                        veredicto = "Yes"
                        razon_final = "Set consistente y rentable en todos los periodos analizados. Supervivencia Elite Confirmada."

        except Exception as e:
            razon_final = f"Error durante el analisis: {str(e)}"

    # ======================================================================
    # FINALIZACIÓN Y VEREDICTO
    # ======================================================================
    print(f"VEREDICTO: {veredicto}")
    print(f"MOTIVO: {razon_final}")

    # Escribir el acta de sentencia
    with open(log_path, 'w', encoding='utf-8') as f:
        f.write(f"ea={ea_name}\n")
        f.write(f"pass={pass_id}\n")
        f.write(f"seleccionado={veredicto}\n")
        f.write(f"resumenn={razon_final}\n")

    print("-" * 40)

if __name__ == '__main__':
    main()
