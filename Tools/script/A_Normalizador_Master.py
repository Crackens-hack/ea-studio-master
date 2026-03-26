"""
Normalizador master: procesa todos los reports de la instancia activa.

Incluye dos pasos:
1) XML -> CSV (estructura replicada en Res/).
2) HTM -> MD + JSON + CSV Resumen (en español) + copia del HTM (estructura replicada en Res/).

No hace filtrado ni análisis; solo normaliza y deja todo listo.

Uso:
    python script/A_Normalizador_Master.py          # ejecuta ambos pasos
    python script/A_Normalizador_Master.py --xml    # solo XML->CSV
    python script/A_Normalizador_Master.py --htm    # solo HTM->MD/JSON/CSV/HTM
"""

import argparse
import csv
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
import re

from bs4 import BeautifulSoup


# ------------------ Utilidades comunes ------------------ #
def load_reports_root(repo_root: Path) -> Path:
    cred_path = repo_root / "00_setup" / "Instancias" / "credencial_en_uso.json"
    if not cred_path.exists():
        sys.exit(f"No se encontró {cred_path}. Ejecutá 00_setup/Instalador.ps1 para seleccionar la instancia.")
    data = json.loads(cred_path.read_text(encoding="utf-8-sig"))
    reports = data.get("rutas", {}).get("reports")
    if not reports:
        sys.exit("El JSON de credencial no tiene la clave rutas.reports.")
    reports_path = Path(reports)
    if not reports_path.exists():
        sys.exit(f"La carpeta de reports no existe: {reports_path}")
    return reports_path


def _to_number(val):
    if val is None or val == "N/A": return None
    if isinstance(val, (int, float)): return val
    s = str(val).replace(" ", "").replace("%", "").replace(",", "")
    match = re.search(r"([-\d\.]+)", s)
    if match:
        try: return float(match.group(1))
        except: return None
    return None

def _parse_dual_value(val):
    """Retorna (valor_numerico, porcentaje) o (None, None)"""
    if not val or val == "N/A": return None, None
    s = str(val).replace(" ", "").replace(",", "")
    # Caso 1: 2122.57(37.17%) o 2.60(99.07%)
    m1 = re.search(r"([-\d\.]+)\(([-\d\.]+)%?\)", s)
    if m1:
        try: return float(m1.group(1)), float(m1.group(2))
        except: pass
    # Caso 2: 37.17%(2122.57) - Inverso
    m2 = re.search(r"([-\d\.]+)%\(([-\d\.]+)\)", s)
    if m2:
        try: return float(m2.group(2)), float(m2.group(1))
        except: pass
    # Fallback
    return _to_number(val), None


# ------------------ Paso 1: XML -> CSV ------------------ #
def convert_xml_to_csv(xml_path: Path, csv_path: Path) -> bool:
    ns = {"ss": "urn:schemas-microsoft-com:office:spreadsheet"}
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
        table = root.find(".//ss:Table", ns)
        if table is None:
            print(f"[WARN] Sin <Table> en {xml_path}")
            return False
        rows = table.findall("ss:Row", ns)
        if not rows:
            print(f"[WARN] Sin filas en {xml_path}")
            return False
        headers = [cell.find("ss:Data", ns).text if cell.find("ss:Data", ns) is not None else "" for cell in rows[0].findall("ss:Cell", ns)]
        csv_path.parent.mkdir(parents=True, exist_ok=True)
        with csv_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            for row in rows[1:]:
                cells = row.findall("ss:Cell", ns)
                data = []
                for cell in cells:
                    cell_data = cell.find("ss:Data", ns)
                    data.append(cell_data.text if cell_data is not None else "")
                writer.writerow(data)
        
        try:
            import duckdb
            parquet_path = csv_path.with_suffix(".parquet")
            # Usamos normalize_names para tener nombres limpios (sin espacios, minúsculas)
            con = duckdb.connect()
            con.execute(f"COPY (SELECT * FROM read_csv_auto('{csv_path.as_posix()}', normalize_names=True)) TO '{parquet_path.as_posix()}' (FORMAT PARQUET)")
            
            # Generar el "Schema Map" (Inteligencia de Columnas)
            res = con.execute(f"SELECT * FROM '{parquet_path.as_posix()}' LIMIT 0")
            col_names = [d[0] for d in res.description]
            schema = {
                "source_xml": xml_path.name,
                "total_columns": len(col_names),
                "metrics": [c for c in col_names if not c.lower().startswith("inp")],
                "inputs": [c for c in col_names if c.lower().startswith("inp")],
                "all_columns": col_names
            }
            schema_path = csv_path.with_suffix(".schema.json")
            with schema_path.open("w", encoding="utf-8") as sf:
                json.dump(schema, sf, indent=4)
        except Exception as e_duck:
            print(f"[WARN] No se pudo procesar schema/parquet con duckdb {csv_path}: {e_duck}")

        print(f"[OK] {xml_path} -> {csv_path}, parquet y schema.json")
        return True
    except Exception as e:
        print(f"[ERROR] {xml_path}: {e}")
        return False


def run_xml(repo_root: Path):
    reports_root = load_reports_root(repo_root)
    out_root = repo_root / "BUILD" / "RESULTADOS" / "Reportes-Normalizados"
    xml_files = sorted(reports_root.rglob("*.xml"))
    if not xml_files:
        print(f"[INFO] No se encontraron XML en {reports_root}")
        return
    ok = 0
    for xml_path in xml_files:
        rel = xml_path.relative_to(reports_root)
        session_name = rel.parent.name
        stem = rel.stem
        
        # 1. Limpiar el sufijo forward para encontrar el nombre base
        is_forward = ".forward" in stem.lower()
        clean_stem = stem.replace(".forward", "").replace(".Forward", "")
        
        # 2. Extraer el nombre del EA (quitando el nombre de la sesión)
        #    Esto evita rutas ultra-largas que rompen Windows.
        ea_name = clean_stem.replace(f"_{session_name}", "")
        
        # Carpeta dedicada para este EA dentro de la sesión
        xml_dir = out_root / rel.parent / ea_name
        xml_dir.mkdir(parents=True, exist_ok=True)
        
        # Nombre de archivo extremadamente limpio (.forward se mantiene para distinguir)
        suffix = ".forward" if is_forward else ""
        csv_path = xml_dir / f"{ea_name}{suffix}.csv"
        
        if convert_xml_to_csv(xml_path, csv_path):
            ok += 1
            # Eliminar crudo tras éxito
            try:
                xml_path.unlink()
            except:
                pass
    print(f"[RESUMEN XML] {ok}/{len(xml_files)} convertidos -> {out_root}")


# ------------------ Paso 2: HTM -> MD/JSON/HTM ------------------ #
def extraer_seccion_inputs(texto: str) -> str:
    match = re.search(r"Inputs:\s+(.*?)(?=Company:|Currency:|Initial Deposit:)", texto, re.DOTALL | re.IGNORECASE)
    if match:
        inputs_raw = match.group(1).strip()
        lines = [line.strip() for line in inputs_raw.split("\n") if line.strip() and line.strip() != "="]
        return "\n".join(lines)
    return "No encontrado"


def leer_htm(path: Path) -> str:
    for enc in ("utf-16", "utf-8"):
        try:
            return path.read_text(encoding=enc)
        except Exception:
            continue
    raise RuntimeError(f"No pude leer {path} con utf-16 ni utf-8")


def cargar_reporte(path: Path):
    content = leer_htm(path)
    soup = BeautifulSoup(content, "html.parser")
    texto = soup.get_text(separator="  ")

    settings_patterns = {
        "Expert": r"Expert:\s+(.*)",
        "Symbol": r"Symbol:\s+(.*)",
        "Period": r"Period:\s+(.*)",
        "History Quality": r"History Quality:\s+([\d%]+)",
        "Bars": r"Bars:\s+(\d+)",
        "Ticks": r"Ticks:\s+(\d+)",
        "Symbols": r"Symbols:\s+(\d+)",
        "Initial Deposit": r"Initial Deposit:\s+([\d\s\.,-]+)",
        "Leverage": r"Leverage:\s+([\d:]+)",
        "Company": r"Company:\s+(.*)",
        "Currency": r"Currency:\s+([A-Z]{3})",
    }

    resumen_set = {}
    for k, p in settings_patterns.items():
        m = re.search(p, texto, re.IGNORECASE)
        resumen_set[k] = m.group(1).strip() if m else "N/A"

    patrones = {
        "Net Profit": r"Total Net Profit:\s+([\d\s\.,-]+)",
        "Gross Profit": r"Gross Profit:\s+([\d\s\.,-]+)",
        "Gross Loss": r"Gross Loss:\s+([\d\s\.,-]+)",
        "DD Bal Abs": r"Balance Drawdown Absolute:\s+([\d\s\.,-]+)",
        "DD Bal Max": r"Balance Drawdown Maximal:\s+([\d\s\.,-]+\s+\(.*?%\))",
        "DD Bal Rel": r"Balance Drawdown Relative:\s+([\d\s\.,%]+\s+\(.*?[\d\s\.,-]+\))",
        "DD Eq Abs": r"Equity Drawdown Absolute:\s+([\d\s\.,-]+)",
        "DD Eq Max": r"Equity Drawdown Maximal:\s+([\d\s\.,-]+\s+\(.*?%\))",
        "DD Eq Rel": r"Equity Drawdown Relative:\s+([\d\s\.,%]+\s+\(.*?[\d\s\.,-]+\))",
        "Profit Factor": r"Profit Factor:\s+([\d\s\.,-]+)",
        "Expected Payoff": r"Expected Payoff:\s+([\d\s\.,-]+)",
        "Recovery Factor": r"Recovery Factor:\s+([\d\s\.,-]+)",
        "Sharpe Ratio": r"Sharpe Ratio:\s+([\d\s\.,-]+)",
        "Z-Score": r"Z-Score:\s+([\d\s\.,-]+\s+\(.*?%\))",
        "Margin Level": r"Margin Level:\s+([\d\s\.,%-]+)",
        "AHPR": r"AHPR:\s+([\d\s\.,-]+\s+\(.*?%\))",
        "GHPR": r"GHPR:\s+([\d\s\.,-]+\s+\(.*?%\))",
        "LR Correlation": r"LR Correlation:\s+([\d\s\.,-]+)",
        "LR Std Error": r"LR Standard Error:\s+([\d\s\.,-]+)",
        "OnTester": r"OnTester result:\s+([\d\s\.,-]+)",
        "Total Trades": r"Total Trades:\s+(\d+)",
        "Total Deals": r"Total Deals:\s+(\d+)",
        "Short Won": r"Short Trades \(won %\):\s+(\d+)\s+\(([\d\.,%-]+)\)",
        "Long Won": r"Long Trades \(won %\):\s+(\d+)\s+\(([\d\.,%-]+)\)",
        "Profit Trades": r"Profit Trades \(% of total\):\s+(\d+)\s+\(([\d\.,%-]+)\)",
        "Loss Trades": r"Loss Trades \(% of total\):\s+(\d+)\s+\(([\d\.,%-]+)\)",
        "Largest Profit": r"Largest profit trade:\s+([\d\s\.,-]+)",
        "Largest Loss": r"Largest loss trade:\s+([\d\s\.,-]+)",
        "Average Profit": r"Average profit trade:\s+([\d\s\.,-]+)",
        "Average Loss": r"Average loss trade:\s+([\d\s\.,-]+)",
        "Consec Wins Count": r"Maximum consecutive wins \(\$\):\s+(\d+)\s+\(([-\d\.,]+)\)",
        "Consec Loss Count": r"Maximum consecutive losses \(\$\):\s+(\d+)\s+\(([-\d\.,]+)\)",
        "Consec Profit Count": r"Maximal consecutive profit \(count\):\s+([-\d\.,]+)\s+\((\d+)\)",
        "Consec Loss Amount": r"Maximal consecutive loss \(count\):\s+([-\d\.,]+)\s+\((\d+)\)",
        "Avg Wins": r"Average consecutive wins:\s+(\d+)",
        "Avg Loss": r"Average consecutive losses:\s+(\d+)",
        "Corr Profits MFE": r"Correlation \(Profits,MFE\):\s+([\d\s\.,-]+)",
        "Corr Profits MAE": r"Correlation \(Profits,MAE\):\s+([\d\s\.,-]+)",
        "Corr MFE MAE": r"Correlation \(MFE,MAE\):\s+([\d\s\.,-]+)",
        "Min Hold": r"Minimal position holding time:\s+([\d:]+)",
        "Max Hold": r"Maximal position holding time:\s+([\d:]+)",
        "Avg Hold": r"Average position holding time:\s+([\d:]+)",
    }

    res = {}
    for k, p in patrones.items():
        m = re.search(p, texto, re.IGNORECASE)
        if not m:
            res[k] = "N/A"
        elif len(m.groups()) == 1:
            res[k] = m.group(1).strip()
        elif len(m.groups()) == 2:
            res[k] = (m.group(1).strip(), m.group(2).strip())
        else:
            res[k] = m.groups()

    inputs = extraer_seccion_inputs(texto)
    return resumen_set, res, inputs


def generar_markdown(resumen_set: dict, res: dict, inputs: str) -> str:
    return f"""# 📊 INFORME DE ESTRATEGIA: {resumen_set['Expert']}
---
## 📋 DATOS GENERALES DEL ESTRATEGIA
*   **Símbolo:** {resumen_set['Symbol']}
*   **Periodo:** {resumen_set['Period']}
*   **Calidad de Historia:** {resumen_set['History Quality']}
*   **Barras / Ticks / Símbolos:** {resumen_set['Bars']} / {resumen_set['Ticks']} / {resumen_set['Symbols']}
*   **Moneda de cuenta:** {resumen_set['Currency']}
*   **Depósito Inicial:** {resumen_set['Initial Deposit']} {resumen_set['Currency']}
*   **Apalancamiento:** {resumen_set['Leverage']}
*   **Broker (Company):** {resumen_set['Company']}

---

## ⚙️ CONFIGURACIÓN DE PARÁMETROS (Inputs)
```ini
{inputs}
```

---

## 💰 RENDIMIENTO FINANCIERO
*   **Beneficio Neto Total:** $ **{res['Net Profit']}**
*   **Balance Final:** $ **{res.get('Balance Final', 'N/A')}**
*   **Beneficio Bruto:** $ {res['Gross Profit']} | **Pérdida Bruta:** $ {res['Gross Loss']}
*   **Profit Factor:** **{res['Profit Factor']}** | **Expected Payoff:** {res['Expected Payoff']}
*   **Sharpe Ratio:** {res['Sharpe Ratio']} | **Recovery Factor:** {res['Recovery Factor']}
*   **Resultado del Tester (OnTester):** {res['OnTester']}

### Métricas de Estabilidad
*   **Z-Score:** {res['Z-Score']}
*   **AHPR / GHPR:** {res['AHPR']} / {res['GHPR']}
*   **Correlación LR / Error Estándar:** {res['LR Correlation']} / {res['LR Std Error']}
*   **Margen Mínimo:** {res['Margin Level']}

---

## 🛡️ ANÁLISIS DE RIESGO (DRAWDOWN)
| Tipo | Absoluto | Máximo | Relativo |
| :--- | :--- | :--- | :--- |
| **Balance** | $ {res['DD Bal Abs']} | $ {res['DD Bal Max']} | {res['DD Bal Rel']} |
| **Equity**  | $ {res['DD Eq Abs']} | $ **{res['DD Eq Max']}** | {res['DD Eq Rel']} |

---

## 🎯 ESTADÍSTICAS OPERATIVAS
*   **Total Trades / Deals:** {res['Total Trades']} / {res['Total Deals']}
*   **Win Rate Total:** **{res['Profit Trades'][1]}** ({res['Profit Trades'][0]} ganancias de {res['Total Trades']})
*   **Trades Perdedores:** {res['Loss Trades'][1]} ({res['Loss Trades'][0]} pérdidas)
*   **Efectividad Shorts (Sell):** {res['Short Won'][0]} ({res['Short Won'][1]})
*   **Efectividad Longs (Buy):**  {res['Long Won'][0]} ({res['Long Won'][1]})

### Análisis de Operaciones
*   **Mayor Ganancia / Pérdida:** $ {res['Largest Profit']} / $ {res['Largest Loss']}
*   **Promedio Ganancia / Pérdida:** $ {res['Average Profit']} / $ {res['Average Loss']}

### Análisis de Rachas Consecutivas
*   **Máximo Profit (USD / Conteo):** $ {res['Consec Profit Count'][0]} ({res['Consec Profit Count'][1]} trades) | Racha ganadora máx: {res['Consec Wins Count'][0]} trades ($ {res['Consec Wins Count'][1]})
*   **Máximo Loss (USD / Conteo):**  $ {res['Consec Loss Amount'][0]} ({res['Consec Loss Amount'][1]} trades) | Racha perdedora máx: {res['Consec Loss Count'][0]} trades ($ {res['Consec Loss Count'][1]})
*   **Promedio de Rachas (Ganadas/Perdidas):** {res['Avg Wins']} / {res['Avg Loss']}

---

## 📉 CORRELACIONES Y TIEMPOS
*   **Correlación (Profits, MFE):** {res['Corr Profits MFE']}
*   **Correlación (Profits, MAE):** {res['Corr Profits MAE']}
*   **Correlación (MFE, MAE):** {res['Corr MFE MAE']}

### Tiempo de Retención (Holding Time)
*   **Mínimo:** {res['Min Hold']}
*   **Máximo:** {res['Max Hold']}
*   **Promedio:** {res['Avg Hold']}

---
*Reporte Técnico Generado por AI Agent*
"""


MAPEO_ESPANOL = {
    "expert": "Asesor Experto",
    "symbol": "Símbolo",
    "period": "Periodo",
    "period_from": "Desde",
    "period_to": "Hasta",
    "history_quality": "Calidad de Historia",
    "bars": "Barras",
    "ticks": "Ticks",
    "symbols": "Símbolos",
    "currency": "Moneda",
    "initial_deposit": "Depósito Inicial",
    "leverage": "Apalancamiento",
    "company": "Compañía",
    "profit_factor": "Factor de Beneficio",
    "recovery_factor": "Factor de Recuperación",
    "sharpe": "Ratio Sharpe",
    "expected_payoff": "Pago Esperado",
    "net_profit": "Beneficio Neto",
    "balance_final": "Balance Final",
    "gross_profit": "Beneficio Bruto",
    "gross_loss": "Pérdida Bruta",
    "balance_dd_abs": "DD Balance Absoluto",
    "balance_dd_max_usd": "DD Balance Máximo ($)",
    "balance_dd_max_pct": "DD Balance Máximo (%)",
    "balance_dd_rel_pct": "DD Balance Relativo (%)",
    "balance_dd_rel_usd": "DD Balance Relativo ($)",
    "equity_dd_abs": "DD Equidad Absoluto",
    "equity_dd_max_usd": "DD Equidad Máximo ($)",
    "equity_dd_max_pct": "DD Equidad Máximo (%)",
    "equity_dd_rel_pct": "DD Equidad Relativo (%)",
    "equity_dd_rel_usd": "DD Equidad Relativo ($)",
    "total_trades": "Total de Operaciones",
    "total_deals": "Total de Tratos",
    "profit_trades_count": "Op Rentables (Cantidad)",
    "profit_trades_pct": "Op Rentables (%)",
    "loss_trades_count": "Op Perdedoras (Cantidad)",
    "loss_trades_pct": "Op Perdedoras (%)",
    "short_trades_count": "Op Cortas (Cantidad)",
    "short_trades_win_pct": "Op Cortas Ganadoras (%)",
    "long_trades_count": "Op Largas (Cantidad)",
    "long_trades_win_pct": "Op Largas Ganadoras (%)",
    "largest_profit": "Mayor Ganancia",
    "largest_loss": "Mayor Pérdida",
    "avg_profit": "Ganancia Promedio",
    "avg_loss": "Pérdida Promedio",
    "consec_profit_amount": "Monto Racha Ganadora",
    "consec_profit_trades": "Trades Racha Ganadora",
    "consec_loss_amount": "Monto Racha Perdedora",
    "consec_loss_trades": "Trades Racha Perdedora",
    "consec_wins_trades": "Trades Racha Ganancias Consec",
    "consec_wins_amount": "Monto Racha Ganancias Consec",
    "consec_losses_trades": "Trades Racha Pérdidas Consec",
    "consec_losses_amount": "Monto Racha Pérdidas Consec",
    "avg_wins": "Promedio Victorias Consecutivas",
    "avg_losses": "Promedio Pérdidas Consecutivas",
    "corr_pf_mfe": "Correlación (Beneficios, MFE)",
    "corr_pf_mae": "Correlación (Beneficios, MAE)",
    "corr_mfe_mae": "Correlación (MFE, MAE)",
    "hold_min": "Tiempo Retención Mínimo",
    "hold_max": "Tiempo Retención Máximo",
    "hold_avg": "Tiempo Retención Promedio",
    "on_tester": "Resultado OnTester",
    "z_score_val": "Z-Score (Valor)",
    "z_score_pct": "Z-Score (%)",
    "ahpr_val": "AHPR (Valor)",
    "ahpr_pct": "AHPR (%)",
    "ghpr_val": "GHPR (Valor)",
    "ghpr_pct": "GHPR (%)",
    "lr_corr": "Correlación LR",
    "lr_std_err": "Error Estándar LR",
    "margin_level": "Nivel de Margen (%)"
}

def generar_csv_resumen(flat: dict, csv_path: Path):
    headers = list(MAPEO_ESPANOL.values())
    row = [flat.get(k, "") for k in MAPEO_ESPANOL.keys()]
    
    # Agregar inputs como columnas dinámicas
    inputs = flat.get("inputs_list", [])
    for inp in inputs:
        if "=" in inp:
            k, v = inp.split("=", 1)
            headers.append(f"Input: {k.strip()}")
            row.append(v.strip())
            
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        # Usar coma por defecto para interoperabilidad, utf-8-sig para acentos en Excel
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerow(row)


def run_htm(repo_root: Path, ea_cli=None, pass_cli=None):
    rep_root = load_reports_root(repo_root)
    out_root = repo_root / "BUILD" / "RESULTADOS" / "Reportes-Normalizados"

    htm_files = sorted(rep_root.rglob("*.htm"))
    if not htm_files:
        print(f"[INFO] No encontré archivos .htm en {rep_root}")
        return

    ok = 0
    # Colector para consolidar fragmentos al final
    colector_fragmentos = {} # (session, ea) -> { "headers": [], "rows": [] }

    for htm in htm_files:
        try:
            resumen_set, res, inputs = cargar_reporte(htm)
            # Balance Final para MD y CSV
            dep_ini = _to_number(resumen_set.get("Initial Deposit"))
            ben_net = _to_number(res.get("Net Profit"))
            bal_fin = (dep_ini + ben_net) if (dep_ini is not None and ben_net is not None) else None
            res["Balance Final"] = f"{bal_fin:,.2f}" if bal_fin is not None else "N/A"

            md = generar_markdown(resumen_set, res, inputs)
            rel = htm.relative_to(rep_root)
            session_name = rel.parent.name
            full_stem = htm.stem
            
            # Identificar nombre de EA y si es modo fragmentado
            ea_expert_name = resumen_set.get("Expert", "EA_Desconocido")
            is_fragmented  = "fragmentado" in session_name.lower()
            
            # Extracción del nombre base del EA para la carpeta (remover el nombre de sesión)
            ea_base_from_file = full_stem.replace(f"_{session_name}", "")
            is_full_time      = (is_fragmented and "_ANYO_" not in full_stem)

            # Definir carpeta de salida
            if ea_cli and pass_cli:
                # MODO DISCRECIONAL (Inyectado por M-Tester)
                # Ruta: .../ea_name___discrecional/pass_id/Nombre_Fragmento
                folder_ea_discr = f"{ea_cli}___discrecional"
                if is_fragmented:
                    # Si es el maestre completo del fragmentado, lo llamamos FULL-TIME
                    folder_leaf = "FULL-TIME" if is_full_time else ea_base_from_file
                    report_dir = out_root / rel.parent / folder_ea_discr / str(pass_cli) / folder_leaf
                    ea_file_name = folder_leaf
                else:
                    report_dir = out_root / rel.parent / folder_ea_discr / str(pass_cli)
                    ea_file_name = ea_base_from_file
            elif is_fragmented:
                # MODO ESTÁNDAR FRAGMENTADO
                # Si es el maestre completo del fragmentado, lo llamamos FULL-TIME
                folder_leaf = "FULL-TIME" if is_full_time else ea_base_from_file
                # Jerarquía: Modo / EA_Expert / Nombre_Fragmento
                report_dir = out_root / rel.parent / ea_expert_name / folder_leaf
                ea_file_name = folder_leaf
            else:
                # MODO ESTÁNDAR UNIFICADO
                # Jerarquía estándar: Modo / EA_Base
                report_dir = out_root / rel.parent / ea_base_from_file
                ea_file_name = ea_base_from_file

            report_dir.mkdir(parents=True, exist_ok=True)

            out_path = report_dir / f"{ea_file_name}.md"
            out_path.write_text(md, encoding="utf-8")

            # Recuperar métricas individuales para el flat JSON
            profit_trades = res.get("Profit Trades")
            loss_trades   = res.get("Loss Trades")
            short_trades  = res.get("Short Won")
            long_trades   = res.get("Long Won")
            consec_wins   = res.get("Consec Wins Count")
            consec_losses = res.get("Consec Loss Count")
            consec_profit = res.get("Consec Profit Count")
            consec_loss_amount = res.get("Consec Loss Amount")

            period = resumen_set.get("Period", "")
            period_parts = re.findall(r"\(([^)]+)\)", period)
            period_range = period_parts[0] if period_parts else ""
            period_from, period_to = (period_range.split(" - ") + [None, None])[:2] if period_range else (None, None)

            # Parseo de duales para el CSV
            bal_max_usd, bal_max_pct = _parse_dual_value(res.get("DD Bal Max"))
            bal_rel_usd, bal_rel_pct = _parse_dual_value(res.get("DD Bal Rel"))
            eq_max_usd, eq_max_pct   = _parse_dual_value(res.get("DD Eq Max"))
            eq_rel_usd, eq_rel_pct   = _parse_dual_value(res.get("DD Eq Rel"))
            z_v, z_p                 = _parse_dual_value(res.get("Z-Score"))
            ahpr_v, ahpr_p           = _parse_dual_value(res.get("AHPR"))
            ghpr_v, ghpr_p           = _parse_dual_value(res.get("GHPR"))

            # (bal_fin ya calculado arriba)

            flat = {
                "expert": resumen_set.get("Expert"),
                "symbol": resumen_set.get("Symbol"),
                "period": resumen_set.get("Period"),
                "period_from": period_from,
                "period_to": period_to,
                "history_quality": resumen_set.get("History Quality"),
                "bars": resumen_set.get("Bars"),
                "ticks": resumen_set.get("Ticks"),
                "symbols": resumen_set.get("Symbols"),
                "currency": resumen_set.get("Currency"),
                "initial_deposit": resumen_set.get("Initial Deposit"),
                "leverage": resumen_set.get("Leverage"),
                "company": resumen_set.get("Company"),
                "profit_factor": res.get("Profit Factor"),
                "recovery_factor": res.get("Recovery Factor"),
                "sharpe": res.get("Sharpe Ratio"),
                "expected_payoff": res.get("Expected Payoff"),
                "net_profit": res.get("Net Profit"),
                "balance_final": bal_fin,
                "gross_profit": res.get("Gross Profit"),
                "gross_loss": res.get("Gross Loss"),
                "balance_dd_abs": res.get("DD Bal Abs"),
                "balance_dd_max_usd": bal_max_usd,
                "balance_dd_max_pct": bal_max_pct,
                "balance_dd_rel_pct": bal_rel_pct,
                "balance_dd_rel_usd": bal_rel_usd,
                "equity_dd_abs": res.get("DD Eq Abs"),
                "equity_dd_max_usd": eq_max_usd,
                "equity_dd_max_pct": eq_max_pct,
                "equity_dd_rel_pct": eq_rel_pct,
                "equity_dd_rel_usd": eq_rel_usd,
                "total_trades": res.get("Total Trades"),
                "total_deals": res.get("Total Deals"),
                "profit_trades_count": profit_trades[0] if isinstance(profit_trades, tuple) else profit_trades,
                "profit_trades_pct": profit_trades[1] if isinstance(profit_trades, tuple) else None,
                "loss_trades_count": loss_trades[0] if isinstance(loss_trades, tuple) else loss_trades,
                "loss_trades_pct": loss_trades[1] if isinstance(loss_trades, tuple) else None,
                "short_trades_count": short_trades[0] if isinstance(short_trades, tuple) else short_trades,
                "short_trades_win_pct": short_trades[1] if isinstance(short_trades, tuple) else None,
                "long_trades_count": long_trades[0] if isinstance(long_trades, tuple) else long_trades,
                "long_trades_win_pct": long_trades[1] if isinstance(long_trades, tuple) else None,
                "largest_profit": res.get("Largest Profit"),
                "largest_loss": res.get("Largest Loss"),
                "avg_profit": res.get("Average Profit"),
                "avg_loss": res.get("Average Loss"),
                "consec_profit_amount": consec_profit[0] if isinstance(consec_profit, tuple) else consec_profit,
                "consec_profit_trades": consec_profit[1] if isinstance(consec_profit, tuple) else None,
                "consec_loss_amount": consec_loss_amount[0] if isinstance(consec_loss_amount, tuple) else consec_loss_amount,
                "consec_loss_trades": consec_loss_amount[1] if isinstance(consec_loss_amount, tuple) else None,
                "consec_wins_trades": consec_wins[0] if isinstance(consec_wins, tuple) else consec_wins,
                "consec_wins_amount": consec_wins[1] if isinstance(consec_wins, tuple) else None,
                "consec_losses_trades": consec_losses[0] if isinstance(consec_losses, tuple) else consec_losses,
                "consec_losses_amount": consec_losses[1] if isinstance(consec_losses, tuple) else None,
                "avg_wins": res.get("Avg Wins"),
                "avg_losses": res.get("Avg Loss"),
                "corr_pf_mfe": res.get("Corr Profits MFE"),
                "corr_pf_mae": res.get("Corr Profits MAE"),
                "corr_mfe_mae": res.get("Corr MFE MAE"),
                "hold_min": res.get("Min Hold"),
                "hold_max": res.get("Max Hold"),
                "hold_avg": res.get("Avg Hold"),
                "on_tester": res.get("OnTester"),
                "z_score_val": z_v,
                "z_score_pct": z_p,
                "ahpr_val": ahpr_v,
                "ahpr_pct": ahpr_p,
                "ghpr_val": ghpr_v,
                "ghpr_pct": ghpr_p,
                "lr_corr": res.get("LR Correlation"),
                "lr_std_err": res.get("LR Std Error"),
                "margin_level": res.get("Margin Level"),
                "inputs_block": inputs,
                "inputs_list": [line for line in inputs.splitlines() if line.strip()],
            }

            # Si es fragmentado, guardamos para el consolidado final
            if is_fragmented:
                key_colector = (session_name, ea_expert_name)
                if key_colector not in colector_fragmentos:
                    # Preparar cabeceras base + inputs dinámicos
                    cabeceras_full = list(MAPEO_ESPANOL.values())
                    # Agregar inputs a las cabeceras (asumimos que primer fragmento tiene los inputs representativos)
                    for inp in flat.get("inputs_list", []):
                        if "=" in inp:
                            k_inp = inp.split("=", 1)[0].strip()
                            cabeceras_full.append(f"Input: {k_inp}")
                    colector_fragmentos[key_colector] = { "headers": cabeceras_full, "rows": [] }
                
                # Construir fila
                fila = [flat.get(k, "") for k in MAPEO_ESPANOL.keys()]
                for inp in flat.get("inputs_list", []):
                    if "=" in inp:
                        fila.append(inp.split("=", 1)[1].strip())
                
                # Guardamos como tupla (prioridad, fila) para ordenar: 0 para Full-Time, 1 para el resto
                colector_fragmentos[key_colector]["rows"].append((0 if is_full_time else 1, fila))

            flat["numeric"] = {
                "profit_factor": _to_number(res.get("Profit Factor")),
                "recovery_factor": _to_number(res.get("Recovery Factor")),
                "sharpe": _to_number(res.get("Sharpe Ratio")),
                "expected_payoff": _to_number(res.get("Expected Payoff")),
                "net_profit": _to_number(res.get("Net Profit")),
                "gross_profit": _to_number(res.get("Gross Profit")),
                "gross_loss": _to_number(res.get("Gross Loss")),
                "balance_dd_abs": _to_number(res.get("DD Bal Abs")),
                "balance_dd_max": _to_number(res.get("DD Bal Max")),
                "balance_dd_rel_pct": _to_number(res.get("DD Bal Rel")),
                "equity_dd_abs": _to_number(res.get("DD Eq Abs")),
                "equity_dd_max": _to_number(res.get("DD Eq Max")),
                "equity_dd_rel_pct": _to_number(res.get("DD Eq Rel")),
                "total_trades": _to_number(res.get("Total Trades")),
                "total_deals": _to_number(res.get("Total Deals")),
                "profit_trades_count": _to_number(flat["profit_trades_count"]),
                "profit_trades_pct": _to_number(flat["profit_trades_pct"]),
                "loss_trades_count": _to_number(flat["loss_trades_count"]),
                "loss_trades_pct": _to_number(flat["loss_trades_pct"]),
                "short_trades_count": _to_number(flat["short_trades_count"]),
                "short_trades_win_pct": _to_number(flat["short_trades_win_pct"]),
                "long_trades_count": _to_number(flat["long_trades_count"]),
                "long_trades_win_pct": _to_number(flat["long_trades_win_pct"]),
                "largest_profit": _to_number(res.get("Largest Profit")),
                "largest_loss": _to_number(res.get("Largest Loss")),
                "avg_profit": _to_number(res.get("Average Profit")),
                "avg_loss": _to_number(res.get("Average Loss")),
                "consec_profit_amount": _to_number(flat["consec_profit_amount"]),
                "consec_profit_trades": _to_number(flat["consec_profit_trades"]),
                "consec_loss_amount": _to_number(flat["consec_loss_amount"]),
                "consec_loss_trades": _to_number(flat["consec_loss_trades"]),
                "consec_wins_trades": _to_number(flat["consec_wins_trades"]),
                "consec_wins_amount": _to_number(flat["consec_wins_amount"]),
                "consec_losses_trades": _to_number(flat["consec_losses_trades"]),
                "consec_losses_amount": _to_number(flat["consec_losses_amount"]),
                "avg_wins": _to_number(res.get("Avg Wins")),
                "avg_losses": _to_number(res.get("Avg Loss")),
                "corr_pf_mfe": _to_number(res.get("Corr Profits MFE")),
                "corr_pf_mae": _to_number(res.get("Corr Profits MAE")),
                "corr_mfe_mae": _to_number(res.get("Corr MFE MAE")),
                "on_tester": _to_number(res.get("OnTester")),
                "z_score": _to_number(res.get("Z-Score")),
                "ahpr": _to_number(res.get("AHPR")),
                "ghpr": _to_number(res.get("GHPR")),
                "lr_corr": _to_number(res.get("LR Correlation")),
                "lr_std_err": _to_number(res.get("LR Std Error")),
                "margin_level_pct": _to_number(res.get("Margin Level")),
            }

            json_path = report_dir / f"{ea_file_name}.json"
            json_path.write_text(json.dumps(flat, ensure_ascii=False, indent=2), encoding="utf-8")
            
            # Generar CSV Resumen en español
            csv_resumen_path = report_dir / f"{ea_file_name}_resumen.csv"
            generar_csv_resumen(flat, csv_resumen_path)

            print(f"[OK] {htm} -> {report_dir}")
            ok += 1

            # --- Procesamiento de Imágenes Asociadas (Pack Deluxe) ---
            img_suffixes = ["", "-holding", "-hst", "-mfemae"]
            for sfx in img_suffixes:
                img_name = f"{full_stem}{sfx}.png"
                img_path = htm.parent / img_name
                if img_path.exists():
                    try:
                        # Trasladar con nombre corto y borrar original
                        target_img = report_dir / f"{ea_file_name}{sfx}.png"
                        target_img.write_bytes(img_path.read_bytes())
                        img_path.unlink()
                    except Exception as e_img:
                        print(f"[WARN] Error con imagen {img_name}: {e_img}")

            # Eliminar crudo tras éxito total
            try:
                htm.unlink()
            except:
                pass
        except Exception as e:
            print(f"[ERROR] {htm}: {e}")

    # --- FASE FINAL: Generar Consolidados de Fragmentación ---
    for (s_name, ea_name), data in colector_fragmentos.items():
        try:
            if ea_cli and pass_cli:
                # En modo discrecional, el resumen va dentro de la carpeta del pass
                folder_ea_discr = f"{ea_cli}___discrecional"
                resumen_dir = out_root / s_name / folder_ea_discr / str(pass_cli) / "1_RESUMEN"
            else:
                resumen_dir = out_root / s_name / ea_name / "1_RESUMEN"
            
            resumen_dir.mkdir(parents=True, exist_ok=True)
            resumen_file = resumen_dir / "resumen-fragmentacion.csv"
            
            # Ordenar filas: Full-time (prioridad 0) primero, luego el resto por Periodo (índice 2)
            # x[0] es la prioridad, x[1] es la fila de datos
            filas_ordenadas = sorted(data["rows"], key=lambda x: (x[0], x[1][2])) 
            
            with resumen_file.open("w", newline="", encoding="utf-8-sig") as f:
                writer = csv.writer(f)
                writer.writerow(data["headers"])
                for p, r in filas_ordenadas:
                    writer.writerow(r)
            
            print(f"[CONSOLIDADO OK] -> {resumen_file}")
        except Exception as e_cons:
            print(f"[ERROR CONSOLIDADO] {ea_name}: {e_cons}")

    print(f"\n[RESUMEN HTM] {ok}/{len(htm_files)} reportes convertidos. Salida en {out_root}")


def main():
    parser = argparse.ArgumentParser(description="Normalizador master: XML->CSV y HTM->MD/JSON.")
    parser.add_argument("--xml", action="store_true", help="Solo convertir XML.")
    parser.add_argument("--htm", action="store_true", help="Solo procesar HTM.")
    parser.add_argument("--ea", type=str, help="Nombre del EA para modo discrecional.")
    parser.add_argument("--pass_id", type=str, help="ID de Pass para modo discrecional.")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent.parent

    do_xml = args.xml or not args.htm  # si no se pide solo htm, corre xml por defecto
    do_htm = args.htm or not args.xml  # si no se pide solo xml, corre htm por defecto

    if do_xml:
        run_xml(repo_root)
    if do_htm:
        run_htm(repo_root, ea_cli=args.ea, pass_cli=args.pass_id)


if __name__ == "__main__":
    main()
