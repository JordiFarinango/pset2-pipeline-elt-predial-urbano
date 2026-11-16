-- depends_on: {{ ref('br_obligaciones') }}
-- depends_on: {{ ref('br_movimientos') }}
-- depends_on: {{ ref('sl_obligaciones') }}
-- depends_on: {{ ref('sl_movimientos') }}
-- depends_on: {{ ref('sl_resumen_movimientos_por_obligacion') }}
-- depends_on: {{ ref('fct_obligaciones') }}
-- depends_on: {{ ref('fct_movimientos') }}

with esperado as (
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_PRINCIPAL' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_SOLARES' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_MEDICINA' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_EDUCACION' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_MAGISTERIO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_VIVIENDA' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_BOMBEROS' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_ESCOLARES' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_PROCESAMIENTO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_BASURA' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_BORDILLO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_ALCANTA' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_ADOQUI_NUEVO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'IMPORTE_ADO_GLOB_2011' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_OBLIGACIONES' as tabla,'TOTAL_OBLIGACION_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_PRINCIPAL' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_SOLARES' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_MEDICINA' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_EDUCACION' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_MAGISTERIO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_VIVIENDA' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_BOMBEROS' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_ESCOLARES' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_PROCESAMIENTO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_BASURA' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_BORDILLO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_ALCANTA' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_ADOQUI_NUEVO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'IMPORTE_ADO_GLOB_2011' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'TOTAL_MOVIMIENTO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'RECARGO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'DESCUENTO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'INTERES_MORA_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'COSTAS_PROCESALES_DECLARADAS' as columna,16 as precision_esperada
    union all
    select 'BRONZE' as esquema,'BR_MOVIMIENTOS' as tabla,'SALDO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_PRINCIPAL' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_SOLARES' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_MEDICINA' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_EDUCACION' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_MAGISTERIO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_VIVIENDA' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_BOMBEROS' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_ESCOLARES' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_PROCESAMIENTO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_BASURA' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_BORDILLO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_ALCANTA' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_ADOQUI_NUEVO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'IMPORTE_ADO_GLOB_2011' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_OBLIGACIONES' as tabla,'TOTAL_OBLIGACION_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_PRINCIPAL' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_SOLARES' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_MEDICINA' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_EDUCACION' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_MAGISTERIO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_VIVIENDA' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_BOMBEROS' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_ESCOLARES' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_PROCESAMIENTO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_BASURA' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_BORDILLO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_ALCANTA' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_ADOQUI_NUEVO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'IMPORTE_ADO_GLOB_2011' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'TOTAL_MOVIMIENTO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'RECARGO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'DESCUENTO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'INTERES_MORA_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'COSTAS_PROCESALES_DECLARADAS' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_MOVIMIENTOS' as tabla,'SALDO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_RESUMEN_MOVIMIENTOS_POR_OBLIGACION' as tabla,'SUMA_TOTAL_MOVIMIENTOS_DECLARADOS' as columna,38 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_RESUMEN_MOVIMIENTOS_POR_OBLIGACION' as tabla,'SUMA_PRINCIPAL_MOVIMIENTOS_DECLARADOS' as columna,38 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_RESUMEN_MOVIMIENTOS_POR_OBLIGACION' as tabla,'SUMA_RECARGO_DECLARADO' as columna,38 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_RESUMEN_MOVIMIENTOS_POR_OBLIGACION' as tabla,'SUMA_DESCUENTO_DECLARADO' as columna,38 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_RESUMEN_MOVIMIENTOS_POR_OBLIGACION' as tabla,'SUMA_INTERES_MORA_DECLARADO' as columna,38 as precision_esperada
    union all
    select 'SILVER' as esquema,'SL_RESUMEN_MOVIMIENTOS_POR_OBLIGACION' as tabla,'SUMA_COSTAS_PROCESALES_DECLARADAS' as columna,38 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_PRINCIPAL' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_SOLARES' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_MEDICINA' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_EDUCACION' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_MAGISTERIO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_VIVIENDA' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_BOMBEROS' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_ESCOLARES' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_PROCESAMIENTO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_BASURA' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_BORDILLO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_ALCANTA' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_ADOQUI_NUEVO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'IMPORTE_ADO_GLOB_2011' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'TOTAL_OBLIGACION_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'SUMA_TOTAL_MOVIMIENTOS_DECLARADOS' as columna,38 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'SUMA_PRINCIPAL_MOVIMIENTOS_DECLARADOS' as columna,38 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'SUMA_RECARGO_DECLARADO' as columna,38 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'SUMA_DESCUENTO_DECLARADO' as columna,38 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'SUMA_INTERES_MORA_DECLARADO' as columna,38 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_OBLIGACIONES' as tabla,'SUMA_COSTAS_PROCESALES_DECLARADAS' as columna,38 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_PRINCIPAL' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_SOLARES' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_MEDICINA' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_EDUCACION' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_MAGISTERIO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_VIVIENDA' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_BOMBEROS' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_ESCOLARES' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_PROCESAMIENTO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_BASURA' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_BORDILLO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_ALCANTA' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_ADOQUI_NUEVO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'IMPORTE_ADO_GLOB_2011' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'TOTAL_MOVIMIENTO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'RECARGO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'DESCUENTO_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'INTERES_MORA_DECLARADO' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'COSTAS_PROCESALES_DECLARADAS' as columna,16 as precision_esperada
    union all
    select 'GOLD' as esquema,'FCT_MOVIMIENTOS' as tabla,'SALDO_DECLARADO' as columna,16 as precision_esperada
)
select e.esquema,e.tabla,count(*) as columnas_incorrectas
from esperado e left join {{ target.database }}.INFORMATION_SCHEMA.COLUMNS c
  on c.table_schema=e.esquema and c.table_name=e.tabla and c.column_name=e.columna
where c.column_name is null or c.data_type<>'NUMBER'
   or c.numeric_precision<>e.precision_esperada or c.numeric_scale<>2
group by e.esquema,e.tabla
