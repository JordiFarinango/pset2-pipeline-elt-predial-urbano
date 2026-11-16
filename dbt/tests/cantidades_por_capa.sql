-- Solo contadores; no devuelve registros individuales.
with esperado as (
    select obligaciones, movimientos from {{ ref('br_lote_confirmado') }}
), actual as (
    select 'br_obligaciones' as modelo, count(*) as filas, (select obligaciones from esperado) as esperado from {{ ref('br_obligaciones') }}
    union all
    select 'br_movimientos' as modelo, count(*) as filas, (select movimientos from esperado) as esperado from {{ ref('br_movimientos') }}
    union all
    select 'sl_obligaciones' as modelo, count(*) as filas, (select obligaciones from esperado) as esperado from {{ ref('sl_obligaciones') }}
    union all
    select 'sl_movimientos' as modelo, count(*) as filas, (select movimientos from esperado) as esperado from {{ ref('sl_movimientos') }}
    union all
    select 'sl_resumen_movimientos_por_obligacion' as modelo, count(*) as filas, (select obligaciones from esperado) as esperado from {{ ref('sl_resumen_movimientos_por_obligacion') }}
    union all
    select 'fct_obligaciones' as modelo, count(*) as filas, (select obligaciones from esperado) as esperado from {{ ref('fct_obligaciones') }}
    union all
    select 'fct_movimientos' as modelo, count(*) as filas, (select movimientos from esperado) as esperado from {{ ref('fct_movimientos') }}
)
select modelo, filas, esperado from actual where filas <> esperado or esperado is null
