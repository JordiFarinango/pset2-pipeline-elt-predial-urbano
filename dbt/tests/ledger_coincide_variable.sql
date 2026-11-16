select count(*) as filas_lote
from {{ ref('br_lote_confirmado') }}
having count(*)<>1 or coalesce(count_if(lote_id={{ lote_id_sql() }} and commit_en is not null),0)<>1
