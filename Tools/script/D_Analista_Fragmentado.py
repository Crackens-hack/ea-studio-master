import os
import sys
import shutil
import pandas as pd
import configparser
import argparse
from datetime import datetime

# ==============================================================================
# CONFIGURACIÓN DE RUTAS
# ==============================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR   = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
CONF_FILE  = os.path.join(SCRIPT_DIR, 'Config-Filters', 'criterios-analisis-fragmentado.conf')
MODE_NAME  = 'single_mode_fragmentado_VALIDACION_STRESS_ANUALIZADO'
NORMALIZED = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Normalizados', MODE_NAME)
ANALIZADOS = os.path.join(ROOT_DIR, 'BUILD', 'RESULTADOS', 'Reportes-Analizados')
CONSTRUCCION = os.path.join(ROOT_DIR, 'BUILD', '1_BUILDING', '01_ea_construccion')
PORTAFOLIO   = os.path.join(ROOT_DIR, 'BUILD', '1_BUILDING', '03_PORTAFOLIO')

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
        # Eliminar acentos basicos
        clean = clean.replace('á', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o').replace('ú', 'u')
        # Diferenciar explícitamente $ y % antes de limpiar
        clean = clean.replace('%', 'pct').replace('$', 'usd')
        # Limpiar simbolos y espacios
        clean = clean.replace(' ', '_').replace('(', '').replace(')', '').replace(',', '')
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

def find_cartucho_folder(ea_name, pass_id):
    """Localiza la carpeta del cartucho original en los reportes analizados."""
    opt_mode = 'genetica70_fw30_OPTIMIZACION_GENETICA_FW'
    search_root = os.path.join(ANALIZADOS, opt_mode, ea_name, '1_CLUSTERS_ELITE', 'CARGADOR')
    if os.path.exists(search_root):
        for folder in os.listdir(search_root):
            if f"P{pass_id}" in folder:
                return os.path.join(search_root, folder)
    return None

def main():
    parser = argparse.ArgumentParser(description="Juez Forense - Analista Fragmentado")
    parser.add_argument("--ea", required=True, help="Nombre del EA")
    parser.add_argument("--pass_id", required=True, help="ID del Pass a auditar")
    args = parser.parse_args()

    ea_name = args.ea
    pass_id = str(args.pass_id)

    # Construir ruta al resumen
    pass_folder_name = f"{ea_name}___discrecional"
    pass_dir = os.path.join(NORMALIZED, pass_folder_name, pass_id)
    resumen_path = os.path.join(pass_dir, '1_RESUMEN', 'resumen-fragmentacion.csv')

    log_path = os.path.join(pass_dir, "resumen-auditacion-jueza.txt")
    veredicto = "No"
    razon_final = ""

    print(f"\n👨‍⚖️  AUDITORÍA DE ÉLITE: {ea_name} (Pass {pass_id})")
    print("-" * 40)

    if not os.path.exists(resumen_path):
        razon_final = f"Error: No existe el resumen consolidado."
    else:
        try:
            df = pd.read_csv(resumen_path)
            df = normalize_cols(df)
            filters = load_filters()

            if df.empty:
                razon_final = "Error: El CSV esta vacio."
            else:
                ft = df.iloc[0]
                fragments = df.iloc[1:]

                profit_total = clean_val(ft.get('beneficio_neto', 0.0))
                pf_total     = clean_val(ft.get('factor_de_beneficio', 0.0))
                dd_total     = clean_val(ft.get('dd_equidad_maximo_pct', 0.0))
                
                # Nuevas metricas sugeridas
                sharpe      = clean_val(ft.get('ratio_sharpe', 0.0))
                rf          = clean_val(ft.get('factor_de_recuperacion', 0.0))
                payoff      = clean_val(ft.get('pago_esperado', 0.0))
                total_trades = int(clean_val(ft.get('total_de_operaciones', 0.0)))

                # --- Auditoria Full Time ---
                if profit_total < filters['ft_min_profit']:
                    razon_final = f"Falla Full-Time: Profit Negativo (${profit_total:.2f})"
                elif pf_total < filters['ft_min_pf']:
                    razon_final = f"Falla Full-Time: PF Bajo ({pf_total:.2f})"
                elif dd_total > filters['ft_max_dd']:
                    razon_final = f"Falla Full-Time: DD Excesivo ({dd_total:.2f}%)"
                else:
                    # --- Auditoria de Fragmentos (Consistencia Sangrienta) ---
                    fail_frag = False
                    trades_por_anyo = []
                    pfs_por_anyo = []
                    profits_por_anyo = []
                    dds_por_anyo = []
                    wr_por_anyo = []
                    
                    for i, row in fragments.iterrows():
                        y_trades = clean_val(row.get('total_de_operaciones', 0.0))
                        y_pf     = clean_val(row.get('factor_de_beneficio', 0.0))
                        y_profit = clean_val(row.get('beneficio_neto', 0.0))
                        y_dd     = clean_val(row.get('dd_equidad_maximo_pct', 0.0))
                        y_wr     = clean_val(row.get('op_rentables_pct', 0.0))
                        periodo  = row.get('periodo', f'Fragmento_{i}')
                        
                        trades_por_anyo.append(y_trades)
                        profits_por_anyo.append(y_profit)
                        dds_por_anyo.append(y_dd)
                        wr_por_anyo.append(y_wr)
                        if y_trades > 0: pfs_por_anyo.append(y_pf)

                        if y_profit < -abs(filters['max_y_loss']):
                            razon_final = f"Falla Consistencia: Ruina en {periodo} (${y_profit:.2f})"
                            fail_frag = True
                            break
                        if y_dd > filters['max_y_dd']:
                            razon_final = f"Falla Consistencia: DD de Quiebra en {periodo} ({y_dd:.2f}%)"
                            fail_frag = True
                            break
                    
                    if not fail_frag:
                        # Extraer Perfil Tactico y Calidad
                        winrate      = ft.get('op_rentables_pct', 'N/A')
                        holdtime     = ft.get('tiempo_retencion_promedio', 'N/A')
                        z_score      = clean_val(ft.get('z-score_valor', 0.0))
                        linealidad   = clean_val(ft.get('correlacion_lr', 0.0))
                        error_lr     = clean_val(ft.get('error_estandar_lr', 0.0))
                        
                        # Vigilantes del Margen y Calidad Operativa
                        corr_mae     = clean_val(ft.get('correlacion_beneficios_mae', 0.0))
                        max_losing   = int(clean_val(ft.get('trades_racha_perdidas_consec', 0.0)))
                        
                        # Metricas Financieras de Detalle
                        avg_win  = clean_val(ft.get('ganancia_promedio', 0.0))
                        avg_loss = abs(clean_val(ft.get('perdida_promedio', 0.0)))
                        ratio_rr = avg_win / avg_loss if avg_loss > 0 else 0
                        
                        # Calcular promedios y extremos
                        num_anyos   = len(fragments)
                        num_meses   = num_anyos * 12
                        avg_profit_mes = profit_total / num_meses if num_meses > 0 else 0
                        
                        avg_anual      = sum(trades_por_anyo) / len(trades_por_anyo) if trades_por_anyo else 0
                        avg_profit_an  = sum(profits_por_anyo) / len(profits_por_anyo) if profits_por_anyo else 0
                        avg_pf         = sum(pfs_por_anyo) / len(pfs_por_anyo) if pfs_por_anyo else 0
                        avg_wr         = sum(wr_por_anyo) / len(wr_por_anyo) if wr_por_anyo else 0
                        
                        worst_profit = min(profits_por_anyo) if profits_por_anyo else 0
                        worst_wr     = min(wr_por_anyo) if wr_por_anyo else 0
                        max_y_dd     = max(dds_por_anyo) if dds_por_anyo else 0
                        
                        # Indice de Estabilidad (Desviacion sobre promedio)
                        import math
                        if num_anyos > 1:
                            var_profit = sum((p - avg_profit_an)**2 for p in profits_por_anyo) / num_anyos
                            estabilidad = 100 - (math.sqrt(var_profit) / (avg_profit_an if avg_profit_an != 0 else 1) * 100)
                        else:
                            estabilidad = 100

                        # Calificacion Conceptual del Juez
                        if linealidad > 0.90 and estabilidad > 50 and corr_mae > 0.40:
                            perfil = "ROBUSTO [Alta Linealidad y Defensa]"
                        elif linealidad > 0.85 and profit_total > filters['ft_min_profit'] * 5:
                            perfil = "EXPLOSIVO [Alto Rendimiento / Volatilidad]"
                        elif pf_total > 2.0:
                            perfil = "QUIRÚRGICO [Alta Eficiencia / Pocos Trades]"
                        else:
                            perfil = "ESTÁNDAR [Cumple Requisitos]"

                        veredicto = "Yes"
                        razon_final = (
                            f"ÉLITE CERTIFICADO. Sometido a {num_anyos} fragmentos anuales.\n"
                            f"ESTADO: {perfil}\n"
                            f"[Métricas Full-Time: Profit ${profit_total:.2f} (PF {pf_total:.2f}) | DD {dd_total:.2f}% | RF {rf:.2f} | Sharpe {sharpe:.2f}]\n"
                            f"[Perfil Táctico: WinRate Avg {avg_wr:.1f}% (Peor {worst_wr:.1f}%) | Ratio R/R {ratio_rr:.2f} | Linealidad LR {linealidad:.2f}]\n"
                            f"[Vigilancia Margen: Corr MAE {corr_mae:.2f} | Max Losing Streak: {max_losing} trades | Error LR {error_lr:.2f}]\n"
                            f"[Consistencia: PF Promedio {avg_pf:.2f} | Estabilidad Anual {estabilidad:.1f}% | Z-Score {z_score:.2f}]\n"
                            f"[Escalabilidad: ${avg_profit_mes:.2f} / mes | Cadencia {avg_anual:.1f} trades/año]\n"
                            f"[Estrés Histórico: Peor Año Profit ${worst_profit:.2f} | Peor Año DD {max_y_dd:.2f}%].\n"
                            f"Supervivencia 100% confirmada sin ruina anual."
                        )

        except Exception as e:
            razon_final = f"Error Analisis: {str(e)}"

    # Finalizar Veredicto en Texto
    with open(log_path, 'w', encoding='utf-8') as f:
        f.write(f"ea={ea_name}\npass={pass_id}\nseleccionado={veredicto}\nresumenn={razon_final}\n")

    print(f"VEREDICTO: {veredicto}")
    print(f"MOTIVO: {razon_final}")

    # ======================================================================
    # PROMOCIÓN AL PORTAFOLIO 🏆 (Solo si el veredicto es Yes)
    # ======================================================================
    if veredicto == "Yes":
        ea_portfolio_dir = os.path.join(PORTAFOLIO, ea_name)
        os.makedirs(ea_portfolio_dir, exist_ok=True)
        
        # 1. Extraer Cartucho Completo (Renombrando a PASS_ELITE_XXXX)
        dest_pass_dir = os.path.join(ea_portfolio_dir, f"PASS_ELITE_{pass_id}")
        source_cartucho = find_cartucho_folder(ea_name, pass_id)
        
        if source_cartucho and os.path.exists(source_cartucho):
            if os.path.exists(dest_pass_dir): shutil.rmtree(dest_pass_dir)
            shutil.copytree(source_cartucho, dest_pass_dir)
            
            # Copiar también el resumen-fragmentacion.csv y el acta del Juez dentro de la carpeta Elite
            shutil.copy2(resumen_path, os.path.join(dest_pass_dir, "resumen-fragmentacion-verificado.csv"))
            shutil.copy2(log_path, os.path.join(dest_pass_dir, "sentencia-juez.txt"))
            
            print(f"   🚀 Cartucho extraído y promovido a PASS_ELITE_{pass_id}")
        else:
            print(f"   ⚠️  Advertencia: No se encontró el cartucho original en CARGADOR.")

        # 2. Salvaguarda de ADN (Archivos base de construcción)
        # Copia todos los archivos que coincidan con el nombre del EA desde construcción
        if os.path.exists(CONSTRUCCION):
            for file in os.listdir(CONSTRUCCION):
                if file.startswith(ea_name):
                    src_file = os.path.join(CONSTRUCCION, file)
                    dest_file = os.path.join(ea_portfolio_dir, file)
                    shutil.copy2(src_file, dest_file)
            print(f"   🧬 ADN Base sincronizado en la raíz del Portafolio.")

    print("-" * 40)

if __name__ == '__main__':
    main()
