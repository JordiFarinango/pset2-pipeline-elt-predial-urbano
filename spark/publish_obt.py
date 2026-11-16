"""I/O Snowflake y lanzamiento del Spark existente; no transforma la OBT en SQL.

Ejecucion exclusivamente manual con Run-OBT.ps1. No mostrar payloads ni excepciones
del conector. Solo Gold/ledger de lectura y OBT de escritura.
"""
import argparse
import datetime as dt
from decimal import Decimal
import importlib.metadata
import json
import logging
import os
from pathlib import Path
import subprocess
import sys
import uuid
from obt_common import SPEC, ObtError, encode, decode, timestamp
from run_container import SAFE_SPARK_ERRORS

logging.disable(logging.CRITICAL)
ROOT = Path(__file__).resolve().parent.parent
DEMO_MODE = os.environ.get("PSET2_SYNTHETIC_DEMO") == "I_ACKNOWLEDGE_SYNTHETIC"
DB_NAME = "PSET2_DEMO_SINTETICO" if DEMO_MODE else "PSET2_CAYAMBE"
DEST = f"{DB_NAME}.OBT.OBT_URBANO_OBLIGACIONES"
LEDGER = f"{DB_NAME}.RAW.INGESTA_LOTES"
GOLD = f"{DB_NAME}.GOLD."


def check(condition, code):
    if not condition:
        raise ObtError(code)


def connect():
    import snowflake.connector
    check(importlib.metadata.version("snowflake-connector-python")=="5.2.0","DEPENDENCIA_HOST_NO_FIJADA")
    # El modo DEMO acepta la misma cuenta, pero NUNCA la misma base.
    account = os.environ.get("PSET2_DEMO_ACCOUNT", "").upper() if DEMO_MODE else "XSDIWIV-XZ59673"
    check(bool(account), "CUENTA_DEMO_REQUERIDA")
    check(not DEMO_MODE or DB_NAME == "PSET2_DEMO_SINTETICO", "DEMO_DEBE_USAR_BD_AISLADA")
    expected = {"DBT_SNOWFLAKE_ACCOUNT":account,"DBT_SNOWFLAKE_USER":"PSET2_PIPELINE_SVC",
                "DBT_SNOWFLAKE_ROLE":"PSET2_PIPELINE_ROLE","DBT_SNOWFLAKE_DATABASE":DB_NAME,
                "DBT_SNOWFLAKE_WAREHOUSE":"COMPUTE_WH"}
    for key,value in expected.items():
        check(os.environ.get(key, "").upper()==value,"DESTINO_NO_AUTORIZADO")
    private = Path(os.environ["DBT_ENV_SECRET_PRIVATE_KEY_PATH"])
    check(private.is_absolute() and ROOT not in private.resolve().parents,
          "CLAVE_DEBE_ESTAR_FUERA_DEL_PROYECTO")
    return snowflake.connector.connect(
        account=account,user="PSET2_PIPELINE_SVC",role="PSET2_PIPELINE_ROLE",
        database=DB_NAME,warehouse="COMPUTE_WH",schema="OBT",
        authenticator="SNOWFLAKE_JWT",private_key_file=str(private),
        private_key_file_pwd=os.environ["DBT_ENV_SECRET_PRIVATE_KEY_PASSPHRASE"],
        autocommit=False,login_timeout=30,network_timeout=60,
        session_parameters={"QUERY_TAG":"pset2_spark_obt","STATEMENT_TIMEOUT_IN_SECONDS":60})


def check_context(cur):
    cur.execute("SELECT CURRENT_USER(),CURRENT_ROLE(),CURRENT_DATABASE(),CURRENT_WAREHOUSE()")
    check(cur.fetchone()==("PSET2_PIPELINE_SVC","PSET2_PIPELINE_ROLE",DB_NAME,"COMPUTE_WH"),
          "CONTEXTO_SNOWFLAKE_INVALIDO")


def check_schema(cur, schema, table, fields):
    cur.execute(
        "SELECT COLUMN_NAME,DATA_TYPE,CHARACTER_MAXIMUM_LENGTH,NUMERIC_PRECISION,NUMERIC_SCALE,DATETIME_PRECISION "
        f"FROM {DB_NAME}.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s",
        (schema,table))
    actual = {r[0].lower(): r[1:] for r in cur.fetchall()}
    check(set(actual)=={n for n,_ in fields},"COLUMNAS_FUERA_DEL_CONTRATO")
    widths = {"id":64,"uuid":36,"version":16,"code1":1,"code2":2,"origen":10}
    for name,kind in fields:
        data_type,width,precision,scale,date_precision = actual[name]
        if kind in widths:
            ancho_valido = (
                width == widths[kind]
                or (
                    schema == "GOLD"
                    and name == "contexto_key"
                    and kind == "id"
                    and width == 128
                )
            )
            check(data_type == "TEXT" and ancho_valido, "TIPO_TEXTO_INESPERADO")
        elif kind.startswith("money"):
            check(data_type=="NUMBER" and precision==(16 if kind=="money16" else 38) and scale==2,
                  "PRECISION_MONETARIA_INVALIDA")
        elif kind in ("year","count","date_key","smallint"):
            check(data_type=="NUMBER" and scale==0,"TIPO_ENTERO_INESPERADO")
        elif kind=="date":
            check(data_type=="DATE","TIPO_FECHA_INESPERADO")
        elif kind=="timestamp":
            check(data_type=="TIMESTAMP_TZ" and date_precision==3,"TIPO_CAPTURA_INESPERADO")
        elif kind=="bool":
            check(data_type=="BOOLEAN","TIPO_BOOLEANO_INESPERADO")


def prepare(cur):
    # DDL solo con --setup, nunca dentro de una publicacion.
    text = (ROOT/"docs"/"obt_setup.sql").read_text(encoding="utf-8")
    if DEMO_MODE:
        # El SQL local original se reorienta solamente a la base ficticia.
        text = text.replace("USE DATABASE PSET2_CAYAMBE;", "USE DATABASE PSET2_DEMO_SINTETICO;")
    text = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("--"))
    for statement in text.split(";"):
        if statement.strip():
            cur.execute(statement)
    check_schema(cur,"OBT","OBT_URBANO_OBLIGACIONES",SPEC["output"])


def fetch_source(cur, args):
    cur.execute(f"SELECT OBLIGACIONES,MOVIMIENTOS,CAPTURADO_EN,ID_VERSION,COMMIT_EN "
                f"FROM {LEDGER} WHERE LOTE_ID=%s",(args.lote_id,))
    rows = cur.fetchall()
    check(len(rows)==1 and rows[0][4] is not None,"LOTE_INEXISTENTE_NO_CONFIRMADO_O_DUPLICADO")
    row = rows[0]
    n_u,n_p = int(row[0]),int(row[1])
    check(0<n_u<=SPEC["limits"]["obligaciones"] and 0<=n_p<=SPEC["limits"]["movimientos"],
          "LOTE_SUPERA_TOPE_LOCAL")
    if args.expected_obligaciones is not None:
        check(n_u==args.expected_obligaciones,"OBLIGACIONES_ESPERADAS_NO_COINCIDEN")
    if args.expected_movimientos is not None:
        check(n_p==args.expected_movimientos,"MOVIMIENTOS_ESPERADOS_NO_COINCIDEN")
    payload = {"lote_id":args.lote_id,"capturado_en":timestamp(row[2]),"id_version":row[3],
               "procesado_en":dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds"),
               "esperadas":{"obligaciones":n_u,"movimientos":n_p},"sources":{}}
    for name,spec in SPEC["sources"].items():
        check_schema(cur,"GOLD",spec["table"],spec["columns"])
        cur.execute(f"SELECT COUNT(*) FROM {GOLD}{spec['table']} WHERE LOTE_ID=%s",(args.lote_id,))
        count = int(cur.fetchone()[0])
        expected = n_u if name=="obligaciones" else n_p if name=="movimientos" else None
        if expected is not None:
            check(count==expected,"GOLD_NO_CONTIENE_EL_LOTE_COMPLETO")
        else:
            check(0<count<=SPEC["limits"]["dimensiones"],"DIMENSION_VACIA_O_EXCESIVA")
        columns = ",".join(n.upper() for n,_ in spec["columns"])
        cur.execute(f"SELECT {columns} FROM {GOLD}{spec['table']} WHERE LOTE_ID=%s ORDER BY {spec['key']}",
                    (args.lote_id,))
        records = []
        for row in cur:
            records.append({n:encode(v,k) for (n,k),v in zip(spec["columns"],row)})
            check(len(records)<=count,"GOLD_CAMBIO_DURANTE_LECTURA")
        check(len(records)==count,"GOLD_CAMBIO_DURANTE_LECTURA")
        payload["sources"][name] = records
    return payload


def execute_spark(payload):
    body = json.dumps(payload,separators=(",",":"),ensure_ascii=True).encode("ascii")
    check(len(body)<=SPEC["limits"]["bytes"],"SNAPSHOT_SUPERA_TOPE_BYTES")
    # No credenciales SF/HMAC en el entorno o argumentos del cliente Docker.
    allowed = (
        "PATH", "SystemRoot", "WINDIR", "USERPROFILE",
        "HOME", "APPDATA", "LOCALAPPDATA",
        "TEMP", "TMP", "COMSPEC", "PATHEXT",
        "DOCKER_CONFIG",
        "ProgramFiles", "ProgramData",
        "DOCKER_CLI_PLUGIN_EXTRA_DIRS"
    )
    environment = {k:os.environ[k] for k in allowed if k in os.environ}
    # Impedir enviar datos a un contexto Docker remoto configurado por accidente.
    pipe = os.environ.get("PSET2_DOCKER_PIPE","npipe:////./pipe/dockerDesktopLinuxEngine")
    check(pipe in ("npipe:////./pipe/dockerDesktopLinuxEngine","npipe:////./pipe/docker_engine"),
          "SOLO_DOCKER_DESKTOP_LOCAL")
    try:
        result = subprocess.run(
            ["docker","--host",pipe,"compose","--env-file",".env","-f","docker-compose.yml",
             "exec","-T","spark","python3","/workspace/spark/run_container.py"],
            cwd=ROOT,env=environment,input=body,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,
            timeout=1350,check=False)
    except (OSError, subprocess.SubprocessError):
        raise ObtError("SPARK_TRANSPORTE_FALLIDO") from None
    if result.returncode:
        # Solo aceptar el paquete minimo y codigos constantes del puente.
        code = "SPARK_TRANSPORTE_FALLIDO"
        if len(result.stdout)<=256:
            try:
                failure = json.loads(result.stdout)
                if (isinstance(failure,dict) and set(failure)=={"status","error"}
                        and failure["status"]=="failed" and isinstance(failure["error"],str)
                        and failure["error"] in SAFE_SPARK_ERRORS):
                    code = failure["error"]
            except (ValueError, UnicodeError):
                pass
        raise ObtError(code)
    check(len(result.stdout)<=SPEC["limits"]["bytes"],"SPARK_TRANSPORTE_FALLIDO")
    # Salida privada del protocolo; nunca imprimirla.
    try:
        transformed = json.loads(result.stdout)
        check(isinstance(transformed,dict),"SPARK_TRANSPORTE_FALLIDO")
    except (ValueError, UnicodeError):
        raise ObtError("SPARK_TRANSPORTE_FALLIDO") from None
    check(transformed.get("status")=="success","SPARK_NO_COMPLETO")
    metrics = transformed["metrics"]
    check(set(metrics)=={"motor","spark_version","scala_version","java_version","spark_app_id",
                         "obligaciones","movimientos","filas_obt","ids_nulos","duplicados",
                         "diferencias_importes","diferencias_agregados"},"RESUMEN_SPARK_NO_PERMITIDO")
    check(metrics["motor"]=="pyspark_dataframes" and metrics["spark_version"]==SPEC["spark"],
          "MOTOR_SPARK_NO_ACREDITADO")
    check(metrics["obligaciones"]==payload["esperadas"]["obligaciones"] and
          metrics["movimientos"]==payload["esperadas"]["movimientos"],"CONTEOS_SPARK_INVALIDOS")
    records = transformed["rows"]
    check(len(records)==payload["esperadas"]["obligaciones"],"CONTEO_OBT_INVALIDO")
    source_u = {r["obligacion_id"]:r for r in payload["sources"]["obligaciones"]}
    ids = set()
    for record in records:
        check(set(record)=={n for n,_ in SPEC["output"]},"SALIDA_FUERA_DEL_CONTRATO")
        for name,kind in SPEC["output"]:
            record[name] = encode(record[name],kind)
        oid = record["obligacion_id"]
        check(oid is not None and oid not in ids and oid in source_u,"ID_OBT_INVALIDO_O_DUPLICADO")
        ids.add(oid)
        check(record["lote_id"]==payload["lote_id"] and record["obt_version"]==SPEC["version"],
              "LOTE_OBT_INCORRECTO")
        check(record["obt_procesado_en"]==payload["procesado_en"],"INSTANTE_PROCESADO_INVALIDO")
        # Independiente del job: conserva cada campo Gold de la obligacion.
        for name,_ in SPEC["sources"]["obligaciones"]["columns"]:
            check(record[name]==source_u[oid][name],"SPARK_ALTERO_VALORES_GOLD")
    return records,metrics


def validate_destination(cur, lote, n_u, n_p):
    cur.execute(
        f"SELECT COUNT(*),COUNT(DISTINCT OBLIGACION_ID),COUNT_IF(OBLIGACION_ID IS NULL),SUM(N_MOVIMIENTOS) "
        f"FROM {DEST} WHERE LOTE_ID=%s",(lote,))
    count,unique,nulls,movements = cur.fetchone()
    check(count==n_u and unique==n_u and not nulls and movements==n_p,"DESTINO_NO_CONCILIA")
    # Se compara cada valor original y el resumen Gold por obligacion.
    compare = " OR ".join("NOT EQUAL_NULL(u."+n+",o."+n+")" for n,_ in SPEC["sources"]["obligaciones"]["columns"])
    cur.execute(
        f"SELECT COUNT(*) FROM {GOLD}FCT_OBLIGACIONES u JOIN {DEST} o "
        f"ON u.LOTE_ID=o.LOTE_ID AND u.OBLIGACION_ID=o.OBLIGACION_ID "
        f"WHERE o.LOTE_ID=%s AND ({compare})",(lote,))
    check(cur.fetchone()[0]==0,"DESTINO_ALTERO_VALORES_GOLD")
    # Control independiente en Snowflake; NO se usa para construir la OBT.
    aggregates = {
        "n_movimientos":"COUNT(*)",
        "n_totales_informados":"COUNT(total_movimiento_declarado)",
        "n_documentos_ab":"SUM(IFF(tipo_documento_codigo='AB',1,0))",
        "n_documentos_fa":"SUM(IFF(tipo_documento_codigo='FA',1,0))",
        "n_estado_f":"SUM(IFF(estado_codigo='F',1,0))",
        "n_estado_a":"SUM(IFF(estado_codigo='A',1,0))",
        "fecha_primer_movimiento_declarada":"MIN(fecha_pago_declarada)",
        "fecha_ultimo_movimiento_declarada":"MAX(fecha_pago_declarada)",
        "n_saldos_informados":"COUNT(saldo_declarado)",
        "n_contextos_movimiento":"COUNT(DISTINCT contexto_key)"}
    for name,kind,source in SPEC["metric_spec"]+SPEC["extra_sums"]:
        if kind=="money38":
            aggregates[name]="SUM("+source+")"
    flags = [n for n,_ in SPEC["sources"]["movimientos"]["columns"] if n.startswith("dq_")]
    aggregates["n_movimientos_con_advertencias"] = "SUM(IFF("+" OR ".join("COALESCE("+n+",FALSE)" for n in flags)+",1,0))"
    select = ",".join(sql+" AS "+name for name,sql in aggregates.items())
    comparisons = " OR ".join(
        "NOT EQUAL_NULL(o."+name+(",COALESCE(a."+name+",0))" if name.startswith("n_") else ",a."+name+")")
        for name in aggregates)
    cur.execute(
        f"WITH a AS (SELECT obligacion_id,lote_id,{select} FROM {GOLD}FCT_MOVIMIENTOS "
        f"WHERE lote_id=%s GROUP BY obligacion_id,lote_id) "
        f"SELECT COUNT(*) FROM {DEST} o LEFT JOIN a ON a.obligacion_id=o.obligacion_id AND a.lote_id=o.lote_id "
        f"WHERE o.lote_id=%s AND ({comparisons})",(lote,lote))
    check(cur.fetchone()[0]==0,"DESTINO_AGREGADOS_NO_CONCILIAN")


def publish(con, payload, records):
    cur = con.cursor()
    try:
        cur.execute("BEGIN TRANSACTION")
        cur.execute(f"SELECT COUNT(*) FROM {DEST} WHERE LOTE_ID<>%s",(payload["lote_id"],))
        others = int(cur.fetchone()[0])
        # Reemplazo ATOMICO exclusivamente del lote; no overwrite/TRUNCATE global.
        cur.execute(f"DELETE FROM {DEST} WHERE LOTE_ID=%s",(payload["lote_id"],))
        names = [n for n,_ in SPEC["output"]]
        placeholders = ["TO_TIMESTAMP_TZ(%s)" if k=="timestamp" else "%s" for _,k in SPEC["output"]]
        sql = f"INSERT INTO {DEST} ({','.join(names)}) VALUES ({','.join(placeholders)})"
        for offset in range(0,len(records),200):
            rows = [tuple(decode(r[n],k) for n,k in SPEC["output"]) for r in records[offset:offset+200]]
            cur.executemany(sql,rows)
        validate_destination(cur,payload["lote_id"],**{
            "n_u":payload["esperadas"]["obligaciones"],"n_p":payload["esperadas"]["movimientos"]})
        cur.execute(f"SELECT COUNT(*) FROM {DEST} WHERE LOTE_ID<>%s",(payload["lote_id"],))
        check(cur.fetchone()[0]==others,"OTROS_LOTES_CAMBIARON")
        con.commit()
    except BaseException:
        con.rollback()
        raise
    finally:
        cur.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--setup",action="store_true")
    parser.add_argument("--lote-id")
    parser.add_argument("--expected-obligaciones",type=int)
    parser.add_argument("--expected-movimientos",type=int)
    args = parser.parse_args()
    if not args.setup:
        check(args.lote_id is not None and str(uuid.UUID(args.lote_id))==args.lote_id,"UUID_EXPLICITO_REQUERIDO")
    # Un solo publicador por proyecto/host. No mutex distribuido.
    import msvcrt
    runtime = ROOT/".runtime"
    check(runtime.is_dir(),"RUNTIME_PRIVADO_NO_PREPARADO")
    with (runtime/"spark-obt.lock").open("a+b") as lock:
        if lock.tell()==0:
            lock.write(b"0"); lock.flush()
        lock.seek(0)
        msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
        con = connect()
        try:
            cur = con.cursor()
            check_context(cur)
            if args.setup:
                prepare(cur)
                con.commit()
                print(json.dumps({"status":"success","operacion":"preparar_tabla_obt_sin_procesar"}))
                return
            check_schema(cur,"OBT","OBT_URBANO_OBLIGACIONES",SPEC["output"])
            payload = fetch_source(cur,args)
            con.rollback()  # Cerrar cualquier transaccion de lectura antes de Spark.
            records,metrics = execute_spark(payload)
            publish(con,payload,records)
            # Solo resumen; nunca rows, credenciales, consultas con valores o stderr.
            print(json.dumps({"status":"success","lote_id":args.lote_id,"tabla":DEST,
                              "obt_version":SPEC["version"],**metrics}))
        finally:
            con.close()


if __name__=="__main__":
    try:
        main()
    except BaseException as error:
        code = str(error) if isinstance(error,ObtError) else "OBT_FALLO_REVISAR_CONFIGURACION_DEPENDENCIAS_O_PERMISOS"
        print(json.dumps({"status":"failed","error":code}))
        sys.exit(1)
