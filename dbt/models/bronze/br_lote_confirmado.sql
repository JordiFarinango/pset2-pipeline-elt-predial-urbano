-- depends_on: {{ source('raw_cayambe', 'obligaciones') }}
-- depends_on: {{ source('raw_cayambe', 'movimientos') }}
{% do validar_lote() %}
select
    LOTE_ID as lote_id,
    FISCAL_DESDE as fiscal_desde,
    FISCAL_HASTA as fiscal_hasta,
    LIMITE as limite,
    CAPTURADO_EN as capturado_en,
    ID_VERSION as id_version,
    CONTRATO_VERSION as contrato_version,
    OBLIGACIONES as obligaciones,
    MOVIMIENTOS as movimientos,
    COMMIT_EN as commit_en
from {{ source('raw_cayambe', 'ingesta_lotes') }}
where lote_id = {{ lote_id_sql() }} and commit_en is not null
