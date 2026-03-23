import duckdb
import argparse
import json
import pandas as pd
from pathlib import Path
from datetime import datetime

"""
🚀 SUPER DUCKDB ANALYZER V5.4 – ELITE MASTER ENGINE
Este script es el único juez de la fábrica. Analiza Backtest y Forward, 
detecta clústeres de parámetros y genera reportes de élite automáticamente.
"""

def find_column(col_list, aliases):
    for a in aliases:
        for c in col_list:
            clean_c = c.lower().replace(" ", "_").replace("%", "").strip("_")
            clean_a = a.lower().replace(" ", "_").replace("%", "").strip("_")
            if clean_a == clean_c: return c
    return None

def calculate_clusters(df, input_cols):
    """Calcula la estabilidad de los parámetros en el Top N"""
    clusters = {}
    if df.empty or not input_cols: return clusters
    
    for col in input_cols:
        series = pd.to_numeric(df[col], errors='coerce')
        if series.notna().any():
            mean_val = series.mean()
            std_val = series.std()
            clusters[col] = {
                "mean": round(mean_val, 4),
                "std": round(std_val, 4),
                "robust": std_val < (mean_val * 0.2) if mean_val != 0 else True
            }
        else:
            mode_val = df[col].mode()
            clusters[col] = {
                "mode": mode_val.iloc[0] if not mode_val.empty else "N/A",
                "robust": len(mode_val) == 1
            }
    return clusters

def generate_elite_report(ea_name, bt_df, fw_df, clusters, output_dir):
    """Genera el Reporte_Elite_01.md automáticamente"""
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / f"Reporte_Elite_{ea_name}.md"
    
    lines = [
        f"# 🏆 REPORTE DE ÉLITE: {ea_name}",
        f"**Fecha de Análisis**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "\n## 📊 1. RESUMEN DE SUPERVIVENCIA (BT vs FW)",
        "| Pass | Fit_BT | Fit_FW | Profit_BT | Profit_FW | PF_FW | Trades_FW |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"
    ]
    
    for _, row in fw_df.iterrows():
        lines.append(f"| {row['Pass']} | {row['Fit_BT']:.2f} | {row['Fit_FW']:.2f} | {row['Profit_BT']:.2f} | {row['Profit_FW']:.2f} | {row['PF_FW']:.2f} | {row['Trades_FW']} |")
    
    lines.append("\n## 🧠 2. ANÁLISIS DE CLÚSTERES (Robustez de Parámetros)")
    lines.append("Determinamos si los mejores pases comparten un ADN común o son 'golpes de suerte'.")
    lines.append("\n| Parámetro | Valor Sugerido | Desv. Estándar | Estado |")
    lines.append("| :--- | :--- | :--- | :--- |")
    
    for param, data in clusters.items():
        val = data.get("mean", data.get("mode"))
        std = data.get("std", "N/A")
        status = "✅ ROBUSTO" if data["robust"] else "⚠️ DISPERSO"
        lines.append(f"| {param} | {val} | {std} | {status} |")
    
    lines.append("\n## ⚖️ 3. CONCLUSIÓN INGENIERIL")
    if not fw_df.empty and fw_df.iloc[0]['PF_FW'] > 1.2:
        lines.append("✅ **ESTRATEGIA APROBADA**: Existe un clúster de parámetros con supervivencia real en Forward Test.")
    else:
        lines.append("❌ **ESTRATEGIA RECHAZADA**: Inconsisténcia detectada o supervivencia insuficiente en Forward.")

    report_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"  [OK] Reporte generado: {report_path.name}")

def process_ea(con, main_parquet, fw_parquet, ea_name, mode, top_n, do_report, repo_root):
    """Lógica de proceso para un solo EA"""
    print(f"\n" + "="*60)
    print(f" 🔍 ANALIZANDO: {ea_name} ({mode})")
    print("="*60)
    
    elite_dir = repo_root / "BUILD" / "1_BUILDING" / "05_METRICAS_ELITES" / ea_name

    # --- CARGAR COLUMNAS ---
    try:
        res = con.execute(f"SELECT * FROM '{main_parquet.as_posix()}' LIMIT 0")
        main_columns = [d[0] for d in res.description]
        inputs = [c for c in main_columns if c.lower().startswith("inp")]

        c_pass = find_column(main_columns, ['pass']) or 'pass'
        c_profit = find_column(main_columns, ['profit']) or 'profit'
        c_pf = find_column(main_columns, ['profit_factor']) or 'profit_factor'
        c_trades = find_column(main_columns, ['trades']) or 'trades'
        c_fit = find_column(main_columns, ['result', 'custom', 'fitness']) or 'result'

        # --- QUERY BACKTEST ---
        query_bt = f"""
        SELECT "{c_pass}" as Pass, "{c_fit}" as Fitness, "{c_profit}" as Profit, "{c_pf}" as PF, "{c_trades}" as Trades, 
        {', '.join([f'"{i}"' for i in inputs])}
        FROM '{main_parquet.as_posix()}'
        WHERE "{c_trades}" >= 20 AND "{c_pf}" > 1.0
        ORDER BY "{c_fit}" DESC LIMIT {top_n}
        """
        bt_results = con.execute(query_bt).fetchdf()
        
        print(f" > TOP {top_n} Backtest:")
        if not bt_results.empty:
            print(bt_results[['Pass', 'Fitness', 'Profit', 'PF', 'Trades']].head(5).to_string(index=False))
        else:
            print("   No hay pases aprobados en Backtest.")

        # --- QUERY FORWARD ---
        if fw_parquet.exists():
            res_fw = con.execute(f"SELECT * FROM '{fw_parquet.as_posix()}' LIMIT 0")
            fw_cols = [d[0] for d in res_fw.description]
            id_fw = find_column(fw_cols, ['pass', 'id', 'Id']) or 'pass'
            c_fit_fw = find_column(fw_cols, ['forward_result', 'result', 'custom']) or 'result'
            c_profit_fw = find_column(fw_cols, ['profit']) or 'profit'
            c_pf_fw = find_column(fw_cols, ['profit_factor']) or 'profit_factor'
            c_trades_fw = find_column(fw_cols, ['trades']) or 'trades'

            query_fw = f"""
            SELECT b."{c_pass}" as Pass, b."{c_fit}" as Fit_BT, f."{c_fit_fw}" as Fit_FW, 
                   b."{c_profit}" as Profit_BT, f."{c_profit_fw}" as Profit_FW, 
                   f."{c_pf_fw}" as PF_FW, f."{c_trades_fw}" as Trades_FW,
                   {', '.join([f'b."{i}"' for i in inputs])}
            FROM '{main_parquet.as_posix()}' b
            JOIN '{fw_parquet.as_posix()}' f ON b."{c_pass}" = f."{id_fw}"
            WHERE f."{c_pf_fw}" > 1.1 OR f."{c_profit_fw}" > 0
            ORDER BY f."{c_fit_fw}" DESC LIMIT 10
            """
            fw_results = con.execute(query_fw).fetchdf()
            
            if not fw_results.empty:
                print(f" > Supervivientes Forward (Cruce):")
                print(fw_results[['Pass', 'Fit_BT', 'Fit_FW', 'Profit_FW', 'PF_FW']].head(5).to_string(index=False))
                
                clusters = calculate_clusters(fw_results, inputs)
                if do_report:
                    generate_elite_report(ea_name, bt_results, fw_results, clusters, elite_dir)
            else:
                print(" > No hay supervivientes en Forward.")
        else:
            print(" > Sin datos Forward detected.")
            
    except Exception as e:
        print(f"  [ERROR] Procesando {ea_name}: {e}")

def main():
    parser = argparse.ArgumentParser(description="SUPER DUCKDB ANALYZER V5.4 - AUTOMATIC SCAN")
    parser.add_argument("--ea", type=str, help="Nombre del EA (opcional, si se omite escanea todo)")
    parser.add_argument("--mode", type=str, help="Carpeta del reporte (opcional)")
    parser.add_argument("--top", type=int, default=10, help="Top N resultados")
    parser.add_argument("--report", action="store_true", help="Generar reportes Markdown")
    
    args = parser.parse_args()
    
    repo_root = Path(__file__).resolve().parent.parent.parent
    norm_root = repo_root / "BUILD" / "RESULTADOS" / "Reportes-Normalizados"
    
    if not norm_root.exists():
        print(f"ERROR: No existe la carpeta {norm_root}"); return
        
    con = duckdb.connect()
    
    # --- MODO 1: EA ESPECÍFICO ---
    if args.ea:
        mode = args.mode if args.mode else "genetica70_fw30"
        p_dir = norm_root / mode
        m_pq = p_dir / f"{args.ea}_{mode}.parquet"
        f_pq = p_dir / f"{args.ea}_{mode}.forward.parquet"
        
        if m_pq.exists():
            process_ea(con, m_pq, f_pq, args.ea, mode, args.top, args.report, repo_root)
        else:
            print(f"ERROR: No existe el parquet para {args.ea} en {mode}")
            
    # --- MODO 2: ESCANEO AUTOMÁTICO ---
    else:
        print(f"\n🚀 ESCANEANDO TODOS LOS REPORTES NORMALIZADOS...")
        parquet_files = list(norm_root.rglob("*.parquet"))
        processed_pairs = set()

        for pq in parquet_files:
            if ".forward." in pq.name: continue
            
            # El nombre suele ser EA_Mode.parquet
            # Intentamos extraer el modo basado en la carpeta padre
            mode = pq.parent.name
            ea_name = pq.name.replace(f"_{mode}.parquet", "").replace(".parquet", "")
            
            pair_key = (ea_name, mode)
            if pair_key in processed_pairs: continue # por si acaso
            
            f_pq = pq.parent / pq.name.replace(".parquet", ".forward.parquet")
            process_ea(con, pq, f_pq, ea_name, mode, args.top, args.report, repo_root)
            processed_pairs.add(pair_key)

if __name__ == "__main__":
    main()
