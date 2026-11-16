with esperado as (
    select u.obligacion_id, u.lote_id,
        count(p.movimiento_id) as n_movimientos,
        count(p.total_movimiento_declarado) as n_totales_informados,
        sum(iff(p.tipo_documento_codigo='AB',1,0)) as n_documentos_ab,
        sum(iff(p.tipo_documento_codigo='FA',1,0)) as n_documentos_fa,
        sum(iff(p.estado_codigo='F',1,0)) as n_estado_f,
        sum(iff(p.estado_codigo='A',1,0)) as n_estado_a,
        sum(p.total_movimiento_declarado)::number(38,2) as suma_total_movimientos_declarados,
        sum(p.importe_principal)::number(38,2) as suma_principal_movimientos_declarados,
        sum(p.recargo_declarado)::number(38,2) as suma_recargo_declarado,
        sum(p.descuento_declarado)::number(38,2) as suma_descuento_declarado,
        sum(p.interes_mora_declarado)::number(38,2) as suma_interes_mora_declarado,
        sum(p.costas_procesales_declaradas)::number(38,2) as suma_costas_procesales_declaradas,
        min(p.fecha_pago_declarada) as fecha_primer_movimiento_declarada,
        max(p.fecha_pago_declarada) as fecha_ultimo_movimiento_declarada
    from {{ ref('sl_obligaciones') }} u
    left join {{ ref('sl_movimientos') }} p on p.obligacion_id=u.obligacion_id and p.lote_id=u.lote_id
    group by u.obligacion_id,u.lote_id
)
select 'sl_resumen_movimientos_por_obligacion' as control, count(*) as diferencias
from esperado e full outer join {{ ref('sl_resumen_movimientos_por_obligacion') }} r on e.obligacion_id=r.obligacion_id and e.lote_id=r.lote_id
where e.obligacion_id is null or r.obligacion_id is null
    or not equal_null(e.n_movimientos,r.n_movimientos)
    or not equal_null(e.n_totales_informados,r.n_totales_informados)
    or not equal_null(e.n_documentos_ab,r.n_documentos_ab)
    or not equal_null(e.n_documentos_fa,r.n_documentos_fa)
    or not equal_null(e.n_estado_f,r.n_estado_f)
    or not equal_null(e.n_estado_a,r.n_estado_a)
    or not equal_null(e.suma_total_movimientos_declarados,r.suma_total_movimientos_declarados)
    or not equal_null(e.suma_principal_movimientos_declarados,r.suma_principal_movimientos_declarados)
    or not equal_null(e.suma_recargo_declarado,r.suma_recargo_declarado)
    or not equal_null(e.suma_descuento_declarado,r.suma_descuento_declarado)
    or not equal_null(e.suma_interes_mora_declarado,r.suma_interes_mora_declarado)
    or not equal_null(e.suma_costas_procesales_declaradas,r.suma_costas_procesales_declaradas)
    or not equal_null(e.fecha_primer_movimiento_declarada,r.fecha_primer_movimiento_declarada)
    or not equal_null(e.fecha_ultimo_movimiento_declarada,r.fecha_ultimo_movimiento_declarada)
having count(*)>0
union all
select 'fct_obligaciones' as control, count(*) as diferencias
from esperado e full outer join {{ ref('fct_obligaciones') }} r on e.obligacion_id=r.obligacion_id and e.lote_id=r.lote_id
where e.obligacion_id is null or r.obligacion_id is null
    or not equal_null(e.n_movimientos,r.n_movimientos)
    or not equal_null(e.n_totales_informados,r.n_totales_informados)
    or not equal_null(e.n_documentos_ab,r.n_documentos_ab)
    or not equal_null(e.n_documentos_fa,r.n_documentos_fa)
    or not equal_null(e.n_estado_f,r.n_estado_f)
    or not equal_null(e.n_estado_a,r.n_estado_a)
    or not equal_null(e.suma_total_movimientos_declarados,r.suma_total_movimientos_declarados)
    or not equal_null(e.suma_principal_movimientos_declarados,r.suma_principal_movimientos_declarados)
    or not equal_null(e.suma_recargo_declarado,r.suma_recargo_declarado)
    or not equal_null(e.suma_descuento_declarado,r.suma_descuento_declarado)
    or not equal_null(e.suma_interes_mora_declarado,r.suma_interes_mora_declarado)
    or not equal_null(e.suma_costas_procesales_declaradas,r.suma_costas_procesales_declaradas)
    or not equal_null(e.fecha_primer_movimiento_declarada,r.fecha_primer_movimiento_declarada)
    or not equal_null(e.fecha_ultimo_movimiento_declarada,r.fecha_ultimo_movimiento_declarada)
having count(*)>0
