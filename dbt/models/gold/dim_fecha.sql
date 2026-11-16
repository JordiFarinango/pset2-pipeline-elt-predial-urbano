-- Calendario de fechas OBSERVADAS, mas miembro 0 para fechas desconocidas.
with observadas as (
    select fecha_emision_declarada as fecha from {{ ref('sl_obligaciones') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_creacion_declarada as fecha from {{ ref('sl_obligaciones') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_modificacion_declarada as fecha from {{ ref('sl_obligaciones') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_pago_actual_declarada as fecha from {{ ref('sl_obligaciones') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_anulacion_declarada as fecha from {{ ref('sl_obligaciones') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_pago_declarada as fecha from {{ ref('sl_movimientos') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_emision_declarada as fecha from {{ ref('sl_movimientos') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_creacion_declarada as fecha from {{ ref('sl_movimientos') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_modificacion_declarada as fecha from {{ ref('sl_movimientos') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_anulacion_declarada as fecha from {{ ref('sl_movimientos') }} where lote_id={{ lote_id_sql() }}
    union all
    select fecha_proceso_declarada as fecha from {{ ref('sl_movimientos') }} where lote_id={{ lote_id_sql() }}
), fechas as (
    select distinct fecha from observadas where fecha is not null
    union all select null::date
)
select
    {{ fecha_key('f.fecha') }} as fecha_key,
    f.fecha,
    year(f.fecha)::number(4,0) as anio,
    month(f.fecha)::number(2,0) as mes,
    day(f.fecha)::number(2,0) as dia,
    dayofweekiso(f.fecha)::number(1,0) as dia_semana_iso,
    (f.fecha is null) as es_fecha_desconocida,
    l.lote_id, l.capturado_en, l.id_version
from fechas f cross join {{ ref('br_lote_confirmado') }} l
