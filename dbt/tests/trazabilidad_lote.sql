select 'br_obligaciones' as modelo, count(*) as inconsistencias
from {{ ref('br_obligaciones') }} m cross join {{ ref('br_lote_confirmado') }} l
where m.lote_id <> {{ lote_id_sql() }} or not equal_null(m.lote_id,l.lote_id)
   or not equal_null(m.capturado_en,l.capturado_en) or not equal_null(m.id_version,l.id_version)
having count(*) > 0
union all
select 'br_movimientos' as modelo, count(*) as inconsistencias
from {{ ref('br_movimientos') }} m cross join {{ ref('br_lote_confirmado') }} l
where m.lote_id <> {{ lote_id_sql() }} or not equal_null(m.lote_id,l.lote_id)
   or not equal_null(m.capturado_en,l.capturado_en) or not equal_null(m.id_version,l.id_version)
having count(*) > 0
union all
select 'sl_obligaciones' as modelo, count(*) as inconsistencias
from {{ ref('sl_obligaciones') }} m cross join {{ ref('br_lote_confirmado') }} l
where m.lote_id <> {{ lote_id_sql() }} or not equal_null(m.lote_id,l.lote_id)
   or not equal_null(m.capturado_en,l.capturado_en) or not equal_null(m.id_version,l.id_version)
having count(*) > 0
union all
select 'sl_movimientos' as modelo, count(*) as inconsistencias
from {{ ref('sl_movimientos') }} m cross join {{ ref('br_lote_confirmado') }} l
where m.lote_id <> {{ lote_id_sql() }} or not equal_null(m.lote_id,l.lote_id)
   or not equal_null(m.capturado_en,l.capturado_en) or not equal_null(m.id_version,l.id_version)
having count(*) > 0
union all
select 'sl_resumen_movimientos_por_obligacion' as modelo, count(*) as inconsistencias
from {{ ref('sl_resumen_movimientos_por_obligacion') }} m cross join {{ ref('br_lote_confirmado') }} l
where m.lote_id <> {{ lote_id_sql() }} or not equal_null(m.lote_id,l.lote_id)
   or not equal_null(m.capturado_en,l.capturado_en) or not equal_null(m.id_version,l.id_version)
having count(*) > 0
union all
select 'dim_fecha' as modelo, count(*) as inconsistencias
from {{ ref('dim_fecha') }} m cross join {{ ref('br_lote_confirmado') }} l
where m.lote_id <> {{ lote_id_sql() }} or not equal_null(m.lote_id,l.lote_id)
   or not equal_null(m.capturado_en,l.capturado_en) or not equal_null(m.id_version,l.id_version)
having count(*) > 0
union all
select 'dim_contexto_tributario' as modelo, count(*) as inconsistencias
from {{ ref('dim_contexto_tributario') }} m cross join {{ ref('br_lote_confirmado') }} l
where m.lote_id <> {{ lote_id_sql() }} or not equal_null(m.lote_id,l.lote_id)
   or not equal_null(m.capturado_en,l.capturado_en) or not equal_null(m.id_version,l.id_version)
having count(*) > 0
union all
select 'fct_obligaciones' as modelo, count(*) as inconsistencias
from {{ ref('fct_obligaciones') }} m cross join {{ ref('br_lote_confirmado') }} l
where m.lote_id <> {{ lote_id_sql() }} or not equal_null(m.lote_id,l.lote_id)
   or not equal_null(m.capturado_en,l.capturado_en) or not equal_null(m.id_version,l.id_version)
having count(*) > 0
union all
select 'fct_movimientos' as modelo, count(*) as inconsistencias
from {{ ref('fct_movimientos') }} m cross join {{ ref('br_lote_confirmado') }} l
where m.lote_id <> {{ lote_id_sql() }} or not equal_null(m.lote_id,l.lote_id)
   or not equal_null(m.capturado_en,l.capturado_en) or not equal_null(m.id_version,l.id_version)
having count(*) > 0
