{{ config(severity='warn', tags=['advertencias']) }}
-- Observaciones para revision: no excluyen ni corrigen filas.
select 'sl_obligaciones_dq_fecha_emision_nula' as observacion, count(*) as filas
from {{ ref('sl_obligaciones') }} where dq_fecha_emision_nula having count(*)>0
union all
select 'sl_obligaciones_dq_emision_pre1901' as observacion, count(*) as filas
from {{ ref('sl_obligaciones') }} where dq_emision_pre1901 having count(*)>0
union all
select 'sl_obligaciones_dq_creacion_posterior_emision' as observacion, count(*) as filas
from {{ ref('sl_obligaciones') }} where dq_creacion_posterior_emision having count(*)>0
union all
select 'sl_obligaciones_dq_total_nulo' as observacion, count(*) as filas
from {{ ref('sl_obligaciones') }} where dq_total_nulo having count(*)>0
union all
select 'sl_obligaciones_dq_total_negativo' as observacion, count(*) as filas
from {{ ref('sl_obligaciones') }} where dq_total_negativo having count(*)>0
union all
select 'sl_obligaciones_dq_principal_negativo' as observacion, count(*) as filas
from {{ ref('sl_obligaciones') }} where dq_principal_negativo having count(*)>0
union all
select 'sl_obligaciones_dq_pago_posterior_captura' as observacion, count(*) as filas
from {{ ref('sl_obligaciones') }} where dq_pago_posterior_captura having count(*)>0
union all
select 'sl_obligaciones_dq_a_sin_fecha_anulacion' as observacion, count(*) as filas
from {{ ref('sl_obligaciones') }} where dq_a_sin_fecha_anulacion having count(*)>0
union all
select 'sl_obligaciones_dq_f_con_fecha_anulacion' as observacion, count(*) as filas
from {{ ref('sl_obligaciones') }} where dq_f_con_fecha_anulacion having count(*)>0
union all
select 'sl_obligaciones_estado_no_catalogado' as observacion,count(*) as filas
from {{ ref('sl_obligaciones') }} where estado_codigo is null or estado_codigo not in ('A','F','P','T','U') having count(*)>0
union all
select 'sl_obligaciones_condicion_no_catalogada' as observacion,count(*) as filas
from {{ ref('sl_obligaciones') }} where condicion_codigo is null or condicion_codigo not in ('N','S') having count(*)>0
union all
select 'sl_movimientos_dq_fecha_pago_nula' as observacion, count(*) as filas
from {{ ref('sl_movimientos') }} where dq_fecha_pago_nula having count(*)>0
union all
select 'sl_movimientos_dq_pago_anterior_emision' as observacion, count(*) as filas
from {{ ref('sl_movimientos') }} where dq_pago_anterior_emision having count(*)>0
union all
select 'sl_movimientos_dq_pago_posterior_captura' as observacion, count(*) as filas
from {{ ref('sl_movimientos') }} where dq_pago_posterior_captura having count(*)>0
union all
select 'sl_movimientos_dq_fecha_proceso_nula' as observacion, count(*) as filas
from {{ ref('sl_movimientos') }} where dq_fecha_proceso_nula having count(*)>0
union all
select 'sl_movimientos_dq_total_nulo' as observacion, count(*) as filas
from {{ ref('sl_movimientos') }} where dq_total_nulo having count(*)>0
union all
select 'sl_movimientos_dq_total_negativo' as observacion, count(*) as filas
from {{ ref('sl_movimientos') }} where dq_total_negativo having count(*)>0
union all
select 'sl_movimientos_dq_a_sin_fecha_anulacion' as observacion, count(*) as filas
from {{ ref('sl_movimientos') }} where dq_a_sin_fecha_anulacion having count(*)>0
union all
select 'sl_movimientos_dq_f_con_fecha_anulacion' as observacion, count(*) as filas
from {{ ref('sl_movimientos') }} where dq_f_con_fecha_anulacion having count(*)>0
union all
select 'sl_movimientos_estado_no_catalogado' as observacion,count(*) as filas
from {{ ref('sl_movimientos') }} where estado_codigo is null or estado_codigo not in ('A','B','F','S') having count(*)>0
union all
select 'sl_movimientos_condicion_no_catalogada' as observacion,count(*) as filas
from {{ ref('sl_movimientos') }} where condicion_codigo is null or condicion_codigo not in ('N','S') having count(*)>0
