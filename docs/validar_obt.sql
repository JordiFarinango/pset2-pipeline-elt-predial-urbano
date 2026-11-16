-- VALIDACION MANUAL AGREGADA. No mostrar/exportar filas individuales.
-- Sustituir el UUID antes de ejecutar. No ejecutado por Codex.
USE ROLE PSET2_PIPELINE_ROLE;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE PSET2_CAYAMBE;
USE SCHEMA OBT;
SET lote = '00000000-0000-0000-0000-000000000000';

SELECT COUNT(*) AS registros_ledger, MIN(obligaciones) AS obligaciones_confirmadas,
       MIN(movimientos) AS movimientos_confirmados
FROM PSET2_CAYAMBE.RAW.INGESTA_LOTES WHERE lote_id=$lote AND commit_en IS NOT NULL;

SELECT 'GOLD_OBLIGACIONES' AS origen,COUNT(*) AS filas FROM PSET2_CAYAMBE.GOLD.FCT_OBLIGACIONES WHERE lote_id=$lote
UNION ALL
SELECT 'GOLD_MOVIMIENTOS',COUNT(*) FROM PSET2_CAYAMBE.GOLD.FCT_MOVIMIENTOS WHERE lote_id=$lote
UNION ALL
SELECT 'OBT',COUNT(*) FROM OBT_URBANO_OBLIGACIONES WHERE lote_id=$lote;

SELECT COUNT(*) AS filas,COUNT(DISTINCT obligacion_id) AS ids_unicos,
       COALESCE(COUNT_IF(obligacion_id IS NULL),0) AS ids_nulos,
       SUM(n_movimientos) AS movimientos_representados
FROM OBT_URBANO_OBLIGACIONES WHERE lote_id=$lote;

-- Debe devolver cero; no se exponen valores de dinero o ids por registro.
SELECT COUNT(*) AS diferencias_de_valores_gold
FROM PSET2_CAYAMBE.GOLD.FCT_OBLIGACIONES g FULL OUTER JOIN OBT_URBANO_OBLIGACIONES o
  ON o.obligacion_id=g.obligacion_id AND o.lote_id=g.lote_id
WHERE (o.lote_id=$lote OR g.lote_id=$lote) AND (
    o.obligacion_id IS NULL OR g.obligacion_id IS NULL
    OR not equal_null(g.obligacion_id,o.obligacion_id)
    or not equal_null(g.anio_fiscal,o.anio_fiscal)
    or not equal_null(g.importe_principal,o.importe_principal)
    or not equal_null(g.importe_solares,o.importe_solares)
    or not equal_null(g.importe_medicina,o.importe_medicina)
    or not equal_null(g.importe_educacion,o.importe_educacion)
    or not equal_null(g.importe_magisterio,o.importe_magisterio)
    or not equal_null(g.importe_vivienda,o.importe_vivienda)
    or not equal_null(g.importe_bomberos,o.importe_bomberos)
    or not equal_null(g.importe_escolares,o.importe_escolares)
    or not equal_null(g.importe_procesamiento,o.importe_procesamiento)
    or not equal_null(g.importe_basura,o.importe_basura)
    or not equal_null(g.importe_bordillo,o.importe_bordillo)
    or not equal_null(g.importe_alcanta,o.importe_alcanta)
    or not equal_null(g.importe_adoqui_nuevo,o.importe_adoqui_nuevo)
    or not equal_null(g.importe_ado_glob_2011,o.importe_ado_glob_2011)
    or not equal_null(g.total_obligacion_declarado,o.total_obligacion_declarado)
    or not equal_null(g.fecha_emision_declarada,o.fecha_emision_declarada)
    or not equal_null(g.fecha_creacion_declarada,o.fecha_creacion_declarada)
    or not equal_null(g.fecha_modificacion_declarada,o.fecha_modificacion_declarada)
    or not equal_null(g.fecha_pago_actual_declarada,o.fecha_pago_actual_declarada)
    or not equal_null(g.fecha_anulacion_declarada,o.fecha_anulacion_declarada)
    or not equal_null(g.estado_codigo,o.estado_codigo)
    or not equal_null(g.condicion_codigo,o.condicion_codigo)
    or not equal_null(g.tipo_documento_codigo,o.tipo_documento_codigo)
    or not equal_null(g.lote_id,o.lote_id)
    or not equal_null(g.capturado_en,o.capturado_en)
    or not equal_null(g.id_version,o.id_version)
    or not equal_null(g.dq_fecha_emision_nula,o.dq_fecha_emision_nula)
    or not equal_null(g.dq_emision_pre1901,o.dq_emision_pre1901)
    or not equal_null(g.dq_creacion_posterior_emision,o.dq_creacion_posterior_emision)
    or not equal_null(g.dq_total_nulo,o.dq_total_nulo)
    or not equal_null(g.dq_total_negativo,o.dq_total_negativo)
    or not equal_null(g.dq_principal_negativo,o.dq_principal_negativo)
    or not equal_null(g.dq_pago_posterior_captura,o.dq_pago_posterior_captura)
    or not equal_null(g.dq_a_sin_fecha_anulacion,o.dq_a_sin_fecha_anulacion)
    or not equal_null(g.dq_f_con_fecha_anulacion,o.dq_f_con_fecha_anulacion)
    or not equal_null(g.contexto_key,o.contexto_key)
    or not equal_null(g.fecha_emision_key,o.fecha_emision_key)
    or not equal_null(g.fecha_creacion_key,o.fecha_creacion_key)
    or not equal_null(g.fecha_modificacion_key,o.fecha_modificacion_key)
    or not equal_null(g.fecha_pago_actual_key,o.fecha_pago_actual_key)
    or not equal_null(g.fecha_anulacion_key,o.fecha_anulacion_key)
    or not equal_null(g.n_movimientos,o.n_movimientos)
    or not equal_null(g.n_totales_informados,o.n_totales_informados)
    or not equal_null(g.n_documentos_ab,o.n_documentos_ab)
    or not equal_null(g.n_documentos_fa,o.n_documentos_fa)
    or not equal_null(g.n_estado_f,o.n_estado_f)
    or not equal_null(g.n_estado_a,o.n_estado_a)
    or not equal_null(g.suma_total_movimientos_declarados,o.suma_total_movimientos_declarados)
    or not equal_null(g.suma_principal_movimientos_declarados,o.suma_principal_movimientos_declarados)
    or not equal_null(g.suma_recargo_declarado,o.suma_recargo_declarado)
    or not equal_null(g.suma_descuento_declarado,o.suma_descuento_declarado)
    or not equal_null(g.suma_interes_mora_declarado,o.suma_interes_mora_declarado)
    or not equal_null(g.suma_costas_procesales_declaradas,o.suma_costas_procesales_declaradas)
    or not equal_null(g.fecha_primer_movimiento_declarada,o.fecha_primer_movimiento_declarada)
    or not equal_null(g.fecha_ultimo_movimiento_declarada,o.fecha_ultimo_movimiento_declarada)
);

WITH a AS (
  SELECT obligacion_id,lote_id,
    count(*) AS n_movimientos,
    count(total_movimiento_declarado) AS n_totales_informados,
    sum(iff(tipo_documento_codigo='AB',1,0)) AS n_documentos_ab,
    sum(iff(tipo_documento_codigo='FA',1,0)) AS n_documentos_fa,
    sum(iff(estado_codigo='F',1,0)) AS n_estado_f,
    sum(iff(estado_codigo='A',1,0)) AS n_estado_a,
    min(fecha_pago_declarada) AS fecha_primer_movimiento_declarada,
    max(fecha_pago_declarada) AS fecha_ultimo_movimiento_declarada,
    count(saldo_declarado) AS n_saldos_informados,
    count(distinct contexto_key) AS n_contextos_movimiento,
    sum(total_movimiento_declarado) AS suma_total_movimientos_declarados,
    sum(importe_principal) AS suma_principal_movimientos_declarados,
    sum(recargo_declarado) AS suma_recargo_declarado,
    sum(descuento_declarado) AS suma_descuento_declarado,
    sum(interes_mora_declarado) AS suma_interes_mora_declarado,
    sum(costas_procesales_declaradas) AS suma_costas_procesales_declaradas,
    sum(importe_solares) AS suma_importe_solares_movimientos,
    sum(importe_medicina) AS suma_importe_medicina_movimientos,
    sum(importe_educacion) AS suma_importe_educacion_movimientos,
    sum(importe_magisterio) AS suma_importe_magisterio_movimientos,
    sum(importe_vivienda) AS suma_importe_vivienda_movimientos,
    sum(importe_bomberos) AS suma_importe_bomberos_movimientos,
    sum(importe_escolares) AS suma_importe_escolares_movimientos,
    sum(importe_procesamiento) AS suma_importe_procesamiento_movimientos,
    sum(importe_basura) AS suma_importe_basura_movimientos,
    sum(importe_bordillo) AS suma_importe_bordillo_movimientos,
    sum(importe_alcanta) AS suma_importe_alcanta_movimientos,
    sum(importe_adoqui_nuevo) AS suma_importe_adoqui_nuevo_movimientos,
    sum(importe_ado_glob_2011) AS suma_importe_ado_glob_2011_movimientos,
    sum(iff(coalesce(dq_fecha_pago_nula,false) or coalesce(dq_pago_anterior_emision,false) or coalesce(dq_pago_posterior_captura,false) or coalesce(dq_fecha_proceso_nula,false) or coalesce(dq_total_nulo,false) or coalesce(dq_total_negativo,false) or coalesce(dq_a_sin_fecha_anulacion,false) or coalesce(dq_f_con_fecha_anulacion,false),1,0)) AS n_movimientos_con_advertencias
  FROM PSET2_CAYAMBE.GOLD.FCT_MOVIMIENTOS WHERE lote_id=$lote
  GROUP BY obligacion_id,lote_id
)
SELECT COUNT(*) AS diferencias_agregados
FROM OBT_URBANO_OBLIGACIONES o LEFT JOIN a ON a.obligacion_id=o.obligacion_id AND a.lote_id=o.lote_id
WHERE o.lote_id=$lote AND (
    not equal_null(o.n_movimientos,coalesce(a.n_movimientos,0))
    or not equal_null(o.n_totales_informados,coalesce(a.n_totales_informados,0))
    or not equal_null(o.n_documentos_ab,coalesce(a.n_documentos_ab,0))
    or not equal_null(o.n_documentos_fa,coalesce(a.n_documentos_fa,0))
    or not equal_null(o.n_estado_f,coalesce(a.n_estado_f,0))
    or not equal_null(o.n_estado_a,coalesce(a.n_estado_a,0))
    or not equal_null(o.fecha_primer_movimiento_declarada,a.fecha_primer_movimiento_declarada)
    or not equal_null(o.fecha_ultimo_movimiento_declarada,a.fecha_ultimo_movimiento_declarada)
    or not equal_null(o.n_saldos_informados,coalesce(a.n_saldos_informados,0))
    or not equal_null(o.n_contextos_movimiento,coalesce(a.n_contextos_movimiento,0))
    or not equal_null(o.suma_total_movimientos_declarados,a.suma_total_movimientos_declarados)
    or not equal_null(o.suma_principal_movimientos_declarados,a.suma_principal_movimientos_declarados)
    or not equal_null(o.suma_recargo_declarado,a.suma_recargo_declarado)
    or not equal_null(o.suma_descuento_declarado,a.suma_descuento_declarado)
    or not equal_null(o.suma_interes_mora_declarado,a.suma_interes_mora_declarado)
    or not equal_null(o.suma_costas_procesales_declaradas,a.suma_costas_procesales_declaradas)
    or not equal_null(o.suma_importe_solares_movimientos,a.suma_importe_solares_movimientos)
    or not equal_null(o.suma_importe_medicina_movimientos,a.suma_importe_medicina_movimientos)
    or not equal_null(o.suma_importe_educacion_movimientos,a.suma_importe_educacion_movimientos)
    or not equal_null(o.suma_importe_magisterio_movimientos,a.suma_importe_magisterio_movimientos)
    or not equal_null(o.suma_importe_vivienda_movimientos,a.suma_importe_vivienda_movimientos)
    or not equal_null(o.suma_importe_bomberos_movimientos,a.suma_importe_bomberos_movimientos)
    or not equal_null(o.suma_importe_escolares_movimientos,a.suma_importe_escolares_movimientos)
    or not equal_null(o.suma_importe_procesamiento_movimientos,a.suma_importe_procesamiento_movimientos)
    or not equal_null(o.suma_importe_basura_movimientos,a.suma_importe_basura_movimientos)
    or not equal_null(o.suma_importe_bordillo_movimientos,a.suma_importe_bordillo_movimientos)
    or not equal_null(o.suma_importe_alcanta_movimientos,a.suma_importe_alcanta_movimientos)
    or not equal_null(o.suma_importe_adoqui_nuevo_movimientos,a.suma_importe_adoqui_nuevo_movimientos)
    or not equal_null(o.suma_importe_ado_glob_2011_movimientos,a.suma_importe_ado_glob_2011_movimientos)
    or not equal_null(o.n_movimientos_con_advertencias,coalesce(a.n_movimientos_con_advertencias,0))
);

SELECT COUNT(*) AS claves_duplicadas FROM (
  SELECT lote_id,obligacion_id FROM OBT_URBANO_OBLIGACIONES
  WHERE lote_id=$lote GROUP BY lote_id,obligacion_id HAVING COUNT(*)<>1
);

-- Repetir antes/despues del MISMO job/lote: cantidades y control deben ser iguales.
-- Se excluye el instante de procesamiento, que cambia al repetir el trabajo.
SELECT lote_id,COUNT(*) AS filas,
       HASH_AGG(obligacion_id,anio_fiscal,importe_principal,importe_solares,importe_medicina,importe_educacion,importe_magisterio,importe_vivienda,importe_bomberos,importe_escolares,importe_procesamiento,importe_basura,importe_bordillo,importe_alcanta,importe_adoqui_nuevo,importe_ado_glob_2011,total_obligacion_declarado,fecha_emision_declarada,fecha_creacion_declarada,fecha_modificacion_declarada,fecha_pago_actual_declarada,fecha_anulacion_declarada,estado_codigo,condicion_codigo,tipo_documento_codigo,lote_id,capturado_en,id_version,dq_fecha_emision_nula,dq_emision_pre1901,dq_creacion_posterior_emision,dq_total_nulo,dq_total_negativo,dq_principal_negativo,dq_pago_posterior_captura,dq_a_sin_fecha_anulacion,dq_f_con_fecha_anulacion,contexto_key,fecha_emision_key,fecha_creacion_key,fecha_modificacion_key,fecha_pago_actual_key,fecha_anulacion_key,n_movimientos,n_totales_informados,n_documentos_ab,n_documentos_fa,n_estado_f,n_estado_a,suma_total_movimientos_declarados,suma_principal_movimientos_declarados,suma_recargo_declarado,suma_descuento_declarado,suma_interes_mora_declarado,suma_costas_procesales_declaradas,fecha_primer_movimiento_declarada,fecha_ultimo_movimiento_declarada,suma_importe_solares_movimientos,suma_importe_medicina_movimientos,suma_importe_educacion_movimientos,suma_importe_magisterio_movimientos,suma_importe_vivienda_movimientos,suma_importe_bomberos_movimientos,suma_importe_escolares_movimientos,suma_importe_procesamiento_movimientos,suma_importe_basura_movimientos,suma_importe_bordillo_movimientos,suma_importe_alcanta_movimientos,suma_importe_adoqui_nuevo_movimientos,suma_importe_ado_glob_2011_movimientos,n_saldos_informados,n_contextos_movimiento,n_movimientos_con_advertencias,tiene_movimientos,tiene_documentos_ab,tiene_movimientos_estado_a,tiene_totales_nulos,obligacion_con_advertencias,dias_entre_movimientos_declarados,contexto_origen,anio_emision,mes_emision,dia_semana_iso_emision,fecha_desconocida_emision,anio_pago_actual,mes_pago_actual,dia_semana_iso_pago_actual,fecha_desconocida_pago_actual,obt_version) AS control_contenido
FROM OBT_URBANO_OBLIGACIONES GROUP BY lote_id;
-- Comparar tambien las cantidades de OTROS lotes: no deben cambiar.
-- Un hash agregado es un control auxiliar, no prueba criptografica ni anonimiza.
