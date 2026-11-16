#!/usr/bin/env python3
"""Construye un Flow Kestra con 10 obligaciones y 6 pagos exclusivamente sintéticos.

No conecta con SQL Server, Snowflake, Kestra ni la red. No produce datos reales.
La generación es determinista y compatible con ingesta/contract.json y Raw.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = json.loads((ROOT / "ingesta" / "contract.json").read_text(encoding="utf-8"))
DEST = ROOT / "kestra" / "flows" / "demo_sintetico_raw.yml"
LOTE = "11111111-2222-4333-8444-555555555555"  # UUID fijo reservado para la DEMO
CAPTURA = "TO_TIMESTAMP_TZ('2026-11-15T18:00:00.000+00:00')::TIMESTAMP_TZ(3)"
VERSION = "synthetic-v1"


def make_select(spec, values, source):
    """Proyección explícita. Prohíbe columnas no declaradas."""
    cols = [f["name"] for f in spec] + ["LOTE_ID", "CAPTURADO_EN", "ID_VERSION"]
    if set(values) != set(cols):
        raise ValueError(f"Proyección incorrecta: {set(cols) ^ set(values)}")
    select_sql = ",\n        ".join(f"{values[col]} AS {col}" for col in cols)
    return cols, f"SELECT\n        {select_sql}\n    FROM {source}"


def merge(table, columns, inner, key):
    names = ", ".join(columns)
    source_names = ", ".join("s." + c for c in columns)
    return (f"MERGE INTO PSET2_DEMO_SINTETICO.RAW.{table} AS t\n"
            f"USING (\n    {inner}\n) AS s\n"
            f"ON t.LOTE_ID = s.LOTE_ID AND t.{key} = s.{key}\n"
            f"WHEN NOT MATCHED THEN INSERT ({names}) VALUES ({source_names})")


def sql_obligaciones():
    zero = "0::NUMBER(16,2)"
    values = {f["name"]: zero if f["type"] == "money" else "NULL" for f in CONTRACT["raw"]["obligaciones"]}
    values.update(
        OBLIGACION_ID="LOWER(SHA2('PSET2-DEMO-OBL-' || TO_VARCHAR(n),256))",
        ANIO_FISCAL="2024::NUMBER(4,0)",
        IM_PRINCIPAL="(100 + n * 10)::NUMBER(16,2)",
        IM_BOMBEROS="1.25::NUMBER(16,2)",
        IM_TOTAL="(101.25 + n * 10)::NUMBER(16,2)",
        # Anomalía intencional NO identificable: una emisión nula para mostrar DQ warning.
        IM_FECHA_EMISION="IFF(n=10, NULL::DATE, '2024-01-05'::DATE)",
        IM_FECHA_CREA="'2024-01-02'::DATE",
        IM_FECHA_ULTMODIFIC="'2024-01-09'::DATE",
        IM_FECHA_PAGO="IFF(n IN (1,2,4,6),DATEADD('day',n,'2024-06-20'::DATE),NULL::DATE)",
        IM_FECHA_ANULACION="NULL::DATE",
        IM_ESTADO="'F'::VARCHAR(1)",
        IM_CONDICION="'N'::VARCHAR(1)",
        TIPO_DOC="'FA'::VARCHAR(2)",
        LOTE_ID=f"'{LOTE}'::VARCHAR(36)",
        CAPTURADO_EN=CAPTURA,
        ID_VERSION=f"'{VERSION}'::VARCHAR(16)",
    )
    cols, inner = make_select(CONTRACT["raw"]["obligaciones"], values,
                              "(SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS n FROM TABLE(GENERATOR(ROWCOUNT => 10)))")
    return merge("RAW_URBANO_OBLIGACIONES",cols,inner,"OBLIGACION_ID")


def sql_movimientos():
    zero = "0::NUMBER(16,2)"
    values = {f["name"]: zero if f["type"] == "money" else "NULL" for f in CONTRACT["raw"]["movimientos"]}
    values.update(
        MOVIMIENTO_ID="LOWER(SHA2('PSET2-DEMO-MOV-' || TO_VARCHAR(k),256))",
        OBLIGACION_ID="LOWER(SHA2('PSET2-DEMO-OBL-' || TO_VARCHAR(n),256))",
        IMP_FECHA_PAGO="DATEADD('day',k,'2024-06-20'::DATE)",
        IMP_PRINCIPAL="(18 + k * 5)::NUMBER(16,2)",
        IMP_TOTAL="(18 + k * 5)::NUMBER(16,2)",
        SALDO="NULL::NUMBER(16,2)",  # saldo histórico no reconstruido
        IMP_FECHA_EMISION="'2024-01-05'::DATE",
        IMP_FECHA_CREA="'2024-01-02'::DATE",
        IMP_FECHA_ULTMODIFIC="DATEADD('day',k,'2024-06-20'::DATE)",
        IMP_FECHA_ANULACION="NULL::DATE",
        FECHA_PROCESO="DATEADD('day',k,'2024-06-20'::DATE)",
        IMP_ESTADO="'F'::VARCHAR(1)",
        IMP_CONDICION="'N'::VARCHAR(1)",
        IMP_TIPO="'A'::VARCHAR(1)",
        TIPO_DOC="IFF(k IN (1,2,5),'AB','FA')::VARCHAR(2)",
        LOTE_ID=f"'{LOTE}'::VARCHAR(36)",
        CAPTURADO_EN=CAPTURA,
        ID_VERSION=f"'{VERSION}'::VARCHAR(16)",
    )
    cols, inner = make_select(CONTRACT["raw"]["movimientos"],values,
                              "(SELECT column1 AS k, column2 AS n FROM VALUES (1,1),(2,1),(3,2),(4,4),(5,6),(6,6))")
    return merge("RAW_URBANO_MOVIMIENTOS_PAGO",cols,inner,"MOVIMIENTO_ID")


def sql_ledger():
    sql = f"""MERGE INTO PSET2_DEMO_SINTETICO.RAW.INGESTA_LOTES AS t
USING (
    SELECT
      '{LOTE}'::VARCHAR(36) AS LOTE_ID,
      '2024-01-01'::DATE AS FISCAL_DESDE,
      '2025-01-01'::DATE AS FISCAL_HASTA,
      10::NUMBER(9,0) AS LIMITE,
      {CAPTURA} AS CAPTURADO_EN,
      '{VERSION}'::VARCHAR(16) AS ID_VERSION,
      'raw-v1'::VARCHAR(16) AS CONTRATO_VERSION,
      LOWER(SHA2('PUBLIC-SYNTHETIC-KEY-TAG-V1',256)) AS KEY_TAG,
      10::NUMBER(16,0) AS OBLIGACIONES,
      6::NUMBER(16,0) AS MOVIMIENTOS,
      LOWER(SHA2('PSET2-DEMO-CONTRACT-10-6-v1',256)) AS CONTENIDO_SHA256,
      CURRENT_TIMESTAMP()::TIMESTAMP_TZ(3) AS COMMIT_EN
    WHERE
      (SELECT COUNT(*) FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_OBLIGACIONES
       WHERE LOTE_ID='{LOTE}')=10
      AND (SELECT COUNT(*) FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_MOVIMIENTOS_PAGO
           WHERE LOTE_ID='{LOTE}')=6
      AND (SELECT COUNT(DISTINCT OBLIGACION_ID)
           FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_OBLIGACIONES
           WHERE LOTE_ID='{LOTE}')=10
      AND (SELECT COUNT(DISTINCT MOVIMIENTO_ID)
           FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_MOVIMIENTOS_PAGO
           WHERE LOTE_ID='{LOTE}')=6
      AND NOT EXISTS (
         SELECT 1 FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_MOVIMIENTOS_PAGO p
         WHERE p.LOTE_ID='{LOTE}' AND NOT EXISTS (
           SELECT 1 FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_OBLIGACIONES o
           WHERE o.LOTE_ID=p.LOTE_ID AND o.OBLIGACION_ID=p.OBLIGACION_ID))
) AS s
ON t.LOTE_ID=s.LOTE_ID
WHEN NOT MATCHED THEN INSERT (
  LOTE_ID,FISCAL_DESDE,FISCAL_HASTA,LIMITE,CAPTURADO_EN,ID_VERSION,
  CONTRATO_VERSION,KEY_TAG,OBLIGACIONES,MOVIMIENTOS,CONTENIDO_SHA256,COMMIT_EN)
VALUES (
  s.LOTE_ID,s.FISCAL_DESDE,s.FISCAL_HASTA,s.LIMITE,s.CAPTURADO_EN,s.ID_VERSION,
  s.CONTRATO_VERSION,s.KEY_TAG,s.OBLIGACIONES,s.MOVIMIENTOS,s.CONTENIDO_SHA256,s.COMMIT_EN)"""
    return sql


def sql_validar():
    return f"""SELECT c.*,
  IFF(c.OBLIGACIONES=10 AND c.MOVIMIENTOS=6 AND c.LOTES=1 AND c.HUERFANOS=0,
      'OK','ERROR') AS ESTADO
FROM (
SELECT
  (SELECT COUNT(*) FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_OBLIGACIONES
   WHERE LOTE_ID='{LOTE}') AS OBLIGACIONES,
  (SELECT COUNT(*) FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_MOVIMIENTOS_PAGO
   WHERE LOTE_ID='{LOTE}') AS MOVIMIENTOS,
  (SELECT COUNT(*) FROM PSET2_DEMO_SINTETICO.RAW.INGESTA_LOTES
   WHERE LOTE_ID='{LOTE}' AND COMMIT_EN IS NOT NULL) AS LOTES,
  (SELECT COUNT(*) FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_MOVIMIENTOS_PAGO p
   WHERE p.LOTE_ID='{LOTE}' AND NOT EXISTS (
     SELECT 1 FROM PSET2_DEMO_SINTETICO.RAW.RAW_URBANO_OBLIGACIONES o
     WHERE o.LOTE_ID=p.LOTE_ID AND o.OBLIGACION_ID=p.OBLIGACION_ID)) AS HUERFANOS
) AS c"""


def render():
    common = """    type: io.kestra.plugin.jdbc.snowflake.Query
    url: \"{{ secret('SNOWFLAKE_JDBC_URL') }}\"
    username: PSET2_PIPELINE_SVC
    privateKey: \"{{ secret('SNOWFLAKE_PRIVATE_KEY') }}\"
    privateKeyPassword: \"{{ secret('SNOWFLAKE_PRIVATE_KEY_PASSWORD') }}\"
    role: PSET2_PIPELINE_ROLE
    warehouse: COMPUTE_WH
    database: PSET2_DEMO_SINTETICO
    schema: RAW
"""
    tasks = []
    for task_id, query, fetch in [
        ("insertar_obligaciones_ficticias",sql_obligaciones(),None),
        ("insertar_movimientos_ficticios",sql_movimientos(),None),
        ("confirmar_lote_sintetico",sql_ledger(),None),
        ("comprobar_lote_sintetico",sql_validar(),"FETCH_ONE"),
    ]:
        content = f"  - id: {task_id}\n" + common
        if fetch: content += f"    fetchType: {fetch}\n"
        content += "    sql: |\n" + "\n".join("      "+line for line in query.splitlines()) + "\n"
        tasks.append(content)
    checks = """  - id: exigir_conteos
    type: io.kestra.plugin.core.execution.Assert
    conditions:
      - \"{{ outputs.comprobar_lote_sintetico.row.ESTADO == 'OK' }}\"
    errorMessage: DEMO_SINTETICA_NO_CONCILIA
"""
    return ("# DEMOSTRACION CON DATOS FICTICIOS. Nunca accede a SQL Server municipal.\n"
            "id: demo_sintetico_raw\nnamespace: usfq.pset2\n"
            "description: 'DEMO SINTETICA: genera obligaciones/pagos ficticios y los carga en Snowflake Raw.'\n"
            "concurrency:\n  limit: 1\n  behavior: QUEUE\n"
            "tasks:\n" + "".join(tasks) + checks)


if __name__ == "__main__":
    DEST.parent.mkdir(parents=True,exist_ok=True)
    DEST.write_text(render(),encoding="utf-8")
    print(f"Flujo sintetico generado: {DEST.relative_to(ROOT)}")
    print("Sin red, sin datos privados y sin ejecutar cargas.")
