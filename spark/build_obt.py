"""Trabajo PySpark REAL. I/O local privado en tmpfs, sin credenciales Snowflake."""
import argparse
from functools import reduce
import json
import os
from pathlib import Path
import sys

from obt_common import SPEC, ObtError, decode, encode
from run_container import SAFE_SPARK_ERRORS


_diagnostic_path = None
_stage_code = "SPARK_ARRANQUE_FALLIDO"


def stage(code):
    global _stage_code
    # Solo constantes de la lista cerrada; nunca escribir errores ni registros.
    if code not in SAFE_SPARK_ERRORS:
        raise ObtError("DIAGNOSTICO_NO_PERMITIDO")
    _stage_code = code
    if _diagnostic_path is not None:
        _diagnostic_path.write_text(code,encoding="ascii")


def check(condition, code):
    if not condition:
        stage("SPARK_VALIDACION_FALLIDA")
        raise ObtError(code)


def build(payload):
    stage("SPARK_ARRANQUE_FALLIDO")
    from pyspark.sql import SparkSession, functions as F, types as T
    spark = (SparkSession.builder.appName("PSet2 OBT urbana")
             .config("spark.sql.ansi.enabled", "true")
             .config("spark.sql.decimalOperations.allowPrecisionLoss", "false")
             .config("spark.sql.session.timeZone", "UTC")
             .config("spark.sql.shuffle.partitions", "2")
             .config("spark.sql.adaptive.enabled", "true")
             .config("spark.ui.enabled", "false")
             .config("spark.eventLog.enabled", "false")
             .getOrCreate())
    spark.sparkContext.setLogLevel("ERROR")
    try:
        scala = spark.sparkContext._jvm.scala.util.Properties.versionNumberString()
        java = spark.sparkContext._jvm.java.lang.System.getProperty("java.specification.version")
        check(spark.version == SPEC["spark"] and scala.startswith(SPEC["scala"] + ".") and java == "17",
              "VERSION_RUNTIME_INESPERADA")
        types = {
            "money16": T.DecimalType(16,2), "money38": T.DecimalType(38,2),
            "year": T.LongType(), "smallint": T.LongType(), "date_key": T.LongType(),
            "count": T.LongType(), "date": T.DateType(), "bool": T.BooleanType(),
        }
        data = {}
        lote = payload["lote_id"]
        for name, spec in SPEC["sources"].items():
            stage("SPARK_LECTURA_FALLIDA")
            columns = spec["columns"]
            records = payload["sources"][name]
            schema = T.StructType([T.StructField(n, types.get(k, T.StringType()), True) for n,k in columns])
            rows = [tuple(decode(r[n],k) for n,k in columns) for r in records]
            frame = spark.createDataFrame(rows, schema).cache()
            check(frame.count() == len(records), "LECTURA_SPARK_NO_CONCILIA")
            stage("SPARK_VALIDACION_FALLIDA")
            key = spec["key"]
            check(frame.where(F.col(key).isNull()).count() == 0, "CLAVES_NULAS")
            check(frame.select(key).distinct().count() == len(records), "CLAVES_DUPLICADAS")
            wrong_trace = (~F.col("lote_id").eqNullSafe(F.lit(lote)) |
                           ~F.col("capturado_en").eqNullSafe(F.lit(payload["capturado_en"])) |
                           ~F.col("id_version").eqNullSafe(F.lit(payload["id_version"])))
            check(frame.where(wrong_trace).count() == 0, "TRAZABILIDAD_INCONSISTENTE")
            data[name] = frame
        u, p, dates, codes = (data[n] for n in ("obligaciones","movimientos","fechas","contextos"))
        n_u, n_p = u.count(), p.count()
        check(n_u == payload["esperadas"]["obligaciones"] and n_p == payload["esperadas"]["movimientos"],
              "CONTEOS_GOLD_NO_CONCILIAN")
        keys = ["obligacion_id","lote_id"]
        stage("SPARK_JOIN_FALLIDO")
        check(p.join(u.select(*keys), keys, "left_anti").count() == 0, "MOVIMIENTOS_HUERFANOS")
        stage("SPARK_VALIDACION_FALLIDA")
        check(dates.where((F.col("fecha_key")==0) & F.col("fecha").isNull()).count()==1,
              "FECHA_DESCONOCIDA_INVALIDA")
        expected_date_key = F.coalesce(F.date_format("fecha","yyyyMMdd").cast("long"), F.lit(0))
        check(dates.where(~F.col("fecha_key").eqNullSafe(expected_date_key)).count()==0, "CLAVE_FECHA_INVALIDA")
        check(dates.where(~F.col("es_fecha_desconocida").eqNullSafe(F.col("fecha").isNull())).count()==0,
              "MIEMBRO_FECHA_DESCONOCIDA_INVALIDO")
        for name, expression in (
            ("anio",F.year("fecha")),("mes",F.month("fecha")),("dia",F.dayofmonth("fecha")),
            ("dia_semana_iso",((F.dayofweek("fecha")+5)%7)+1)):
            check(dates.where(~F.col(name).eqNullSafe(expression)).count()==0,
                  "ATRIBUTOS_FECHA_INCONSISTENTES")
        for name, frame in (("obligaciones",u),("movimientos",p)):
            origin = "OBLIGACION" if name=="obligaciones" else "MOVIMIENTO"
            stage("SPARK_JOIN_FALLIDO")
            check(frame.join(codes.select("contexto_key","lote_id"),["contexto_key","lote_id"],"left_anti").count()==0,
                  "CONTEXTO_HUERFANO")
            joined = frame.alias("f").join(codes.alias("c"),
                       (F.col("f.contexto_key")==F.col("c.contexto_key")) &
                       (F.col("f.lote_id")==F.col("c.lote_id")), "inner")
            wrong = ~F.col("c.origen").eqNullSafe(F.lit(origin))
            for col in ("estado_codigo","condicion_codigo","tipo_documento_codigo"):
                wrong = wrong | ~F.col("f."+col).eqNullSafe(F.col("c."+col))
            if name=="movimientos":
                wrong = wrong | ~F.col("f.tipo_movimiento_codigo").eqNullSafe(F.col("c.tipo_movimiento_codigo"))
            check(joined.where(wrong).count()==0,"CODIGOS_DIMENSION_NO_CONCILIAN")
            for key,_ in SPEC["sources"][name]["columns"]:
                if key.startswith("fecha_") and key.endswith("_key"):
                    date_col = key[:-4] + "_declarada"
                    check(frame.join(dates.select(F.col("fecha_key").alias(key),"lote_id"),
                                     [key,"lote_id"],"left_anti").count()==0, "FECHA_HUERFANA")
                    linked = frame.alias("f").join(dates.alias("d"),
                              (F.col("f."+key)==F.col("d.fecha_key")) &
                              (F.col("f.lote_id")==F.col("d.lote_id")),"inner")
                    check(linked.where(~F.col("f."+date_col).eqNullSafe(F.col("d.fecha"))).count()==0,
                          "FECHA_DIMENSION_NO_CONCILIA")

        # Todas estas agregaciones se ejecutan en Spark, sin SQL pushdown.
        stage("SPARK_AGREGACION_FALLIDA")
        aggregates = []
        metric_names = []
        for name, kind, source in SPEC["metric_spec"]:
            metric_names.append(name)
            if name=="n_movimientos":
                expression = F.count("movimiento_id")
            elif name=="n_totales_informados":
                expression = F.count("total_movimiento_declarado")
            elif name.startswith("n_documentos_"):
                expression = F.sum(F.when(F.col("tipo_documento_codigo")==source,1).otherwise(0))
            elif name.startswith("n_estado_"):
                expression = F.sum(F.when(F.col("estado_codigo")==source,1).otherwise(0))
            elif kind=="money38":
                expression = F.sum(source).cast("decimal(38,2)")
            elif source=="min":
                expression = F.min("fecha_pago_declarada")
            elif source=="max":
                expression = F.max("fecha_pago_declarada")
            else:
                raise ObtError("METRICA_NO_DEFINIDA")
            aggregates.append(expression.alias(name))
        for name,_,source in SPEC["extra_sums"]:
            aggregates.append(F.sum(source).cast("decimal(38,2)").alias(name))
        p_flags = [F.coalesce(F.col(n),F.lit(False)) for n,_ in SPEC["sources"]["movimientos"]["columns"] if n.startswith("dq_")]
        any_p_flag = reduce(lambda a,b:a|b, p_flags)
        aggregates.extend([
            F.count("saldo_declarado").alias("n_saldos_informados"),
            F.countDistinct("contexto_key").alias("n_contextos_movimiento"),
            F.sum(F.when(any_p_flag,1).otherwise(0)).alias("n_movimientos_con_advertencias")
        ])
        grouped = p.groupBy(*keys).agg(*aggregates).cache()
        check(grouped.select(*keys).distinct().count()==grouped.count(),"AGREGADO_DUPLICADO")
        base = [n for n,_ in SPEC["sources"]["obligaciones"]["columns"] if n not in metric_names]
        aggregated_columns = [(n,k) for n,k,_ in SPEC["metric_spec"]] + [(n,k) for n,k,_ in SPEC["extra_sums"]] + [
            ("n_saldos_informados","count"),("n_contextos_movimiento","count"),("n_movimientos_con_advertencias","count")]
        stage("SPARK_JOIN_FALLIDO")
        result = u.alias("u").join(grouped.alias("m"),keys,"left").select(
            *[F.col("u."+n).alias(n) for n in base],
            *[(F.coalesce(F.col("m."+n),F.lit(0)).cast("long") if k=="count" else F.col("m."+n)).alias(n)
              for n,k in aggregated_columns])
        check(result.count()==n_u,"MULTIPLICACION_JOIN_MOVIMIENTOS")
        compare = result.alias("r").join(u.alias("g"),
                  (F.col("r.obligacion_id")==F.col("g.obligacion_id")) &
                  (F.col("r.lote_id")==F.col("g.lote_id")),"inner")
        mismatch = reduce(lambda a,b:a|b, [~F.col("r."+n).eqNullSafe(F.col("g."+n)) for n in metric_names])
        check(compare.where(mismatch).count()==0,"AGREGADOS_NO_CONCILIAN_CON_GOLD")
        # Desnormalizar dimensiones unicas: contexto literal y roles de fecha.
        lookup = codes.select(F.col("contexto_key").alias("_ctx"),F.col("lote_id").alias("_lote"),
                              F.col("origen").alias("contexto_origen"))
        result = result.join(lookup,(result.contexto_key==lookup["_ctx"]) &
                             (result.lote_id==lookup["_lote"]),"left").drop("_ctx","_lote")
        for role in ("emision","pago_actual"):
            lookup = dates.select(
                F.col("fecha_key").alias("_fecha"), F.col("lote_id").alias("_lote"),
                F.col("anio").alias("anio_"+role),F.col("mes").alias("mes_"+role),
                F.col("dia_semana_iso").alias("dia_semana_iso_"+role),
                F.col("es_fecha_desconocida").alias("fecha_desconocida_"+role))
            result = result.join(lookup,(result["fecha_"+role+"_key"]==lookup["_fecha"]) &
                                  (result.lote_id==lookup["_lote"]),"left").drop("_fecha","_lote")
        u_flags = [F.coalesce(F.col(n),F.lit(False)) for n in base if n.startswith("dq_")]
        result = (result
            .withColumn("tiene_movimientos",F.col("n_movimientos")>0)
            .withColumn("tiene_documentos_ab",F.col("n_documentos_ab")>0)
            .withColumn("tiene_movimientos_estado_a",F.col("n_estado_a")>0)
            .withColumn("tiene_totales_nulos",F.col("n_totales_informados")<F.col("n_movimientos"))
            .withColumn("obligacion_con_advertencias",reduce(lambda a,b:a|b,u_flags))
            .withColumn("dias_entre_movimientos_declarados",
                        F.datediff("fecha_ultimo_movimiento_declarada","fecha_primer_movimiento_declarada").cast("long"))
            .withColumn("obt_version",F.lit(SPEC["version"]))
            .withColumn("obt_procesado_en",F.lit(payload["procesado_en"]))
            .select(*[n for n,_ in SPEC["output"]]).cache())
        check(result.count()==n_u and result.select(*keys).distinct().count()==n_u, "GRANO_OBT_INVALIDO")
        stage("SPARK_VALIDACION_FALLIDA")
        check(result.where(F.col("obligacion_id").isNull()).count()==0,"ID_OBT_NULO")
        stage("SPARK_AGREGACION_FALLIDA")
        result_sum = result.agg(F.sum("n_movimientos")).first()[0]
        check(result_sum==n_p,"MOVIMIENTOS_OBT_NO_CONCILIAN")
        # Comprobar cada campo base, incluyendo decimal y NULL, tras los JOIN.
        stage("SPARK_JOIN_FALLIDO")
        compare = result.alias("r").join(u.alias("g"),
                  (F.col("r.obligacion_id")==F.col("g.obligacion_id")) &
                  (F.col("r.lote_id")==F.col("g.lote_id")),"inner")
        changed = reduce(lambda a,b:a|b,[~F.col("r."+n).eqNullSafe(F.col("g."+n)) for n in base+metric_names])
        check(compare.where(changed).count()==0,"VALORES_OBLIGACION_ALTERADOS")
        stage("SPARK_VALIDACION_FALLIDA")
        metrics = {"motor":"pyspark_dataframes","spark_version":spark.version,"scala_version":scala,
                   "java_version":java,"spark_app_id":spark.sparkContext.applicationId,
                   "obligaciones":n_u,"movimientos":n_p,"filas_obt":result.count(),
                   "ids_nulos":0,"duplicados":0,"diferencias_importes":0,"diferencias_agregados":0}
        return spark,result,metrics
    except BaseException:
        # La limpieza no debe ocultar la etapa que causo el fallo original.
        try:
            spark.stop()
        except BaseException:
            pass
        raise


def main():
    global _diagnostic_path
    parser = argparse.ArgumentParser()
    parser.add_argument("--input",required=True)
    parser.add_argument("--output",required=True)
    parser.add_argument("--diagnostic",required=True)
    args = parser.parse_args()
    _diagnostic_path = Path(args.diagnostic)
    stage("SPARK_TRANSPORTE_FALLIDO")
    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
    spark = None
    try:
        spark,frame,metrics = build(payload)
        # Salida privada tmpfs; no show(), filas en logs ni collect ilimitado.
        stage("SPARK_ESCRITURA_FALLIDA")
        descriptor = os.open(args.output,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(descriptor,"w",encoding="utf-8") as stream:
            stream.write('{"status":"success","metrics":'+json.dumps(metrics)+',"rows":[')
            first = True
            for row in frame.toLocalIterator():
                data = {n:encode(row[n],k) for n,k in SPEC["output"]}
                if not first:
                    stream.write(",")
                stream.write(json.dumps(data,separators=(",",":"),ensure_ascii=True))
                first = False
            stream.write("]}")
    finally:
        if spark:
            if sys.exc_info()[0] is None:
                stage("SPARK_CIERRE_FALLIDO")
                spark.stop()
            else:
                try:
                    spark.stop()
                except BaseException:
                    pass


if __name__=="__main__":
    try:
        main()
    except BaseException:
        # El puente lee solo el archivo de etapa y descarta toda salida de JVM.
        print(_stage_code if _stage_code in SAFE_SPARK_ERRORS else "SPARK_ARRANQUE_FALLIDO",file=sys.stderr)
        sys.exit(1)
