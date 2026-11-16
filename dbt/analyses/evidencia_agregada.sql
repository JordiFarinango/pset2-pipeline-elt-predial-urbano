-- Solo agregados. Compilar y ejecutar manualmente si se autoriza; nunca dbt show de hechos.
select 'obligaciones_gold' as conjunto,count(*) as filas,count(distinct obligacion_id) as ids_unicos from {{ ref('fct_obligaciones') }}
union all
select 'movimientos_gold',count(*),count(distinct movimiento_id) from {{ ref('fct_movimientos') }}
