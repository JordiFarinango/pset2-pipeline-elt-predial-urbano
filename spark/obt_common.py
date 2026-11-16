"""Contrato de tipos compartido. No credenciales ni acceso de red."""
import datetime as dt
from decimal import Decimal, getcontext
import json
from pathlib import Path
import re

getcontext().prec = 60
SPEC = json.loads((Path(__file__).resolve().parent / "obt_contract.json").read_text(encoding="utf-8"))


class ObtError(Exception):
    """Error de codigo constante, sin detalles de registros."""


def timestamp(value):
    if isinstance(value, str):
        value = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if not isinstance(value, dt.datetime) or value.utcoffset() is None:
        raise ObtError("TIMESTAMP_SIN_ZONA")
    if value.microsecond % 1000:
        raise ObtError("TIMESTAMP_FUERA_DE_PRECISION")
    return value.astimezone(dt.timezone.utc).isoformat(timespec="milliseconds")


def encode(value, kind):
    if value is None:
        return None
    if kind.startswith("money"):
        if isinstance(value, float):
            raise ObtError("FLOAT_MONETARIO_NO_PERMITIDO")
        value = Decimal(value)
        precision = 16 if kind == "money16" else 38
        if not value.is_finite() or value != value.quantize(Decimal(".01")) or abs(value) >= Decimal(10) ** (precision - 2):
            raise ObtError("DECIMAL_FUERA_DE_CONTRATO")
        return format(value, ".2f")
    if kind in ("year", "smallint", "date_key", "count"):
        if isinstance(value, bool) or isinstance(value, float):
            raise ObtError("ENTERO_FUERA_DE_CONTRATO")
        number = Decimal(value)
        if number != number.to_integral_value() or not -(2**63) <= number < 2**63:
            raise ObtError("ENTERO_FUERA_DE_CONTRATO")
        return int(number)
    if kind == "timestamp":
        return timestamp(value)
    if kind == "date":
        if isinstance(value, str):
            value = dt.date.fromisoformat(value)
        if not isinstance(value, dt.date) or isinstance(value, dt.datetime):
            raise ObtError("FECHA_FUERA_DE_CONTRATO")
        return value.isoformat()
    if kind == "bool":
        if not isinstance(value, bool):
            raise ObtError("BOOLEANO_FUERA_DE_CONTRATO")
        return value
    width = {"id":64,"uuid":36,"version":16,"code1":1,"code2":2,"origen":10}[kind]
    if not isinstance(value, str) or len(value) > width:
        raise ObtError("TEXTO_FUERA_DE_CONTRATO")
    if kind == "id" and not re.fullmatch("[0-9a-f]{64}", value):
        raise ObtError("ID_PROTEGIDO_INVALIDO")
    return value


def decode(value, kind):
    value = encode(value, kind)
    if value is None:
        return None
    if kind.startswith("money"):
        return Decimal(value)
    if kind == "date":
        return dt.date.fromisoformat(value)
    # TIMESTAMP se mantiene como ISO UTC para no perder zona en Spark.
    return value
