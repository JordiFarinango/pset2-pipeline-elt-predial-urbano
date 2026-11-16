"""Puente de transporte privado: stdin -> tmpfs -> spark-submit -> stdout IPC.

No autentica con Snowflake ni realiza transformaciones de negocio.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from obt_common import SPEC


# Protocolo cerrado: nunca derivar codigos del texto de una excepcion.
SAFE_SPARK_ERRORS = frozenset({
    "SPARK_TRANSPORTE_FALLIDO", "SPARK_ARRANQUE_FALLIDO",
    "SPARK_LECTURA_FALLIDA", "SPARK_VALIDACION_FALLIDA",
    "SPARK_AGREGACION_FALLIDA", "SPARK_JOIN_FALLIDO",
    "SPARK_ESCRITURA_FALLIDA", "SPARK_CIERRE_FALLIDO",
})


class SparkStageError(Exception):
    pass


def read_diagnostic(path, fallback):
    try:
        # Archivo separado del resultado: nunca interpretar filas como diagnostico.
        with path.open("rb") as stream:
            code = stream.read(81).decode("ascii")
        return code if code in SAFE_SPARK_ERRORS else fallback
    except (OSError, UnicodeError):
        return fallback


def main():
    os.umask(0o077)
    raw = sys.stdin.buffer.read(SPEC["limits"]["bytes"]+1)
    if len(raw)>SPEC["limits"]["bytes"]:
        raise ValueError("LIMITE_ENTRADA")
    with tempfile.TemporaryDirectory(prefix="pset2-obt-",dir="/tmp") as folder:
        source, target = Path(folder)/"input.json", Path(folder)/"output.json"
        diagnostic = Path(folder)/"diagnostic.txt"
        source.write_bytes(raw)
        source.chmod(0o600)
        try:
            completed = subprocess.run(
                ["/opt/spark/bin/spark-submit","/workspace/spark/build_obt.py",
                 "--input",str(source),"--output",str(target),
                 "--diagnostic",str(diagnostic)],
                stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,
                timeout=1200,check=False)
        except (OSError, subprocess.SubprocessError):
            raise SparkStageError(read_diagnostic(diagnostic,"SPARK_ARRANQUE_FALLIDO")) from None
        if completed.returncode:
            raise SparkStageError(read_diagnostic(diagnostic,"SPARK_ARRANQUE_FALLIDO"))
        if not target.is_file() or target.stat().st_size>SPEC["limits"]["bytes"]:
            raise SparkStageError("SPARK_ESCRITURA_FALLIDA")
        # SOLO para el proceso puente Windows; no ejecutar directamente a consola.
        try:
            body = target.read_bytes()
            result = json.loads(body)
            if not isinstance(result,dict) or result.get("status")!="success":
                raise ValueError()
        except (OSError, ValueError):
            raise SparkStageError("SPARK_ESCRITURA_FALLIDA") from None
        sys.stdout.buffer.write(body)


if __name__=="__main__":
    try:
        main()
    except BaseException as error:
        # Nunca reenviar mensajes JVM o detalles de registros al terminal.
        code = error.args[0] if isinstance(error,SparkStageError) and error.args else None
        if code not in SAFE_SPARK_ERRORS:
            code = "SPARK_TRANSPORTE_FALLIDO"
        print(json.dumps({"status":"failed","error":code}))
        sys.exit(1)
