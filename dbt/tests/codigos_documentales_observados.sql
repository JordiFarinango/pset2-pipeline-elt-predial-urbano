{{ config(severity='warn', tags=['advertencias']) }}
select 'obligaciones_documento_no_catalogado' as observacion,count(*) as filas
from {{ ref('sl_obligaciones') }}
where tipo_documento_codigo is not null and tipo_documento_codigo not in ('A','AB','FA') having count(*)>0
union all
select 'movimientos_documento_no_catalogado',count(*) from {{ ref('sl_movimientos') }}
where tipo_documento_codigo is not null and tipo_documento_codigo not in ('AB','FA') having count(*)>0
union all
select 'movimientos_tipo_no_catalogado',count(*) from {{ ref('sl_movimientos') }}
where tipo_movimiento_codigo is not null and tipo_movimiento_codigo not in ('A','B','C') having count(*)>0
