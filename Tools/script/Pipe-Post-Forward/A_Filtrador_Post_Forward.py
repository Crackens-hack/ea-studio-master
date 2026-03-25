"""
B_Filtrador_Post_Forward.py
==========================
Filtrado estándar de calidad Post-Genético + Forward.
Lee los CSVs normalizados, aplica criterios del archivo de configuración
y exporta dos CSVs filtrados en Reportes-Analizados para cruce posterior.
"""

import os
import sys
import json
import configparser
import pandas as pd

# ==============================================================================
# RUTAS BASE
# ==============================================================================
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR     = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..', '..'))
CONF_FILE    = os.path.join(SCRIPT_DIR, '..', 'Config-Filters', 'criterios-minimos-post-forward.conf')
MODE_FOLDER  = 'genetica70_fw30_OPTIMIZACION_GENETICA_FW'
INPUT_BASE   = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados', MODE_FOLDER)
OUTPUT_BASE  = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Analizados', MODE_FOLDER)

# ==============================================================================
# HELPERS
# ==============================================================================
def load_conf(tf: str) -> dict:
    cfg = configparser.ConfigParser()
    cfg.read(CONF_FILE, encoding='utf-8')
    tf_key = tf.upper()
    if tf_key not in cfg:
        print(f"[ERROR] Timeframe '{tf_key}' no encontrado en {CONF_FILE}")
        print(f"        Opciones disponibles: {list(cfg.sections())}")
        sys.exit(1)
    return dict(cfg[tf_key])

def list_ea_folders() -> list:
    if not os.path.isdir(INPUT_BASE):
        print(f"[ERROR] No existe la carpeta: {INPUT_BASE}")
        sys.exit(1)
    folders = [f for f in os.listdir(INPUT_BASE) if os.path.isdir(os.path.join(INPUT_BASE, f))]
    if not folders:
        print(f"[ERROR] No hay carpetas de EA en: {INPUT_BASE}")
        sys.exit(1)
    return folders

def choose_ea(folders: list) -> str:
    if len(folders) == 1:
        print(f"[AUTO] EA detectado: {folders[0]}")
        return folders[0]
    print("\nEAs disponibles:")
    for i, f in enumerate(folders, 1):
        print(f"  [{i}] {f}")
    sel = input("Elegí EA (número): ").strip()
    try:
        return folders[int(sel) - 1]
    except (ValueError, IndexError):
        print("[ERROR] Selección inválida.")
        sys.exit(1)

def load_schema(schema_path: str) -> dict:
    with open(schema_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def normalize_col(col: str) -> str:
    """Lowercase + replace spaces/% with underscores, strip trailing underscores."""
    return col.lower().strip().replace(' ', '_').replace('%', '').replace('__', '_').rstrip('_')

def load_csv(csv_path: str) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    df.columns = [normalize_col(c) for c in df.columns]
    return df

def apply_filters(df: pd.DataFrame, criteria: dict, years: int, label: str) -> pd.DataFrame:
    """Aplica los filtros del conf file proporcionales a los años del periodo."""
    trades_anuales  = float(criteria.get('trades_anuales', 30))
    min_trades      = int(trades_anuales * years)
    min_profit      = float(criteria.get('profit_min', 0.01))
    min_pf          = float(criteria.get('profit_factor_min', 1.25))
    min_ep          = float(criteria.get('expected_payoff_min', 0.50))
    max_dd          = float(criteria.get('equity_dd_max', 15.0))
    min_sharpe      = float(criteria.get('sharpe_min', 1.5))
    min_rf          = float(criteria.get('recovery_factor_min', 2.0))

    print(f"\n  [{label}] Filtros aplicados (proporcional a {years} años):")
    print(f"    Trades mínimos   : {min_trades}  ({trades_anuales}/año × {years} años)")
    print(f"    Profit mínimo    : {min_profit}")
    print(f"    Profit Factor    : ≥ {min_pf}")
    print(f"    Expected Payoff  : ≥ {min_ep}")
    print(f"    Equity DD máximo : ≤ {max_dd}%")
    print(f"    Sharpe mínimo    : ≥ {min_sharpe}")
    print(f"    Recovery Factor  : ≥ {min_rf}")

    initial = len(df)
    mask = (
        (df['trades']          >= min_trades) &
        (df['profit']          >= min_profit) &
        (df['profit_factor']   >= min_pf) &
        (df['expected_payoff'] >= min_ep) &
        (df['equity_dd']       <= max_dd) &
        (df['sharpe_ratio']    >= min_sharpe) &
        (df['recovery_factor'] >= min_rf)
    )
    filtered = df[mask].copy()
    print(f"    Resultado        : {len(filtered)} / {initial} sets sobrevivieron.")
    return filtered

def save_filtered(df: pd.DataFrame, out_dir: str, filename: str):
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, filename)
    df.to_csv(out_path, index=False)
    print(f"    💾 Guardado en: {out_path}")

# ==============================================================================
# MAIN
# ==============================================================================
def main():
    print("=" * 68)
    print("🦈 B_Filtrador_Post_Forward.py  |  CLI MODE - FILTRADO QUIRÚRGICO")
    print("=" * 68)

    # 1. Gestión de Argumentos o Inputs
    if len(sys.argv) >= 5:
        # Modo Automático (CLI)
        ea_name   = sys.argv[1]
        bt_years  = int(sys.argv[2])
        fw_years  = int(sys.argv[3])
        tf        = sys.argv[4].upper()
        print(f"   [CLI] EA: {ea_name} | BT: {bt_years}y | FW: {fw_years}y | TF: {tf}")
    else:
        # Modo Interactivo
        print("\n[MODO INTERACTIVO] Ingresá los datos manualmente:")
        bt_years  = int(input("¿Cuántos años duró el Backtest/Genético? (ej: 4): ").strip())
        fw_years  = int(input("¿Cuántos años duró el Forward? (ej: 2): ").strip())
        tf        = input("¿Cuál es el Timeframe? (M15, H1, H4, D1): ").strip().upper()
        
        # Selección de EA (Solo si no viene por argumento)
        ea_folders = list_ea_folders()
        ea_name    = choose_ea(ea_folders)

    criteria   = load_conf(tf)
    ea_dir     = os.path.join(INPUT_BASE, ea_name)
    out_dir    = os.path.join(OUTPUT_BASE, ea_name)

    # 3. Cargar schemas para validación de columnas
    schema_bt_path = os.path.join(ea_dir, f"{ea_name}.schema.json")
    schema_fw_path = os.path.join(ea_dir, f"{ea_name}.forward.schema.json")

    schema_bt = load_schema(schema_bt_path) if os.path.exists(schema_bt_path) else {}
    schema_fw = load_schema(schema_fw_path) if os.path.exists(schema_fw_path) else {}

    # 4. Cargar CSVs
    csv_bt_path = os.path.join(ea_dir, f"{ea_name}.csv")
    csv_fw_path = os.path.join(ea_dir, f"{ea_name}.forward.csv")

    if not os.path.exists(csv_bt_path):
        print(f"[ERROR] No existe: {csv_bt_path}")
        sys.exit(1)
    if not os.path.exists(csv_fw_path):
        print(f"[ERROR] No existe: {csv_fw_path}")
        sys.exit(1)

    df_bt = load_csv(csv_bt_path)
    df_fw = load_csv(csv_fw_path)

    print(f"\n📂 EA analizado: {ea_name}")
    print(f"   Backtest: {len(df_bt)} sets totales")
    print(f"   Forward : {len(df_fw)} sets totales")

    # 4. Determinar carpetas de salida
    # La salida SIEMPRE va a Reportes-Analizados
    out_dir = os.path.join(OUTPUT_BASE, ea_name, '3_FILTERED_POST_FW')
    
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)

    # 5. Aplicar filtros a cada periodo
    print("\n🔪 APLICANDO GUILLOTINA DE ACERO VALYRIO...")
    df_bt_filtered = apply_filters(df_bt, criteria, bt_years, "BACKTEST")
    df_fw_filtered = apply_filters(df_fw, criteria, fw_years, "FORWARD")

    # --- 💾 EXPORTANDO CSVs FILTRADOS ---
    print("\n💾 EXPORTANDO CSVs FILTRADOS...")
    
    # 📂 Organización: Crear subcarpeta del Analista
    # out_dir = os.path.join(ea_dir, '3_FILTERED_POST_FW') # This line is now redundant
    # if not os.path.exists(out_dir): # This check is now redundant
    #     os.makedirs(out_dir) # This creation is now redundant

    out_genetic = os.path.join(out_dir, f"{ea_name}_genetic_filtered.csv")
    out_forward = os.path.join(out_dir, f"{ea_name}_forward_filtered.csv")

    # Guardar siempre (incluso si están vacíos - solo cabecera)
    df_bt_filtered.to_csv(out_genetic, index=False)
    df_fw_filtered.to_csv(out_forward, index=False)

    # 📂 8. Generar Sensor para el Pipeline (info.txt)
    count_bt = len(df_bt_filtered)
    count_fw = len(df_fw_filtered)
    
    info_path = os.path.join(out_dir, "resumen_filtrado.txt")
    with open(info_path, 'w', encoding='utf-8') as f:
        f.write(f"forward_filtered={'YES' if count_fw > 0 else 'NO'} ({count_fw})\n")
        f.write(f"genetic_filtered={'YES' if count_bt > 0 else 'NO'} ({count_bt})\n")

    print(f"    💾 Guardado en: {out_dir}")
    print(f"    🚦 Sensor creado: {info_path}")

    # 9. Resumen final
    print()
    print("=" * 68)
    print(f"✅ FILTRADO COMPLETO")
    print(f"   Backtest élite : {count_bt} sets")
    print(f"   Forward élite  : {count_fw} sets")
    print(f"   Destino        : {out_dir}")
    print()
    print("📌 Próximo paso:")
    print("   Usar el script de CRUCE DE PASS para encontrar los sets")
    print("   que sobrevivieron en AMBOS periodos simultáneamente.")
    print("=" * 68)

if __name__ == '__main__':
    main()
