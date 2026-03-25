"""
C_Cruce_Pass.py
===============
Cruce por ADN (columnas inp*) entre el Forward filtrado y el Genético filtrado.
Los inp* se detectan dinámicamente del schema.json del EA.
Solo trabaja si encuentra AMBOS archivos filtrados para un EA.
Genera dos CSVs cruzados (forward_crossed + genetic_crossed).
"""

import os
import json
import pandas as pd

# ==============================================================================
# RUTAS BASE
# ==============================================================================
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR    = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
MODE_FOLDER = 'genetica70_fw30_OPTIMIZACION_GENETICA_FW'
BASE_DIR    = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Analizados', MODE_FOLDER)

# ==============================================================================
# HELPERS
# ==============================================================================
def get_inp_cols_from_schema(ea_name: str) -> list:
    """Lee el schema del genético para obtener la lista dinámica de columnas inp*."""
    schema_path = os.path.join(
        ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados',
        MODE_FOLDER, ea_name, f"{ea_name}.schema.json"
    )
    if os.path.exists(schema_path):
        with open(schema_path, 'r', encoding='utf-8') as f:
            schema = json.load(f)
        return [c.lower() for c in schema.get('inputs', [])]
    return []

def normalize_cols(df: pd.DataFrame) -> pd.DataFrame:
    df.columns = [c.lower().strip() for c in df.columns]
    return df

def dna_key(row, inp_cols: list) -> tuple:
    """Crea una tupla única con los valores de los inputs = el ADN del set."""
    return tuple(round(float(row[c]), 6) if isinstance(row[c], float) else row[c] for c in inp_cols)

# ==============================================================================
# MAIN
# ==============================================================================
def main():
    print("=" * 68)
    print("⚔️  C_Cruce_Pass.py  |  Intersección por ADN (inp*)")
    print("=" * 68)

    if not os.path.isdir(BASE_DIR):
        print(f"[ERROR] No existe la carpeta base: {BASE_DIR}")
        return

    ea_folders = [f for f in os.listdir(BASE_DIR) if os.path.isdir(os.path.join(BASE_DIR, f))]

    if not ea_folders:
        print("[ERROR] No se encontraron carpetas de EA en Reportes-Analizados.")
        return

    processed = 0
    skipped   = 0

    for ea_name in ea_folders:
        ea_dir = os.path.join(BASE_DIR, ea_name)

        fw_path = os.path.join(ea_dir, f"{ea_name}_forward_filtered.csv")
        bt_path = os.path.join(ea_dir, f"{ea_name}_genetic_filtered.csv")

        # Sin Forward = sin Edge útil
        if not os.path.exists(fw_path):
            print(f"\n[SKIP] {ea_name}: falta forward_filtered.csv → sin Edge. Ignorando.")
            skipped += 1
            continue

        if not os.path.exists(bt_path):
            print(f"\n[SKIP] {ea_name}: falta genetic_filtered.csv. Ignorando.")
            skipped += 1
            continue

        print(f"\n🔬 Procesando: {ea_name}")

        # Cargar CSVs
        df_fw = normalize_cols(pd.read_csv(fw_path))
        df_bt = normalize_cols(pd.read_csv(bt_path))

        # Obtener columnas inp* del schema (dinámico por EA)
        inp_cols = get_inp_cols_from_schema(ea_name)

        # Fallback: detectarlas del CSV si el schema no está disponible
        if not inp_cols:
            inp_cols = [c for c in df_fw.columns if c.startswith('inp')]
            print(f"   [WARN] Schema no encontrado. Detectadas {len(inp_cols)} columnas inp* del CSV.")

        if not inp_cols:
            print(f"   [ERROR] No se encontraron columnas inp*. Saltando.")
            skipped += 1
            continue

        print(f"   ADN detectado: {len(inp_cols)} columnas inp*")

        # Verificar que las columnas existen en ambos DataFrames
        missing_fw = [c for c in inp_cols if c not in df_fw.columns]
        missing_bt = [c for c in inp_cols if c not in df_bt.columns]
        if missing_fw or missing_bt:
            print(f"   [ERROR] Columnas faltantes: FW={missing_fw} BT={missing_bt}")
            skipped += 1
            continue

        # Construir set de ADNs del Forward filtrado
        fw_dna_set = set(df_fw.apply(lambda row: dna_key(row, inp_cols), axis=1))

        # Filtrar el Genético: solo los que tienen ese mismo ADN
        df_bt['_dna'] = df_bt.apply(lambda row: dna_key(row, inp_cols), axis=1)
        df_fw['_dna'] = df_fw.apply(lambda row: dna_key(row, inp_cols), axis=1)

        df_bt_crossed = df_bt[df_bt['_dna'].isin(fw_dna_set)].drop(columns=['_dna']).copy()
        df_fw_crossed = df_fw[df_fw['_dna'].isin(fw_dna_set)].drop(columns=['_dna']).copy()

        if df_bt_crossed.empty:
            print(f"   ⚠️  Ningún ADN del Forward coincide en el Genético. Sin Élite para este EA.")
            skipped += 1
            continue

        # Guardar CSVs cruzados
        fw_out = os.path.join(ea_dir, f"{ea_name}_forward_crossed.csv")
        bt_out = os.path.join(ea_dir, f"{ea_name}_genetic_crossed.csv")

        df_fw_crossed.to_csv(fw_out, index=False)
        df_bt_crossed.to_csv(bt_out, index=False)

        print(f"   Forward filtrado  : {len(df_fw)} sets")
        print(f"   Genético filtrado : {len(df_bt)} sets")
        print(f"   🏆 ADNs cruzados  : {len(df_fw_crossed)} (sobrevivieron AMBOS periodos)")
        print(f"   💾 {ea_name}_forward_crossed.csv")
        print(f"   💾 {ea_name}_genetic_crossed.csv")

        processed += 1

    print()
    print("=" * 68)
    print(f"✅ CRUCE COMPLETADO")
    print(f"   EAs procesados : {processed}")
    print(f"   EAs ignorados  : {skipped}")
    print()
    print("📌 Próximo paso:")
    print("   Abrir los _crossed.csv para comparar métricas entre")
    print("   el periodo conocido (genetic) y el periodo ciego (forward).")
    print("=" * 68)


if __name__ == '__main__':
    main()
