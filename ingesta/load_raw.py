"""Subproceso privado del worker. Solo recibe filas ya seudonimizadas por stdin.

No usar directamente: el protocolo requiere handshake y un marcador final.
No vuelca excepciones, consultas, credenciales ni filas a stdout/stderr.
"""
import datetime as dt
import decimal
import hashlib
import json
import logging
import os
from pathlib import Path
import re
import sys
import time
import uuid

logging.disable(logging.CRITICAL)
TABLES = {
    "obligaciones": "PSET2_CAYAMBE.RAW.RAW_URBANO_OBLIGACIONES",
    "movimientos": "PSET2_CAYAMBE.RAW.RAW_URBANO_MOVIMIENTOS_PAGO",
}
LEDGER = "PSET2_CAYAMBE.RAW.INGESTA_LOTES"
BASE = Path(__file__).resolve().parent
CONTRACT = json.loads((BASE / "contract.json").read_text(encoding="utf-8"))


class SafeError(Exception):
    pass


def emit(value):
    print(json.dumps(value, separators=(",", ":")), flush=True)


def read_message():
    line = sys.stdin.readline(2_000_000)
    if not line or not line.endswith("\n"):
        raise SafeError("PROTOCOLO_INCOMPLETO")
    return json.loads(line)


def before_deadline(m):
    if time.time() >= m["expires"]:
        raise SafeError("SOLICITUD_EXPIRADA")


def check_manifest(m):
    if str(uuid.UUID(m["lote_id"])) != m["lote_id"]:
        raise SafeError("LOTE_INVALIDO")
    start, end = dt.date.fromisoformat(m["fiscal_desde"]), dt.date.fromisoformat(m["fiscal_hasta"])
    if not start < end or not 1900 <= start.year <= end.year <= 2100:
        raise SafeError("RANGO_INVALIDO")
    if not isinstance(m["limite"], int) or not 0 <= m["limite"] <= 1_000_000:
        raise SafeError("LIMITE_INVALIDO")
    if m["id_version"] != CONTRACT["id_version"] or m["contrato_version"] != CONTRACT["version"]:
        raise SafeError("VERSION_INVALIDA")
    if not re.fullmatch("[0-9a-f]{64}", m["key_tag"]):
        raise SafeError("KEY_TAG_INVALIDO")
    captured = dt.datetime.fromisoformat(m["capturado_en"])
    if captured.utcoffset() != dt.timedelta(0):
        raise SafeError("CAPTURA_NO_UTC")
    before_deadline(m)


def measure(cur, lote):
    result = {}
    for kind, table in TABLES.items():
        key = "OBLIGACION_ID" if kind == "obligaciones" else "MOVIMIENTO_ID"
        cur.execute(
            f"SELECT COUNT(*), COUNT(DISTINCT {key}), COUNT_IF({key} IS NULL OR OBLIGACION_ID IS NULL) "
            f"FROM {table} WHERE LOTE_ID=%s", (lote,))
        total, unique, nulls = cur.fetchone()
        if total != unique or (nulls or 0):
            raise SafeError("DESTINO_IDS_INVALIDOS")
        result[kind] = int(total)
    cur.execute(
        f"SELECT COUNT(*) FROM {TABLES['movimientos']} p WHERE p.LOTE_ID=%s AND NOT EXISTS "
        f"(SELECT 1 FROM {TABLES['obligaciones']} u "
        "WHERE u.LOTE_ID=p.LOTE_ID AND u.OBLIGACION_ID=p.OBLIGACION_ID)", (lote,))
    if cur.fetchone()[0]:
        raise SafeError("DESTINO_HUERFANOS")
    return result


def check_schema(cur):
    types = {"id": ("TEXT", 64), "code1": ("TEXT", 1), "code2": ("TEXT", 2),
             "year": ("NUMBER", 4, 0), "money": ("NUMBER", 16, 2), "date": ("DATE",)}
    for kind, table in TABLES.items():
        cur.execute(
            "SELECT COLUMN_NAME,DATA_TYPE,CHARACTER_MAXIMUM_LENGTH,NUMERIC_PRECISION,NUMERIC_SCALE,DATETIME_PRECISION "
            "FROM PSET2_CAYAMBE.INFORMATION_SCHEMA.COLUMNS "
            "WHERE TABLE_SCHEMA='RAW' AND TABLE_NAME=%s", (table.split(".")[-1],))
        actual = {r[0]: r[1:] for r in cur.fetchall()}
        expected = {f["name"]: types[f["type"]] for f in CONTRACT["raw"][kind]}
        expected.update(LOTE_ID=("TEXT", 36), CAPTURADO_EN=("TIMESTAMP_TZ", 3), ID_VERSION=("TEXT", 16))
        if set(actual) != set(expected):
            raise SafeError("ESQUEMA_RAW_CAMBIO")
        for name, spec in expected.items():
            data_type, width, precision, scale, date_precision = actual[name]
            if data_type != spec[0]:
                raise SafeError("ESQUEMA_RAW_CAMBIO")
            if data_type == "TEXT" and width != spec[1]:
                raise SafeError("ESQUEMA_RAW_CAMBIO")
            if data_type == "NUMBER" and (precision, scale) != spec[1:]:
                raise SafeError("ESQUEMA_RAW_CAMBIO")
            if data_type == "TIMESTAMP_TZ" and date_precision != spec[1]:
                raise SafeError("ESQUEMA_RAW_CAMBIO")


def convert(field, value):
    kind = field["type"]
    if value is None:
        if kind in ("id", "year"):
            raise SafeError("ID_NULO")
        return None
    if kind == "id":
        if not isinstance(value, str) or not re.fullmatch("[0-9a-f]{64}", value):
            raise SafeError("ID_INVALIDO")
        return value
    if kind == "year":
        if not isinstance(value, int) or not 1753 <= value <= 9999:
            raise SafeError("ANIO_INVALIDO")
        return value
    if kind == "money":
        # Las cantidades viajan como texto decimal invariante, nunca float.
        if not isinstance(value, str) or not re.fullmatch(r"-?\d{1,14}\.\d{2}", value):
            raise SafeError("IMPORTE_INVALIDO")
        return decimal.Decimal(value)
    if kind == "date":
        if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise SafeError("FECHA_INVALIDA")
        return dt.date.fromisoformat(value)
    width = 1 if kind == "code1" else 2
    if not isinstance(value, str) or len(value) > width:
        raise SafeError("CODIGO_INVALIDO")
    return value


def connect_sf():
    # Importar aqui permite que cualquier error de dependencia sea saneado.
    import snowflake.connector
    key_path = Path(os.environ["SNOWFLAKE_PRIVATE_KEY_FILE"])
    if not key_path.is_absolute() or BASE.parent in key_path.resolve().parents:
        raise SafeError("CLAVE_DEBE_ESTAR_FUERA_DEL_PROYECTO")
    return snowflake.connector.connect(
        account=os.environ.get("SNOWFLAKE_ACCOUNT", "xsdiwiv-xz59673"),
        user="PSET2_PIPELINE_SVC", role="PSET2_PIPELINE_ROLE",
        warehouse="COMPUTE_WH", database="PSET2_CAYAMBE", schema="RAW",
        authenticator="SNOWFLAKE_JWT",
        private_key_file=str(key_path),
        private_key_file_pwd=os.environ.pop("PSET2_SF_KEY_PASSWORD"),
        autocommit=False, login_timeout=30, network_timeout=60,
        session_parameters={"QUERY_TAG": "pset2_raw",
                            "STATEMENT_TIMEOUT_IN_SECONDS": 60},
    )


def initialize():
    # Solo invocable manualmente con Initialize-Raw.ps1. Nunca durante un job.
    con = connect_sf()
    try:
        sql = (BASE.parent / "docs" / "raw_setup.sql").read_text(encoding="utf-8")
        sql = "\n".join(line for line in sql.splitlines() if not line.lstrip().startswith("--"))
        with con.cursor() as cur:
            for statement in sql.split(";"):
                if statement.strip():
                    cur.execute(statement)
            check_schema(cur)
        con.commit()
        emit({"status": "success", "operacion": "preparar_raw_sin_extraer"})
    finally:
        con.close()


def run():
    m = read_message()
    check_manifest(m)
    con = connect_sf()
    try:
        cur = con.cursor()
        cur.execute("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_WAREHOUSE()")
        if cur.fetchone() != ("PSET2_PIPELINE_SVC", "PSET2_PIPELINE_ROLE", "PSET2_CAYAMBE", "COMPUTE_WH"):
            raise SafeError("CONTEXTO_DESTINO_INVALIDO")
        check_schema(cur)
        cur.execute("BEGIN TRANSACTION")
        cur.execute(f"SELECT COUNT(*) FROM {LEDGER} WHERE ID_VERSION=%s AND KEY_TAG<>%s",
                    (m["id_version"], m["key_tag"]))
        if cur.fetchone()[0]:
            raise SafeError("CAMBIO_HMAC_REQUIERE_NUEVA_VERSION")
        cur.execute(
            f"SELECT FISCAL_DESDE,FISCAL_HASTA,LIMITE,CAPTURADO_EN,ID_VERSION,"
            f"CONTRATO_VERSION,KEY_TAG,OBLIGACIONES,MOVIMIENTOS FROM {LEDGER} WHERE LOTE_ID=%s",
            (m["lote_id"],))
        existing = cur.fetchall()
        if len(existing) > 1:
            raise SafeError("LEDGER_DUPLICADO")
        if existing:
            row = existing[0]
            if (str(row[0]), str(row[1]), int(row[2]), row[3], row[4], row[5], row[6]) != (
                m["fiscal_desde"], m["fiscal_hasta"], m["limite"],
                dt.datetime.fromisoformat(m["capturado_en"]),
                m["id_version"], m["contrato_version"], m["key_tag"]):
                raise SafeError("LOTE_CON_OTRO_CONTRATO")
            counts = measure(cur, m["lote_id"])
            if counts != {"obligaciones": int(row[7]), "movimientos": int(row[8])}:
                raise SafeError("REINTENTO_NO_RECONCILIA")
            con.rollback()
            emit({"status": "success", "reutilizado": True, **counts,
                  "ids_nulos": 0, "duplicados": 0, "huerfanos": 0})
            return
        if any(measure(cur, m["lote_id"]).values()):
            raise SafeError("FILAS_SIN_LEDGER")
        emit({"status": "ready"})
        capture = read_message()
        if capture.get("kind") != "capture":
            raise SafeError("CAPTURA_NO_DECLARADA")
        m["capturado_en"] = capture["capturado_en"]
        check_manifest(m)
        buffers = {key: [] for key in TABLES}
        seen = {key: set() for key in TABLES}
        parents = set()
        pending_parent_ids = set()
        digest = hashlib.sha256()
        statements = {}
        for kind, table in TABLES.items():
            names = [f["name"] for f in CONTRACT["raw"][kind]]
            columns = names + ["LOTE_ID", "CAPTURADO_EN", "ID_VERSION"]
            placeholders = ["%s"] * len(names) + ["%s", "TO_TIMESTAMP_TZ(%s)", "%s"]
            statements[kind] = f"INSERT INTO {table} ({','.join(columns)}) VALUES ({','.join(placeholders)})"

        def flush(kind):
            if buffers[kind]:
                before_deadline(m)
                cur.executemany(statements[kind], buffers[kind])
                buffers[kind].clear()

        while True:
            before_deadline(m)
            msg = read_message()
            if msg.get("kind") == "end":
                expected = {"obligaciones": msg["obligaciones"], "movimientos": msg["movimientos"]}
                if expected != {k: len(v) for k, v in seen.items()}:
                    raise SafeError("CONTEOS_FUENTE_NO_COINCIDEN")
                if pending_parent_ids - parents:
                    raise SafeError("ORIGEN_HUERFANOS")
                break
            kind, data = msg["kind"], msg["data"]
            fields = CONTRACT["raw"][kind]
            if set(data) != {f["name"] for f in fields}:
                raise SafeError("PROYECCION_NO_PERMITIDA")
            key = data["OBLIGACION_ID"] if kind == "obligaciones" else data["MOVIMIENTO_ID"]
            if key in seen[kind]:
                raise SafeError("ORIGEN_DUPLICADO")
            seen[kind].add(key)
            if len(seen[kind]) > m["max_" + kind]:
                raise SafeError("TOPE_LOCAL_EXCEDIDO")
            if kind == "obligaciones":
                parents.add(data["OBLIGACION_ID"])
            else:
                pending_parent_ids.add(data["OBLIGACION_ID"])
            digest.update(json.dumps(msg, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii"))
            values = [convert(f, data[f["name"]]) for f in fields]
            buffers[kind].append(tuple(values + [m["lote_id"], m["capturado_en"], m["id_version"]]))
            if len(buffers[kind]) >= 200:
                flush(kind)
        for kind in TABLES:
            flush(kind)
        actual = measure(cur, m["lote_id"])
        if actual != expected:
            raise SafeError("CONTEOS_DESTINO_NO_COINCIDEN")
        before_deadline(m)
        cur.execute(
            f"INSERT INTO {LEDGER} (LOTE_ID,FISCAL_DESDE,FISCAL_HASTA,LIMITE,CAPTURADO_EN,"
            "ID_VERSION,CONTRATO_VERSION,KEY_TAG,OBLIGACIONES,MOVIMIENTOS,CONTENIDO_SHA256,COMMIT_EN) "
            "VALUES (%s,%s,%s,%s,TO_TIMESTAMP_TZ(%s),%s,%s,%s,%s,%s,%s,CURRENT_TIMESTAMP())",
            (m["lote_id"], m["fiscal_desde"], m["fiscal_hasta"], m["limite"],
             m["capturado_en"], m["id_version"], m["contrato_version"], m["key_tag"],
             expected["obligaciones"], expected["movimientos"], digest.hexdigest()))
        con.commit()
        emit({"status": "success", "reutilizado": False, **actual,
              "ids_nulos": 0, "duplicados": 0, "huerfanos": 0})
    except BaseException:
        con.rollback()
        raise
    finally:
        con.close()


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--setup"]:
            initialize()
        elif not sys.argv[1:]:
            run()
        else:
            raise SafeError("ARGUMENTOS_INVALIDOS")
    except BaseException as exc:
        # No imprimir excepciones del conector: pueden contener valores SQL.
        code = str(exc) if isinstance(exc, SafeError) else "CARGA_FALLIDA_REVISAR_CONFIGURACION_Y_PERMISOS"
        emit({"status": "failed", "error": code})
        sys.exit(1)
