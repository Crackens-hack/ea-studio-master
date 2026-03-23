"""
Analista Profesional: evalúa resultados normalizados (CSV y JSON) y produce conclusiones.

Flujos:
- CSV (salida de A_Convertidor_xml_csv): aplica filtros y genera análisis; copia aprobados a Informes-Limpios.
- JSON (salida de C_analizar_reporte_htm): aplica filtros, calcula score, genera análisis; copia aprobados a Informes-Limpios.

Configuración centralizada en script/analisis_conf.json (secciones "csv" y "json").

Uso:
    python script/B_Analista_Profesional.py             # analiza csv y json
    python script/B_Analista_Profesional.py --csv       # solo csv
    python script/B_Analista_Profesional.py --json      # solo json
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd


# ------------------ utilidades ------------------ #
def load_conf(repo_root: Path) -> dict:
    conf_path = repo_root / "Tools" / "script" / "analisis_conf.json"
    defaults = {
        "csv": {
            "min_trades_fitness": 15,
            "min_trades_volume": 30,
            "top_n": 5,
            "top_pct": 0.10,
            "min_profit": 0.0,
            "min_pf": 1.0,
            "max_dd_pct": 25.0,
            "min_forward_ratio": 0.7,
            "sort_back": "Result",
            "sort_forward": "Forward Result",
            "numeric_columns": [
                "Result",
                "Forward Result",
                "Back Result",
                "Profit",
                "Expected Payoff",
                "Profit Factor",
                "Recovery Factor",
                "Sharpe Ratio",
                "Custom",
                "Equity DD %",
                "Trades",
            ],
        },
        "json": {
            "min_trades": 50,
            "min_pf": 1.2,
            "min_rf": 1.0,
            "max_dd_pct": 25.0,
            "min_net_profit": 0.0,
            "min_winrate": 50.0,
            "max_consec_loss_trades": 12,
            "score": {
                "pf_weight": 0.35,
                "rf_weight": 0.25,
                "winrate_weight": 0.15,
                "payoff_weight": 0.15,
                "dd_penalty": 0.10,
            },
            "top_n": 5,
        },
    }
    if conf_path.exists():
        try:
            data = json.loads(conf_path.read_text(encoding="utf-8"))
            return {
                "csv": {**defaults["csv"], **data.get("csv", {})},
                "json": {**defaults["json"], **data.get("json", {})},
            }
        except Exception as e:
            print(f"[WARN] No se pudo leer {conf_path}: {e}. Uso defaults.")
    return defaults


def ensure_dirs(repo_root: Path) -> tuple[Path, Path]:
    res_root = repo_root / "BUILD" / "RESULTADOS" / "Reportes-Normalizados"
    clean_root = repo_root / "BUILD" / "RESULTADOS" / "Reportes-Analizados"
    clean_root.mkdir(parents=True, exist_ok=True)
    return res_root, clean_root


# ------------------ CSV ------------------ #
def coerce_numeric(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    for col in columns:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def filter_csv(df: pd.DataFrame, conf: dict, is_forward: bool) -> pd.DataFrame:
    df = df.copy()
    df = df[df["Trades"] >= conf["min_trades_fitness"]]
    df = df[df["Profit"] > conf["min_profit"]]
    df = df[df["Profit Factor"] >= conf["min_pf"]]
    if "Equity DD %" in df.columns:
        df = df[df["Equity DD %"] <= conf["max_dd_pct"]]
    if is_forward:
        df["fwd_back_ratio"] = df["Forward Result"] / df["Back Result"].replace(0, np.nan)
        df = df[df["fwd_back_ratio"] >= conf["min_forward_ratio"]]
    return df


def summarize_csv(df: pd.DataFrame, conf: dict, is_forward: bool) -> tuple[str, pd.DataFrame]:
    df = filter_csv(df, conf, is_forward)
    lines = []
    lines.append(f"Total pasadas (post-filtro): {len(df)}")
    top_n = conf["top_n"]

    if is_forward:
        df = df.sort_values(by=conf["sort_forward"], ascending=False)
        lines.append(f"\n[Top {top_n} {conf['sort_forward']}]")
        lines.append(df.head(top_n)[["Pass", "Forward Result", "Back Result", "Profit", "Profit Factor", "Equity DD %", "Trades", "fwd_back_ratio"]].to_string(index=False))
    else:
        df = df.sort_values(by=conf["sort_back"], ascending=False)
        lines.append(f"\n[Top {top_n} {conf['sort_back']}]")
        lines.append(df.head(top_n)[["Pass", "Result", "Profit", "Profit Factor", "Equity DD %", "Trades"]].to_string(index=False))

        min_vol = conf["min_trades_volume"]
        top_vol = df[df["Trades"] >= min_vol].head(top_n)
        lines.append(f"\n[Top {top_n} Volumen | Trades >= {min_vol}]")
        if len(top_vol):
            lines.append(top_vol[["Pass", "Result", "Profit", "Equity DD %", "Trades"]].to_string(index=False))
        else:
            lines.append("No hay pasadas con ese mínimo de trades.")

    summary = "\n".join(lines)
    top_df = df.head(top_n)

    # Estadística avanzada de parámetros Inp* (media, mediana, p25/p75, modo para no numérico)
    inp_cols = [c for c in top_df.columns if c.startswith("Inp")]
    if inp_cols and len(top_df):
        stats_lines = []
        for c in inp_cols:
            series_num = pd.to_numeric(top_df[c], errors="coerce")
            if series_num.notna().any():
                # Forzar a float para evitar TypeError en quantile() con numpy 2.x si es booleano
                if series_num.dtype == bool:
                    series_num = series_num.astype(float)
                stats_lines.append(
                    f"- {c}: media={series_num.mean():.2f} mediana={series_num.median():.2f} p25={series_num.quantile(0.25):.2f} p75={series_num.quantile(0.75):.2f}"
                )
            else:
                # modo para no numéricos/bools
                mode_vals = top_df[c].mode()
                mode_display = "|".join(mode_vals.astype(str).tolist()) if not mode_vals.empty else "N/A"
                stats_lines.append(f"- {c}: modo={mode_display}")
        if stats_lines:
            summary += "\n\n[Parámetros (Top {0}) media/mediana/p25/p75 | modo]\n".format(top_n)
            summary += "\n".join(stats_lines)

    return summary, top_df


def analyze_csv(repo_root: Path, conf: dict, clean_root: Path, res_root: Path):
    csv_files = sorted(res_root.rglob("*.csv"))
    if not csv_files:
        print("[INFO] No encontré CSV en Res/.")
        return

    summaries = []
    for csv_path in csv_files:
        try:
            df = pd.read_csv(csv_path)
        except Exception as e:
            print(f"[ERROR] No se pudo leer {csv_path}: {e}")
            continue

        df = coerce_numeric(df, conf["numeric_columns"])
        is_forward = "Forward Result" in df.columns and "Back Result" in df.columns
        summary, top_df = summarize_csv(df, conf, is_forward)

        out_txt = csv_path.with_name(csv_path.stem + "_analysis.txt")
        out_txt.write_text(summary, encoding="utf-8")
        summaries.append(f"{csv_path}:\n{summary}\n")

        # copiar a Informes-Limpios solo el análisis si pasa al menos 1 fila tras filtros
        if len(top_df):
            dest_txt = clean_root / out_txt.relative_to(res_root)
            dest_txt.parent.mkdir(parents=True, exist_ok=True)
            dest_txt.write_bytes(out_txt.read_bytes())

    if summaries:
        analysis_dir = clean_root / "1_No_Pasan_Filtros"
        analysis_dir.mkdir(parents=True, exist_ok=True)
        (analysis_dir / "csv_analysis.txt").write_text("\n".join(summaries), encoding="utf-8")
        print("[OK] csv_analysis.txt generado y análisis CSV aprobados copiados a Reportes-Analizados.")


# ------------------ JSON ------------------ #
def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"[ERROR] No pude leer {path}: {e}")
        return None


def passes_json_filters(doc: dict, conf: dict) -> tuple[bool, list[str]]:
    num = doc.get("numeric", {})
    reasons = []
    try:
        if (num.get("total_trades") or 0) < conf["min_trades"]:
            reasons.append(f"trades<{conf['min_trades']}")
        if (num.get("profit_factor") or 0) < conf["min_pf"]:
            reasons.append(f"pf<{conf['min_pf']}")
        if (num.get("recovery_factor") or 0) < conf["min_rf"]:
            reasons.append(f"rf<{conf['min_rf']}")
        ddp = num.get("equity_dd_rel_pct")
        if ddp is None:
            ddp = num.get("balance_dd_rel_pct")
        if ddp is None:
            ddp = 0
        if ddp > conf["max_dd_pct"]:
            reasons.append(f"dd%>{conf['max_dd_pct']}")
        if (num.get("net_profit") or 0) <= conf["min_net_profit"]:
            reasons.append(f"net_profit<={conf['min_net_profit']}")
        if (num.get("profit_trades_pct") or 0) < conf["min_winrate"]:
            reasons.append(f"winrate<{conf['min_winrate']}")
        if (num.get("consec_losses_trades") or 0) > conf["max_consec_loss_trades"]:
            reasons.append(f"consec_losses>{conf['max_consec_loss_trades']}")
        return len(reasons) == 0, reasons
    except Exception as e:
        return False, [f"error:{e}"]


def compute_score(doc: dict, conf: dict) -> float:
    num = doc.get("numeric", {})
    pf = max(num.get("profit_factor", 0), 0)
    rf = max(num.get("recovery_factor", 0), 0)
    wr = max(num.get("profit_trades_pct", 0), 0) / 100.0
    payoff = 0.0
    if num.get("avg_loss") not in (None, 0):
        payoff = abs((num.get("avg_profit", 0) or 0) / num.get("avg_loss"))
    dd = max(num.get("equity_dd_rel_pct", num.get("balance_dd_rel_pct", 0)) or 0, 0)
    s = conf["score"]
    base = (pf ** s["pf_weight"]) * (max(rf, 0.0001) ** s["rf_weight"]) * (max(wr, 0.0001) ** s["winrate_weight"]) * (max(payoff, 0.0001) ** s["payoff_weight"])
    return base / (1 + s["dd_penalty"] * dd)


def analyze_json(repo_root: Path, conf: dict, clean_root: Path, res_root: Path):
    json_files = sorted(res_root.rglob("*.json"))
    if not json_files:
        print("[INFO] No encontré JSON en Res/.")
        return

    docs = []
    passed_paths = []
    failed_paths = []
    for path in json_files:
        doc = load_json(path)
        if not doc:
            failed_paths.append((path, ["read_error"]))
            continue
        ok, reasons = passes_json_filters(doc, conf)
        if ok:
            doc["_score"] = compute_score(doc, conf)
            doc["_path"] = path
            docs.append(doc)
            passed_paths.append(path)
        else:
            failed_paths.append((path, reasons))

    docs = sorted(docs, key=lambda d: d["_score"], reverse=True)
    top_n = conf["top_n"]
    lines = []
    lines.append(f"Reportes filtrados: {len(docs)}")
    lines.append(f"\n[Top {top_n} Score]")
    for d in docs[:top_n]:
        num = d.get("numeric", {})
        payoff = None
        if num.get("avg_loss") not in (None, 0):
            payoff = abs((num.get("avg_profit", 0) or 0) / num.get("avg_loss"))
        lines.append(f"- {d.get('expert')} {d.get('symbol')} Score={d['_score']:.4f} PF={num.get('profit_factor')} RF={num.get('recovery_factor')} DD%={num.get('equity_dd_rel_pct')} WR%={num.get('profit_trades_pct')} Payoff≈{payoff} Trades={num.get('total_trades')} OnTester={num.get('on_tester')}")

    analysis_dir = clean_root / "1_No_Pasan_Filtros"
    analysis_dir.mkdir(parents=True, exist_ok=True)
    out_path = analysis_dir / "json_analysis.txt"
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"[OK] json_analysis.txt generado.")

    # Copiar aprobados a Informes-Limpios
    for path in passed_paths:
        rel = path.relative_to(res_root)
        dest_json = clean_root / rel
        dest_json.parent.mkdir(parents=True, exist_ok=True)
        dest_json.write_bytes(path.read_bytes())
        md_src = path.with_suffix(".md")
        htm_src = path.with_suffix(".htm")
        if md_src.exists():
            md_dest = clean_root / md_src.relative_to(res_root)
            md_dest.parent.mkdir(parents=True, exist_ok=True)
            md_dest.write_bytes(md_src.read_bytes())
        if htm_src.exists():
            htm_dest = clean_root / htm_src.relative_to(res_root)
            htm_dest.parent.mkdir(parents=True, exist_ok=True)
            htm_dest.write_bytes(htm_src.read_bytes())

    if failed_paths:
        failed_path = analysis_dir / "json_descartados.txt"
        lines = [f"{p}: {', '.join(r)}" for p, r in failed_paths]
        failed_path.write_text("\n".join(lines), encoding="utf-8")
        print(f"[INFO] Descartados listados en {failed_path}")


# ------------------ main ------------------ #
def main():
    parser = argparse.ArgumentParser(description="Analista Profesional (CSV + JSON normalizados).")
    parser.add_argument("--csv", action="store_true", help="Solo analizar CSV.")
    parser.add_argument("--json", action="store_true", help="Solo analizar JSON.")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent.parent
    conf = load_conf(repo_root)
    res_root, clean_root = ensure_dirs(repo_root)

    do_csv = args.csv or not args.json
    do_json = args.json or not args.csv

    if do_csv:
        analyze_csv(repo_root, conf["csv"], clean_root, res_root)
    if do_json:
        analyze_json(repo_root, conf["json"], clean_root, res_root)


if __name__ == "__main__":
    main()
