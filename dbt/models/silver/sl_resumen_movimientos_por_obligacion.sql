-- Primero agregar el lado muchos; nunca multiplicar importes de la obligacion.
with agregado as (
    select obligacion_id, lote_id,
        count(*) as n_movimientos,
        count(total_movimiento_declarado) as n_totales_informados,
        sum(iff(tipo_documento_codigo='AB',1,0)) as n_documentos_ab,
        sum(iff(tipo_documento_codigo='FA',1,0)) as n_documentos_fa,
        sum(iff(estado_codigo='F',1,0)) as n_estado_f,
        sum(iff(estado_codigo='A',1,0)) as n_estado_a,
        sum(total_movimiento_declarado)::number(38,2) as suma_total_movimientos_declarados,
        sum(importe_principal)::number(38,2) as suma_principal_movimientos_declarados,
        sum(recargo_declarado)::number(38,2) as suma_recargo_declarado,
        sum(descuento_declarado)::number(38,2) as suma_descuento_declarado,
        sum(interes_mora_declarado)::number(38,2) as suma_interes_mora_declarado,
        sum(costas_procesales_declaradas)::number(38,2) as suma_costas_procesales_declaradas,
        min(fecha_pago_declarada) as fecha_primer_movimiento_declarada,
        max(fecha_pago_declarada) as fecha_ultimo_movimiento_declarada
    from {{ ref('sl_movimientos') }}
    where lote_id = {{ lote_id_sql() }}
    group by obligacion_id, lote_id
)
select
    u.obligacion_id, u.lote_id, u.capturado_en, u.id_version,
    coalesce(a.n_movimientos,0)::number(38,0) as n_movimientos,
    coalesce(a.n_totales_informados,0)::number(38,0) as n_totales_informados,
    coalesce(a.n_documentos_ab,0)::number(38,0) as n_documentos_ab,
    coalesce(a.n_documentos_fa,0)::number(38,0) as n_documentos_fa,
    coalesce(a.n_estado_f,0)::number(38,0) as n_estado_f,
    coalesce(a.n_estado_a,0)::number(38,0) as n_estado_a,
    a.suma_total_movimientos_declarados,
    a.suma_principal_movimientos_declarados,
    a.suma_recargo_declarado,
    a.suma_descuento_declarado,
    a.suma_interes_mora_declarado,
    a.suma_costas_procesales_declaradas,
    a.fecha_primer_movimiento_declarada,
    a.fecha_ultimo_movimiento_declarada
from {{ ref('sl_obligaciones') }} u
left join agregado a on a.obligacion_id=u.obligacion_id and a.lote_id=u.lote_id
where u.lote_id = {{ lote_id_sql() }}
