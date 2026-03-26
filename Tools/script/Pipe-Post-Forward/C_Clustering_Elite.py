"""
D_Clustering_Elite.py
======================
Agrupamiento inteligente de sets por ADN (parámetros de entrada).
Identifica familias lógicas y extrae al mejor representante de cada una.
Evita redundancia en la validación final.
"""

import os
import json
import pandas as pd
import numpy as np
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

# ==============================================================================
# CONFIGURACIÓN
# ==============================================================================
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR    = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..', '..'))
MODE_FOLDER = 'genetica70_fw30_OPTIMIZACION_GENETICA_FW'
BASE_DIR    = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Analizados', MODE_FOLDER)
MAX_CLUSTERS = 18

# ==============================================================================
# MAIN
# ==============================================================================
def main():
    print("=" * 68)
    print("🧬 D_Clustering_Elite.py | Agrupamiento por Familias de ADN")
    print("=" * 68)

    if not os.path.isdir(BASE_DIR):
        print(f"[ERROR] No existe la carpeta base: {BASE_DIR}")
        return

    ea_folders = [f for f in os.listdir(BASE_DIR) if os.path.isdir(os.path.join(BASE_DIR, f))]

    if not ea_folders:
        print("[ERROR] No se encontraron carpetas de EA.")
        return

    for ea_name in ea_folders:
        ea_dir = os.path.join(BASE_DIR, ea_name)
        # 📂 La brújula ahora apunta a la carpeta de Cruces
        input_path = os.path.join(ea_dir, '2_CROSSED_DNA', f"{ea_name}_genetic_crossed.csv")

        if not os.path.exists(input_path):
            continue

        print(f"\n🔬 Procesando familias para: {ea_name}")
        df = pd.read_csv(input_path)
        
        if len(df) < 2:
            print("   [INFO] Muy pocos sets para clusterizar. Saltando.")
            continue

        # 1. Identificar columnas de ADN (entradas inp*)
        inp_cols = [c for c in df.columns if c.lower().startswith('inp')]
        if not inp_cols:
            print("   [ERROR] No se detectaron columnas de entrada (inp*).")
            continue

        # 2. Preparar datos para KMeans (Escalado)
        X = df[inp_cols].copy()
        
        # Eliminar columnas con varianza cero (constantes que arruinan el clustering)
        X = X.loc[:, (X != X.iloc[0]).any()]
        if X.empty:
            print("   [INFO] Todos los sets tienen el mismo ADN exacto. No hay clusters que formar.")
            continue

        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)

        # 3. Determinar número de clusters
        n_samples = len(df)
        k = min(MAX_CLUSTERS, n_samples // 2 if n_samples < 36 else MAX_CLUSTERS)
        if k < 2: k = 2
        
        print(f"   Calculando {k} familias lógicas...")

        # 4. Ejecutar Clustering
        kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
        df['cluster'] = kmeans.fit_predict(X_scaled)

        # 5. Cargar PESOS del .conf
        import configparser
        conf_path = os.path.join(SCRIPT_DIR, '..', 'Config-Filters', 'criterios-de-clustering-elite.conf')
        weights = {'sharpe_ratio': 1.0, 'profit_factor': 1.0, 'result': 1.0, 'recovery_factor': 1.0, 'trades': 1.0}
        
        if os.path.exists(conf_path):
            cfg = configparser.ConfigParser()
            cfg.read(conf_path, encoding='utf-8')
            if 'WEIGHTS' in cfg:
                for k_w in weights.keys():
                    weights[k_w] = float(cfg['WEIGHTS'].get(f"{k_w.upper()}_WEIGHT", 1.0))

        # 6. Calcular "SCORE ÉLITE" (Normalización Min-Max para comparar peras con manzanas)
        df_score = df.copy()
        for col in weights.keys():
            if col in df_score.columns:
                c_min = df_score[col].min()
                c_max = df_score[col].max()
                if c_max != c_min:
                    df_score[f'_{col}_norm'] = (df_score[col] - c_min) / (c_max - c_min)
                else:
                    df_score[f'_{col}_norm'] = 1.0
            else:
                df_score[f'_{col}_norm'] = 0.0

        df['elite_score'] = sum(df_score[f'_{col}_norm'] * weights[col] for col in weights.keys())

        # 7. Identificar al Líder de cada Familia (Mejor Elite Score)
        family_leaders = []
        for i in range(k):
            cluster_data = df[df['cluster'] == i]
            if cluster_data.empty: continue
            
            # El líder es el que tenga el mayor score ponderado
            leader = cluster_data.sort_values(by='elite_score', ascending=False).iloc[0]
            family_leaders.append(leader)

        df_leaders = pd.DataFrame(family_leaders)
        
        # 8. Organización: Crear subcarpeta de Clusters
        cluster_dir = os.path.join(ea_dir, '1_CLUSTERS_ELITE')
        if not os.path.exists(cluster_dir):
            os.makedirs(cluster_dir)

        # 9. Guardar Resultados
        output_all = os.path.join(cluster_dir, f"{ea_name}_clustered_full.csv")
        output_leaders = os.path.join(cluster_dir, f"{ea_name}_family_leaders.csv")
        
        df.to_csv(output_all, index=False)
        df_leaders.to_csv(output_leaders, index=False)

        print(f"   ✅ Familias identificadas: {len(df_leaders)}")
        print(f"   💾 Guardado en: {cluster_dir}")

        # ======================================================================
        # 🧪 FASE CARGADOR: Generar archivos .set para cada líder
        # ======================================================================
        cargador_dir = os.path.join(cluster_dir, "CARGADOR")
        os.makedirs(cargador_dir, exist_ok=True)
        
        # Obtener mapeo de casing correcto desde el schema (como en el rescatador)
        schema_path = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados', MODE_FOLDER, ea_name, f"{ea_name}.schema.json")
        correct_case = {}
        if os.path.exists(schema_path):
            with open(schema_path, 'r', encoding='utf-8') as f:
                schema = json.load(f)
                for original_name in schema.get('inputs', []):
                    correct_case[original_name.lower()] = original_name

        for i, row in df_leaders.iterrows():
            pass_id = int(row['pass'])
            cluster_id = int(row['cluster'])
            
            # 📂 Crear Carpeta del Cartucho
            cartucho_name = f"CARTUCHO_{cluster_id:02d}_P{pass_id}"
            cartucho_dir = os.path.join(cargador_dir, cartucho_name)
            os.makedirs(cartucho_dir, exist_ok=True)
            
            # 📄 Escribir el .set (Llamarlo como el EA.set)
            set_path = os.path.join(cartucho_dir, f"{ea_name}.set")
            
            with open(set_path, 'w', encoding='utf-16') as f: # MT5 prefiere UTF-16
                f.write(";archivo de configuracion\n")
                for col in inp_cols:
                    final_name = correct_case.get(col, col) # Usar casing real o el de la columna
                    val = row[col]
                    # Formatear números para evitar problemas de precisión
                    if isinstance(val, (float, np.float64, np.float32)):
                        val_str = f"{val:.6f}".rstrip('0').rstrip('.')
                    else:
                        val_str = str(val)
                    f.write(f"{final_name}={val_str}\n")
            
            print(f"      🎯 Cartucho listo: {cartucho_name}")

    print("\n" + "=" * 68)
    print("📢 PROCESO COMPLETADO. Revisá los archivos '_family_leaders.csv'.")
    print("=" * 68)

if __name__ == '__main__':
    main()
