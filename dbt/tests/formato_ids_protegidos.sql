select 'obligaciones' as conjunto,count(*) as ids_invalidos
from {{ ref('br_obligaciones') }} where obligacion_id is null or not regexp_like(obligacion_id,'[0-9a-f]{64}')
having count(*)>0
union all
select 'movimientos',count(*) from {{ ref('br_movimientos') }}
where movimiento_id is null or obligacion_id is null
   or not regexp_like(movimiento_id,'[0-9a-f]{64}') or not regexp_like(obligacion_id,'[0-9a-f]{64}')
having count(*)>0
