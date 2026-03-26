"""
E_Analista_Fragmentado.py (EL JUEZ DEL ISLARIO)
==============================================
1. Escanea Reportes-Normalizados (modo fragmentado).
2. Lee el 'resumen-fragmentacion.csv' de cada EA.
3. Al encontrar el FULL-TIME en el primer renglón, evalúa al líder.
4. Evalúa la consistencia de los años debajo.
5. Emite un veredicto ELITE o RECHAZADO según el .conf.
"""

import os
import sys
import pandas as pd
import configparser
from pathlib import Path

# ==============================================================================
# RUTAS BASE
# ==============================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR   = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
CONF_FILE  = os.path.join(SCRIPT_DIR, 'Config-Filters', 'criterios-analisis-fragmentado.conf')
MODE_NAME  = 'single_mode_fragmentado_VALIDACION_STRESS_ANUALIZADO'
NORMALIZED = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados', MODE_NAME)

# ==============================================================================
# HELPERS
# ==============================================================================
def load_filters() -> dict:
    cfg = configparser.ConfigParser()
    cfg.read(CONF_FILE, encoding='utf-8')
    return {
        'ft_min_profit': float(cfg['FILTROS_DUROS'].get('full_time_min_profit', 0.0)),
        'ft_min_pf': float(cfg['FILTROS_DUROS'].get('full_time_min_pf', 1.1)),
        'ft_max_dd': float(cfg['FILTROS_DUROS'].get('full_time_max_dd_pct', 15.0)),
        'min_consistency': float(cfg['CONSISTENCIA'].get('min_consistency_ratio', 0.66)),
        'max_y_loss': float(cfg['CONSISTENCIA'].get('max_yearly_loss_usd', 150.0)),
        'max_y_dd': float(cfg['CONSISTENCIA'].get('max_yearly_dd_pct', 20.0)),
    }

def normalize_cols(df):
    df.columns = [c.lower().strip() for c in df.columns]
    return df

def clean_val(val):
    if pd.isna(val): return 0.0
    if isinstance(val, str):
        val = val.replace('%', '').replace('$', '').replace(',', '').strip()
    try: return float(val)
    except: return 0.0

# ==============================================================================
# MAIN
# ==============================================================================
def main():
    print("=" * 68)
    print("👨‍⚖️  E_Analista_Fragmentado  |  EL JUEZ DEL PROTOCOLO FÉNIX")
    print("=" * 68)

    if not os.path.isdir(NORMALIZED):
        print(f"[ERROR] No existe la carpeta de reportes fragmentados: {NORMALIZED}")
        return

    filters = load_filters()
    ea_folders = [f for f in os.listdir(NORMALIZED) if os.path.isdir(os.path.join(NORMALIZED, f))]

    if not ea_folders:
        print("[INFO] No se encontraron carpetas de EA.")
        return

    elites = []
    
    for ea_name in ea_folders:
        resumen_path = os.path.join(NORMALIZED, ea_name, '1_RESUMEN', 'resumen-fragmentacion.csv')
        if not os.path.exists(resumen_path):
            continue

        print(f"\n🔍 Auditando {ea_name}...")
        df = normalize_cols(pd.read_csv(resumen_path))
        if df.empty: continue

        # 1. El Jefe (FULL-TIME) está en la primera fila (index 0)
        ft = df.iloc[0]
        # 2. Los Años (Fragmentos) están debajo
        fragments = df.iloc[1:].copy()

        # Extraer métricas clave (buscando por nombres descriptivos usados en el normalizador)
        profit_total = clean_val(ft.get('beneficio neto', 0.0))
        pf_total = clean_val(ft.get('factor de beneficio', 0.0))
        dd_total = clean_val(ft.get('dd equidad máximo (%)', 0.0))

        fail_ft = False
        if profit_total < filters['ft_min_profit']: fail_ft = "PROFIT NEGATIVO"
        elif pf_total < filters['ft_min_pf']: fail_ft = "BAJO PF TOTAL"
        elif dd_total > filters['ft_max_dd']: fail_ft = "DD TOTAL EXCESIVO"

        if fail_ft:
            print(f"   💀 RECHAZADO FULL-TIME: {fail_ft} (Profit: {profit_total:.2f}, PF: {pf_total:.2f}, DD: {dd_total:.2f}%)")
            continue

        # 3. Auditoría de Años (Consistencia)
        total_yrs = len(fragments)
        green_yrs = 0
        fail_y = False

        for i, row in fragments.iterrows():
            y_profit = clean_val(row.get('beneficio neto', 0.0))
            y_dd = clean_val(row.get('dd equidad máximo (%)', 0.0))
            
            if y_profit > 0: green_yrs += 1
            
            # Chequeo de Filtros de Ruina
            if y_profit < -abs(filters['max_y_loss']):
                fail_y = f"PERDIDA EXTREMA EN {row.get('periodo', 'AÑO')}"
                break
            if y_dd > filters['max_y_dd']:
                fail_y = f"DD EXTREMO EN {row.get('periodo', 'AÑO')}"
                break

        if fail_y:
            print(f"   💀 RECHAZADO POR FRAGMENTO: {fail_y}")
            continue

        consistency = green_yrs / total_yrs if total_yrs > 0 else 0
        if consistency < filters['min_consistency']:
            print(f"   💀 RECHAZADO CONSISTENCIA: Solo {green_yrs}/{total_yrs} años verdes ({consistency:.0%})")
            continue

        # 4. PASO A ELITE 🏆
        print(f"   🏆 ¡ELITE ACEPTADO!")
        print(f"      - Consistencia: {green_yrs}/{total_yrs} años verdes.")
        print(f"      - Profit Total: {profit_total:.2f} | PF: {pf_total:.2f}")
        
        elites.append({
            'EA': ea_name,
            'Consistencia': f"{green_yrs}/{total_yrs}",
            'Profit': profit_total,
            'PF': pf_total,
            'DD_Max': dd_total
        })

    # --- REPORTE FINAL ---
    print("\n" + "=" * 68)
    print("🏆  TRIBUNAL DEL ISLARIO - RECUENTO DE ELITES")
    print("=" * 68)
    if not elites:
        print("❌ Ningún set alcanzó el estatus de ELITE en esta sesión.")
    else:
        df_elites = pd.DataFrame(elites)
        print(df_elites.to_string(index=False))
        print("\n📂 Estos sets están listos para el CARGADOR FINAL.")

    print("=" * 68)

if __name__ == '__main__':
    main()
