#!/usr/bin/env bash
# Solo control y contadores. Nunca recibe claves ni filas municipales.
set -euo pipefail
umask 077
attempt=0
managed_retry=false
if [[ -v ATTEMPT ]]; then attempt=$ATTEMPT; managed_retry=true; fi
emit_summary() {
  printf '::{"outputs":'
  cat resumen.json
  printf '}::\n'
}
stop_permanent() {
  trap - ERR
  # Todos los argumentos de esta funcion son constantes del codigo.
  printf '{"status":"failed","error":"%s","retryable":false}\n' "$1" > resumen.json
  emit_summary
  # Assert convierte este resultado en fallo SIN reintentos de extraccion.
  # Con un Flow anterior sin Assert, conservar su salida de error original.
  if [[ "$managed_retry" == false ]]; then exit 1; fi
  exit 0
}
is_transient() {
  grep -Eq '"status"[[:space:]]*:[[:space:]]*"failed"' "$1" &&
  grep -Eq '"error"[[:space:]]*:[[:space:]]*"SQL_TRANSITORIO"' "$1" &&
  grep -Eq '"retryable"[[:space:]]*:[[:space:]]*true' "$1"
}
trap 'stop_permanent PUENTE_FALLO_REQUIERE_REVISION' ERR
[[ "$REQUEST_ID" =~ ^[A-Za-z0-9_-]{1,70}$ ]] || stop_permanent SOLICITUD_INVALIDA
[[ "$LOTE_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || stop_permanent LOTE_INVALIDO
[[ "$FISCAL_DESDE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || stop_permanent RANGO_INVALIDO
[[ "$FISCAL_HASTA" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || stop_permanent RANGO_INVALIDO
[[ "$LIMITE" =~ ^[0-9]{1,7}$ ]] || stop_permanent LIMITE_INVALIDO
# Compatibilidad con el Flow anterior (sin ATTEMPT): una unica solicitud.
[[ "$attempt" =~ ^[012]$ ]] || stop_permanent INTENTOS_AGOTADOS
bridge=/opt/pset2-bridge
# El operador prepara estos directorios y sus ACL antes de habilitar el worker.
[[ -d "$bridge/requests" && -d "$bridge/results" ]] || stop_permanent PREPARAR_PUENTE_PRIMERO
if (( attempt > 0 )); then
  previous="$bridge/results/$REQUEST_ID-a$((attempt-1)).json"
  # Nunca crear otra solicitud si el intento anterior sigue activo/desconocido.
  [[ -f "$previous" ]] || stop_permanent INTENTO_ANTERIOR_SIN_CONFIRMAR
  [[ $(wc -c < "$previous") -le 4096 ]] || stop_permanent RESPUESTA_FUERA_DE_CONTRATO
  is_transient "$previous" || stop_permanent REINTENTO_NO_AUTORIZADO
fi
request_id="$REQUEST_ID-a$attempt"
job="$bridge/requests/$request_id.json"
result="$bridge/results/$request_id.json"
deadline=$(( $(date +%s) + 1800 ))
temp=$(mktemp "$bridge/requests/.request.XXXXXX")
trap 'rm -f "$temp"' EXIT
printf '{"request_id":"%s","lote_id":"%s","fiscal_desde":"%s","fiscal_hasta":"%s","limite":%s,"expires":%s}\n' \
  "$request_id" "$LOTE_ID" "$FISCAL_DESDE" "$FISCAL_HASTA" "$LIMITE" "$deadline" > "$temp"
# Un intento repetido observa su solicitud; no reemplaza archivos ni el UUID.
if [[ ! -f "$job" ]]; then mv "$temp" "$job"; fi
while [[ ! -f "$result" ]]; do
  if (( $(date +%s) >= deadline )); then
    stop_permanent WORKER_SIN_RESPUESTA_RECONCILIAR_LEDGER
  fi
  sleep 2
done
# El worker construye exclusivamente un resumen de cantidades y codigos seguros.
[[ $(wc -c < "$result") -le 4096 ]] || stop_permanent RESPUESTA_FUERA_DE_CONTRATO
cp "$result" resumen.json
emit_summary
if grep -Eq '"status"[[:space:]]*:[[:space:]]*"success"' resumen.json; then
  exit 0
fi
if is_transient resumen.json; then
  exit 1
fi
if [[ "$managed_retry" == false ]]; then exit 1; fi
exit 0
