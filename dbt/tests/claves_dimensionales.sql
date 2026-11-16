select 'fct_obligaciones_fecha_emision_key' as control, count(*) as diferencias
from {{ ref('fct_obligaciones') }} where fecha_emision_key <> {{ fecha_key('fecha_emision_declarada') }}
having count(*)>0
union all
select 'fct_obligaciones_fecha_creacion_key' as control, count(*) as diferencias
from {{ ref('fct_obligaciones') }} where fecha_creacion_key <> {{ fecha_key('fecha_creacion_declarada') }}
having count(*)>0
union all
select 'fct_obligaciones_fecha_modificacion_key' as control, count(*) as diferencias
from {{ ref('fct_obligaciones') }} where fecha_modificacion_key <> {{ fecha_key('fecha_modificacion_declarada') }}
having count(*)>0
union all
select 'fct_obligaciones_fecha_pago_actual_key' as control, count(*) as diferencias
from {{ ref('fct_obligaciones') }} where fecha_pago_actual_key <> {{ fecha_key('fecha_pago_actual_declarada') }}
having count(*)>0
union all
select 'fct_obligaciones_fecha_anulacion_key' as control, count(*) as diferencias
from {{ ref('fct_obligaciones') }} where fecha_anulacion_key <> {{ fecha_key('fecha_anulacion_declarada') }}
having count(*)>0
union all
select 'fct_movimientos_fecha_pago_key' as control, count(*) as diferencias
from {{ ref('fct_movimientos') }} where fecha_pago_key <> {{ fecha_key('fecha_pago_declarada') }}
having count(*)>0
union all
select 'fct_movimientos_fecha_emision_key' as control, count(*) as diferencias
from {{ ref('fct_movimientos') }} where fecha_emision_key <> {{ fecha_key('fecha_emision_declarada') }}
having count(*)>0
union all
select 'fct_movimientos_fecha_creacion_key' as control, count(*) as diferencias
from {{ ref('fct_movimientos') }} where fecha_creacion_key <> {{ fecha_key('fecha_creacion_declarada') }}
having count(*)>0
union all
select 'fct_movimientos_fecha_modificacion_key' as control, count(*) as diferencias
from {{ ref('fct_movimientos') }} where fecha_modificacion_key <> {{ fecha_key('fecha_modificacion_declarada') }}
having count(*)>0
union all
select 'fct_movimientos_fecha_anulacion_key' as control, count(*) as diferencias
from {{ ref('fct_movimientos') }} where fecha_anulacion_key <> {{ fecha_key('fecha_anulacion_declarada') }}
having count(*)>0
union all
select 'fct_movimientos_fecha_proceso_key' as control, count(*) as diferencias
from {{ ref('fct_movimientos') }} where fecha_proceso_key <> {{ fecha_key('fecha_proceso_declarada') }}
having count(*)>0
union all
select 'dim_fecha_valor' as control,count(*) as diferencias from {{ ref('dim_fecha') }}
where fecha_key <> {{ fecha_key('fecha') }} or es_fecha_desconocida <> (fecha is null)
having count(*)>0
union all
select 'dim_fecha_desconocida' as control,count(*) as diferencias from {{ ref('dim_fecha') }}
where fecha_key=0 having count(*)<>1
union all
select 'contexto_obligaciones' as control,count(*) as diferencias
from {{ ref('fct_obligaciones') }}
where contexto_key <> {{ contexto_key('OBLIGACION','estado_codigo','condicion_codigo','tipo_documento_codigo') }}
having count(*)>0
union all
select 'contexto_movimientos' as control,count(*) as diferencias
from {{ ref('fct_movimientos') }}
where contexto_key <> {{ contexto_key('MOVIMIENTO','estado_codigo','condicion_codigo','tipo_documento_codigo','tipo_movimiento_codigo') }}
having count(*)>0
