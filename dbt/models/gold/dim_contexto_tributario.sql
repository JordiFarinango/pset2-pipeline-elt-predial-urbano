-- Dimension de combinaciones de codigos: no implica catalogo de negocio validado.
with codigos as (
    select 'OBLIGACION'::varchar(10) as origen, estado_codigo, condicion_codigo,
           tipo_documento_codigo, null::varchar(1) as tipo_movimiento_codigo,
           lote_id, capturado_en, id_version
    from {{ ref('sl_obligaciones') }} where lote_id = {{ lote_id_sql() }}
    union all
    select 'MOVIMIENTO'::varchar(10), estado_codigo, condicion_codigo,
           tipo_documento_codigo, tipo_movimiento_codigo, lote_id, capturado_en, id_version
    from {{ ref('sl_movimientos') }} where lote_id = {{ lote_id_sql() }}
)
select distinct
    sha2(to_json(array_construct(
        origen, estado_codigo is null, coalesce(estado_codigo,''),
        condicion_codigo is null, coalesce(condicion_codigo,''),
        tipo_documento_codigo is null, coalesce(tipo_documento_codigo,''),
        tipo_movimiento_codigo is null, coalesce(tipo_movimiento_codigo,'')
    )),256) as contexto_key,
    origen, estado_codigo, condicion_codigo, tipo_documento_codigo,
    tipo_movimiento_codigo, lote_id, capturado_en, id_version
from codigos
