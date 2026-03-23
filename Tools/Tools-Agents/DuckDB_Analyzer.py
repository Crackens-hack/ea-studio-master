import duckdb
import argparse
import json
from pathlib import Path

def find_column(col_list, aliases):
    for a in aliases:
        for c in col_list:
            clean_c = c.lower().replace(" ", "_").replace("%", "").strip("_")
            clean_a = a.lower().replace(" ", "_").replace("%", "").strip("_")
            if clean_a == clean_c: return c
    return None

def main():
    parser = argparse.ArgumentParser(description="Analizador Inteligente de Optimizacion Genetica con DuckDB")
    parser.add_argument("--ea", type=str, required=True, help="Nombre del EA (Ej: Titan_Breakout_V1)")
    parser.add_argument("--mode", type=str, default="genetica70_fw30", help="Modo/carpeta del reporte (Ej: genetica70_fw30)")
    parser.add_argument("--top", type=int, default=10, help="Cantidad de mejores resultados a mostrar")
    parser.add_argument("--sort", type=str, default="fitness", choices=["profit", "fitness", "pf", "trades"], help="Criterio de ordenacion")
    parser.add_argument("--debug", action="store_true", help="Muestra el contenido crudo si no hay resultados filtrados")
    
    args = parser.parse_args()
    
    repo_root = Path(__file__).resolve().parent.parent.parent
    parquet_dir = repo_root / "BUILD" / "RESULTADOS" / "Reportes-Normalizados" / args.mode
    
    main_parquet = parquet_dir / f"{args.ea}_{args.mode}.parquet"
    fw_parquet = parquet_dir / f"{args.ea}_{args.mode}.forward.parquet"
    schema_path = parquet_dir / f"{args.ea}_{args.mode}.schema.json"
    
    if not main_parquet.exists():
        print(f"ERROR: No se encontro el archivo {main_parquet}.")
        return
        
    con = duckdb.connect()
    
    print("\n" + "="*80)
    print(f" ANALISIS GENETICO DUCKDB: {args.ea}")
    print("="*80)
    
    try:
        # --- CARGAR SCHEMA PRINCIPAL ---
        main_columns = []
        inputs = []
        if schema_path.exists():
            with schema_path.open("r", encoding="utf-8") as sf:
                sdata = json.load(sf)
                main_columns = sdata.get("all_columns", [])
                inputs = sdata.get("inputs", [])
        else:
            res = con.execute(f"SELECT * FROM '{main_parquet.as_posix()}' LIMIT 0")
            main_columns = [d[0] for d in res.description]
            inputs = [c for c in main_columns if c.lower().startswith("inp")]

        # Mapeo de métricas BT
        c_pass   = find_column(main_columns, ['pass']) or 'pass'
        c_profit = find_column(main_columns, ['profit']) or 'profit'
        c_pf     = find_column(main_columns, ['profit_factor', 'profitfactor']) or 'profit_factor'
        c_trades = find_column(main_columns, ['trades']) or 'trades'
        c_dd     = find_column(main_columns, ['equity_dd', 'equity_dd_pct', 'equitydd']) or 'equity_dd'
        c_rf     = find_column(main_columns, ['recovery_factor', 'recoveryfactor']) or 'recovery_factor'
        c_fit    = find_column(main_columns, ['result', 'custom', 'fitness', 'back_result']) or 'result'

        order_col = f'"{c_fit}"'
        if args.sort == "profit": order_col = f'"{c_profit}"'
        elif args.sort == "pf": order_col = f'"{c_pf}"'
        elif args.sort == "trades": order_col = f'"{c_trades}"'

        min_trades = 30
        select_cols = [f'"{c_pass}" as Pass', f'"{c_fit}" as Fitness', f'"{c_profit}" as Profit', f'"{c_pf}" as PF', f'"{c_rf}" as RF', f'"{c_dd}" as DD', f'"{c_trades}" as Trades']
        select_cols.extend([f'"{p}"' for p in inputs])
        
        query = f"""
        SELECT {', '.join(select_cols)}
        FROM '{main_parquet.as_posix()}'
        WHERE "{c_trades}" >= {min_trades} AND "{c_pf}" > 1.0
        ORDER BY {order_col} DESC LIMIT {args.top}
        """
        
        print(f"\n TOP {args.top} OPTIMIZADOS (Backtest): (Sorted by: {args.sort})")
        bt_results = con.execute(query).fetchdf()
        
        if bt_results.empty:
            print("  Ningun resultado cumple los filtros estandar.")
            if args.debug:
                print("\n [MODO DEBUG] Top 10 por Profit:")
                debug_col_str = f'"{c_pass}", "{c_fit}", "{c_profit}", "{c_pf}", "{c_trades}"'
                print(con.execute(f"SELECT {debug_col_str} FROM '{main_parquet.as_posix()}' ORDER BY \"{c_profit}\" DESC LIMIT 10").fetchdf())
        else:
            print(bt_results.to_string(index=False))

        # --- ANALISIS FORWARD ---
        if fw_parquet.exists():
            print("\n" + "="*80)
            print(" CRUCE CON RESULTADOS FORWARD TEST (Filtro Supervivencia)")
            print("="*80)
            
            res_fw = con.execute(f"SELECT * FROM '{fw_parquet.as_posix()}' LIMIT 0")
            fw_cols = [d[0] for d in res_fw.description]
            id_fw = find_column(fw_cols, ['pass', 'id']) or 'pass'
            c_fit_fw = find_column(fw_cols, ['forward_result', 'result', 'custom', 'fitness']) or 'result'
            c_profit_fw = find_column(fw_cols, ['profit']) or 'profit'
            c_pf_fw = find_column(fw_cols, ['profit_factor', 'profitfactor']) or 'profit_factor'
            c_trades_fw = find_column(fw_cols, ['trades']) or 'trades'

            fw_select = [f'b."{c_pass}" as Pass', f'b."{c_fit}" as Fit_BT', f'f."{c_fit_fw}" as Fit_FW', f'b."{c_profit}" as Profit_BT', f'f."{c_profit_fw}" as Profit_FW', f'f."{c_pf_fw}" as PF_FW', f'f."{c_trades_fw}" as Trades_FW']
            fw_select.extend([f'b."{p}"' for p in inputs])

            fw_query = f"""
            SELECT {', '.join(fw_select)}
            FROM '{main_parquet.as_posix()}' b
            JOIN '{fw_parquet.as_posix()}' f ON b."{c_pass}" = f."{id_fw}"
            WHERE b."{c_profit}" > 0
            ORDER BY f."{c_fit_fw}" DESC LIMIT 10
            """
            try:
                fw_results = con.execute(fw_query).fetchdf()
                if not fw_results.empty:
                    print(fw_results.to_string(index=False))
                    print("\n Estrategia: Buscamos Fit_FW > 0 y PF_FW > 1.2 para MAXIMA estabilidad.")
                else:
                    print("  No hay coincidencias rentables en Forward.")
                    if args.debug:
                        print("\n [MODO DEBUG] Top Forward (Sin cruce):")
                        try: print(con.execute(f"SELECT \"{id_fw}\", \"{c_fit_fw}\", \"{c_profit_fw}\", \"{c_pf_fw}\" FROM '{fw_parquet.as_posix()}' ORDER BY \"{c_fit_fw}\" DESC LIMIT 5").fetchdf())
                        except: pass
            except Exception as e_fw:
                print(f"  Error en cruce Forward: {e_fw}")

    except Exception as e:
        print(f"\n Error Critico: {e}")

if __name__ == "__main__":
    main()
