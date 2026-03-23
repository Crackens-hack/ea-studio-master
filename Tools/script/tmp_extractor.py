import duckdb
import json

db = duckdb.connect()
filePath = "BUILD/RESULTADOS/Reportes-Normalizados/genetica70_fw30_OPTIMIZACION_GENETICA_FW/Apex_S_Cycles_V3_genetica70_fw30_OPTIMIZACION_GENETICA_FW.forward.parquet"
df = db.execute(f"SELECT * FROM '{filePath}' WHERE Pass IN (5174, 7041, 526)").df()

print(df.to_json(orient='records'))
