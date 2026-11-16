#!/usr/bin/env bash
# Valida SOLO parametros operativos; no accede al puente, SQL o Snowflake.
set -euo pipefail
umask 077
fail() { printf '%s\n' "$1" >&2; exit 2; }
[[ $(printf '%s' "$PLAN" | wc -c) -le 2048 ]] || fail PLAN_DEMASIADO_GRANDE
[[ "$EJECUTAR" == true || "$EJECUTAR" == false ]] || fail MODO_INVALIDO
if [[ "$EJECUTAR" == true ]]; then
  [[ "$CONFIRMACION" == EJECUTAR_MUESTRA ]] || fail CONFIRMACION_REQUERIDA
fi
pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12},[0-9]{4}-[0-9]{2}-[0-9]{2},[0-9]{4}-[0-9]{2}-[0-9]{2},([1-9]|10)$'
count=0
total=0
previous_end=0
seen=,
periodos=''
separator=''
while IFS= read -r line; do
  line=$(printf '%s' "$line" | tr -d '\r')
  [[ -n "$line" ]] || continue
  [[ "$line" =~ $pattern ]] || fail FORMATO_PLAN_INVALIDO
  IFS=, read -r lote desde hasta limite <<< "$line"
  [[ "$seen" != *",$lote,"* ]] || fail UUID_REPETIDO_EN_PLAN
  seen="$seen$lote,"
  canonical_from=$(date -u -d "$desde" +%F 2>/dev/null) || fail FECHA_INVALIDA
  canonical_until=$(date -u -d "$hasta" +%F 2>/dev/null) || fail FECHA_INVALIDA
  [[ "$canonical_from" == "$desde" && "$canonical_until" == "$hasta" ]] || fail FECHA_INVALIDA
  [[ "$desde" > 1899-12-31 && "$hasta" < 2101-01-01 ]] || fail RANGO_INVALIDO
  start=$(date -u -d "$desde" +%s)
  end=$(date -u -d "$hasta" +%s)
  (( end > start && end-start <= 31*86400 )) || fail PERIODO_SUPERA_31_DIAS
  if (( count > 0 )); then
    (( start >= previous_end )) || fail PERIODOS_SOLAPADOS_O_DESORDENADOS
  fi
  previous_end=$end
  count=$((count+1))
  total=$((total+limite))
  (( count <= 3 && total <= 30 )) || fail TOPE_PLAN_EXCEDIDO
  record=$(printf '{"lote_id":"%s","fiscal_desde":"%s","fiscal_hasta":"%s","limite":%s}' "$lote" "$desde" "$hasta" "$limite")
  periodos="$periodos$separator$record"
  separator=,
done <<< "$PLAN"
(( count > 0 )) || fail PLAN_VACIO
# Formato construido solo con UUID, fechas y enteros previamente validados.
printf '{"status":"planificado","ejecutar":%s,"total_periodos":%s,"max_obligaciones":%s,"periodos":[%s]}\n' \
  "$EJECUTAR" "$count" "$total" "$periodos" > plan_backfill.json
printf '::{"outputs":'
cat plan_backfill.json
printf '}::\n'
