import duckdb
import json

con = duckdb.connect()
bt = 'RESULTADOS/Reportes-Normalizados/genetica70_fw30/Apex_S_Cycles_V1_genetica70_fw30.parquet'
fw = 'RESULTADOS/Reportes-Normalizados/genetica70_fw30/Apex_S_Cycles_V1_genetica70_fw30.forward.parquet'

ids = [2853, 2664]

query = f'''
SELECT 
    b.pass, 
    b.result as bt_res, 
    f.forward_result as fw_res, 
    b.profit as bt_prof, 
    f.profit as fw_prof, 
    b.profit_factor as bt_pf, 
    f.profit_factor as fw_pf, 
    b.equity_dd as bt_dd, 
    f.equity_dd as fw_dd, 
    b.trades as bt_tr, 
    f.trades as fw_tr, 
    b.sharpe_ratio as bt_sharpe, 
    f.sharpe_ratio as fw_sharpe, 
    b.recovery_factor as bt_rf, 
    f.recovery_factor as fw_rf, 
    b.expected_payoff as bt_ep, 
    f.expected_payoff as fw_ep, 
    b.custom as bt_cust, 
    f.custom as fw_cust,
    b.inprisksniper, b.inpsl_pips, b.inpimaginarytp, b.inptrailingtrigger,
    b.inpriskmaximizer, b.inptrailingstep, b.inpemaperiod, b.inpfractalbars, b.inpatrmultiplier
FROM '{bt}' b 
JOIN '{fw}' f ON b.pass = f.pass 
WHERE b.pass IN ({','.join(map(str, ids))})
'''

df = con.execute(query).fetchdf()
print(df.to_json(orient='records'))
