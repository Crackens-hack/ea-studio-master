"""
D_Rescate_Forward.py (ZERO-DEPENDENCY CLUSTERING)
=================================================
1. Detecta EAs sin convergencia de ADN.
2. Agrupa por familias de ADN usando un algoritmo K-Means manual (solo Numpy).
3. Aplica criterios DUROS de rescate del .conf.
4. Selecciona el 'Alfa' de cada familia para diversificación.
"""

import os
import json
import configparser
import pandas as pd
import numpy as np

# ==============================================================================
# RUTAS BASE
# ==============================================================================
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR     = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
CONF_FILE    = os.path.join(SCRIPT_DIR, 'criterios-de-rescate-forward.conf')
MODE_FOLDER  = 'genetica70_fw30_OPTIMIZACION_GENETICA_FW'
ANALIZADOS   = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Analizados', MODE_FOLDER)

# ==============================================================================
# ALGORITMO DE CLUSTERING MANUAL (K-Means zero-dep)
# ==============================================================================
def simple_kmeans(data, k=3, max_iters=20):
    """Implementación manual de K-means estable (con seed)."""
    np.random.seed(42) # Semilla fija para consistencia
    means = data.mean(axis=0)
    stds  = data.std(axis=0).replace(0, 1)
    scaled = (data - means) / stds
    X = scaled.values
    
    # Inicializar centroides de forma fija
    idx = np.linspace(0, len(X)-1, k, dtype=int)
    centroids = X[idx]
    
    for _ in range(max_iters):
        distances = np.linalg.norm(X[:, np.newaxis] - centroids, axis=2)
        clusters  = np.argmin(distances, axis=1)
        
        new_centroids = np.array([X[clusters == i].mean(axis=0) if len(X[clusters == i]) > 0 else centroids[i] for i in range(k)])
        if np.allclose(centroids, new_centroids): break
        centroids = new_centroids
        
    return clusters

# ==============================================================================
# HELPERS
# ==============================================================================
def load_conf(tf: str) -> dict:
    cfg = configparser.ConfigParser()
    cfg.read(CONF_FILE, encoding='utf-8')
    if tf.upper() not in cfg: raise SystemExit(f"[ERROR] Timeframe '{tf.upper()}' no encontrado en .conf")
    return dict(cfg[tf.upper()])

def get_inp_cols(ea_name: str) -> list:
    schema_path = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados', MODE_FOLDER, ea_name, f"{ea_name}.schema.json")
    if os.path.exists(schema_path):
        with open(schema_path, 'r', encoding='utf-8') as f:
            schema = json.load(f)
        return [c.lower() for c in schema.get('inputs', [])]
    return []

# ==============================================================================
# MAIN
# ==============================================================================
def main():
    print("=" * 68)
    print("🚨 D_Rescate_Forward  |  CLUSTERING MANUAL & FILTRADO DURO")
    print("=" * 68)

    ea_folders = [f for f in os.listdir(ANALIZADOS) if os.path.isdir(os.path.join(ANALIZADOS, f))]
    candidatos = [ea for ea in ea_folders if not os.path.exists(os.path.join(ANALIZADOS, ea, f"{ea}_forward_crossed.csv")) and os.path.exists(os.path.join(ANALIZADOS, ea, f"{ea}_forward_filtered.csv"))]

    if not candidatos:
        print("\n✅ Todos los EAs tienen convergencia o no han sido filtrados.")
        return

    print(f"\n📋 EAs para rescate detectados: {candidatos}")
    ea_name = candidatos[0] if len(candidatos) == 1 else input("Elegí el EA: ")
    
    # Cargar datos filtrados (los 78)
    fw_path = os.path.join(ANALIZADOS, ea_name, f"{ea_name}_forward_filtered.csv")
    df = pd.read_csv(fw_path)
    print(f"\n📂 Analizando {len(df)} sets existentes...")

    # Detectar ADN (inputs)
    inp_cols = get_inp_cols(ea_name)
    if not inp_cols: inp_cols = [c for c in df.columns if c.lower().startswith('inp')]
    print(f"🧬 ADN detectado: {len(inp_cols)} inputs.")

    # CLUSTERING (Manual K-Means)
    print("🎨 Agrupando por familias de ADN (Algoritmo de Islario Humano)...")
    n_clusters = min(5, len(df)) # Subimos a 5 para mayor sensibilidad
    df['cluster'] = simple_kmeans(df[inp_cols], k=n_clusters)

    # FILTROS DUROS DE RESCATE
    tf_input = input("\n¿Cuál es el Timeframe para los filtros de rescate? (M15, H1, H4, D1): ").strip().upper()
    print(f"🔪 Aplicando filtros duros del .conf para {tf_input}...")
    criteria = load_conf(tf_input) 
    
    mask = (
        (df['profit_factor'] >= float(criteria['profit_factor_min'])) &
        (df['equity_dd'] <= float(criteria['equity_dd_max'])) &
        (df['sharpe_ratio'] >= float(criteria['sharpe_min'])) &
        (df['recovery_factor'] >= float(criteria['recovery_factor_min']))
    )
    df_rescue = df[mask].copy()
    
    if df_rescue.empty:
        print("\n⚠️ Ningún set sobrevivió a los filtros duros.")
        return

    # SELECCIONAR ALFAS (Mejor de cada cluster)
    print(f"\n🏆 ALFAS DIVERSIFICADOS ENCONTRADOS ({len(df_rescue.cluster.unique())} grupos):")
    df_rescue = df_rescue.sort_values('forward_result', ascending=False)
    alfa_sets = df_rescue.groupby('cluster').head(1).copy()

    for i, row in alfa_sets.iterrows():
        print(f"   🔹 Familia {int(row['cluster'])} | Pass {int(row['pass'])} | PF: {row['profit_factor']:.2f} | Sharpe: {row['sharpe_ratio']:.2f}")

    # GUARDAR
    rescue_dir = os.path.join(ANALIZADOS, ea_name, "RESCATE_CLUSTER")
    os.makedirs(rescue_dir, exist_ok=True)

    # 7. GENERACIÓN DE ARCHIVOS .SET
    print(f"📄 Generando archivos .set profesionales...")
    
    # Obtener mapeo de casing correcto desde el schema
    schema_path = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados', MODE_FOLDER, ea_name, f"{ea_name}.schema.json")
    correct_case = {}
    if os.path.exists(schema_path):
        with open(schema_path, 'r', encoding='utf-8') as f:
            schema = json.load(f)
            for original_name in schema.get('inputs', []):
                correct_case[original_name.lower()] = original_name

    for i, row in alfa_sets.iterrows():
        set_filename = f"{ea_name}_ALFA_P{int(row['pass'])}_C{int(row['cluster'])}.set"
        set_path = os.path.join(rescue_dir, set_filename)
        
        with open(set_path, 'w', encoding='utf-16') as f: # MT5 prefiere UTF-16
            f.write(";archivo de configuracion\n")
            for col in inp_cols:
                final_name = correct_case.get(col, col) # Usar casing real o el de la columna
                val = row[col]
                # Formatear números para evitar problemas de precisión
                if isinstance(val, (float, np.float64)):
                    val_str = f"{val:.6f}".rstrip('0').rstrip('.')
                else:
                    val_str = str(val)
                f.write(f"{final_name}={val_str}\n")
        
        print(f"   ✅ .set generado: {set_filename}")

    # 8. FINALIZAR
    out_alfa = os.path.join(rescue_dir, f"{ea_name}_ALFAS_DIVERSIFICADOS.csv")
    alfa_sets.to_csv(out_alfa, index=False)

    print(f"\n💾 Resumen guardado en '{ea_name}_ALFAS_DIVERSIFICADOS.csv'")
    print(f"   Ubicación: {rescue_dir}")
    print("=" * 68)

if __name__ == '__main__':
    main()
