# PSet #2 — Impuestos prediales urbanos de Cayambe

## Evidencia final de la demostración sintética — 15 de noviembre de 2026

La demo **comienza en Kestra con datos ficticios; no comienza en SQL Server**.
Kestra genera los datos sintéticos en la base exclusiva `PSET2_DEMO_SINTETICO`.
Después se ejecutan **dbt y PySpark manualmente, en ese orden**, para el lote
`11111111-2222-4333-8444-555555555555`.

| Etapa | Resultado real verificado |
|---|---|
| Kestra | SUCCESS, 5 tareas completadas |
| Snowflake RAW | 10 obligaciones, 6 movimientos sintéticos, lote confirmado |
| dbt | 10 modelos, 113 pruebas: 123 PASS, 1 WARN, 0 ERROR, 0 SKIP |
| Advertencia dbt | `observaciones_calidad` |
| PySpark | SUCCESS, 10 filas OBT, 6 movimientos, 0 identificadores nulos, 0 duplicados, 0 diferencias de importes y agregados |

Estos resultados verificados fueron comunicados por el responsable. No se
ejecutaron pruebas, builds ni nuevas ingestas para esta actualización documental.
La advertencia se conserva; esta evidencia acredita la demo sintética, no la
extracción municipal ni una orquestación integral automática.
La ejecución manual y sus requisitos se detallan en [demo/README.md](demo/README.md).
El docente necesita configurar su propia cuenta Snowflake, credenciales,
permisos y entorno antes de ejecutar la demo; el repositorio no proporciona
acceso a la cuenta del estudiante.

## Evidencia original del flujo municipal comunicada por el responsable — 15 de noviembre de 2026

Lote validado: 8e977e06-ce56-4b4d-9781-cdf6766fb79c.

| Etapa | Evidencia existente |
|---|---|
| SQL Server -> Kestra -> Snowflake Raw | SUCCESS: 10 obligaciones y 6 movimientos |
| Repeticion del mismo lote | reutilizado=true, sin duplicacion |
| dbt Bronze/Silver/Gold | 10 modelos y 113 pruebas: 123 PASS, 1 WARN, 0 ERROR |
| PySpark 3.5.8 -> Snowflake OBT | Trabajo exitoso y segunda publicacion exitosa |
| Consulta independiente OBT | 10 filas, 10 ids unicos, 6 movimientos, 0 ids nulos |

Estos resultados fueron aportados por el responsable; no se volvieron a ejecutar
para esta actualizacion. El WARN de calidad se conserva. La muestra no acredita
cobertura historica completa, representatividad ni un target de impago a 90 dias.

Arquitectura del proyecto:

~~~text
SQL Server -> Kestra -> Snowflake Raw -> dbt Bronze -> dbt Silver
           -> dbt Gold -> Spark -> Snowflake OBT
~~~

Kestra automatiza la solicitud, espera y comprobacion de la ingesta mediante
el worker Windows. dbt y Spark se ejecutan MANUALMENTE y en ese orden.
No existe una orquestacion integral automatica validada.

## Kestra: reintentos y backfill preparados

- ingesta_raw_urbano conserva cola serial y un unico escritor Windows.
- Hasta tres intentos totales, con esperas exponenciales de 30/60 segundos,
  solo con nueva solicitud de carga ante SQL_TRANSITORIO confirmado.
- Cada intento conserva el UUID, filtros, limite y contrato. Cambia solamente
  el identificador de control (-a0/-a1/-a2), nunca se genera otro lote.
- Errores permanentes/desconocidos y resultados ambiguos requieren revision.
  La tarea exigir_confirmacion hace fallar el Flow sin reextraer esos errores.
- backfill_raw_urbano es manual: por defecto valida el plan SIN extraccion.
  Acepta hasta tres periodos disjuntos de hasta 31 dias, de 1 a 10 obligaciones
  por periodo y hasta 30 en total. Todos sus movimientos mantienen el tope
  local existente; no se recortan pagos ni se habilita limite=0.

Las revisiones de ambos Flows se importaron en Kestra segun la evidencia
posterior. La planificacion de backfill sin carga (ejecutar=false) termino en
SUCCESS. No se ha validado la carga historica real ni la recuperacion automatica
despues de un error SQL transitorio. Las nuevas funciones no se comprobaron
con ingestas reales adicionales.

La guia [docs/orquestacion.md](docs/orquestacion.md) contiene configuracion,
demostracion acotada, clasificacion de errores, evidencia y limites temporales.
Usa Loop y fromJson de Kestra 2, de acuerdo con la
[guia oficial](https://kestra.io/docs/migration-guide/v2.0.0/foreach-loop).

## Configuracion y demostracion manual

Trabajar desde este pset_2 existente. No crear otra copia.

1. Mantener Docker Desktop, VPN para el worker y los montajes del override
   docker-compose.ingesta.yml que ya funcionan.
2. Sin solicitudes activas, reiniciar el worker Windows para leer el codigo
   actualizado. Mantener HMAC y clave cifrada, sin renovar secretos.
3. Importar primero ingesta_raw_urbano.yml como revision del Flow existente y
   despues backfill_raw_urbano.yml. Guardar los YAML no ejecuta cargas.
4. En backfill_raw_urbano proporcionar plan con una linea por periodo:
   UUID,fecha_desde,fecha_hasta,limite. Ejecutar primero con ejecutar=false.
5. Revisar plan_backfill.json. Solo cuando se decida cargar la demostracion,
   iniciar el worker con topes de sesion 10 obligaciones/100 movimientos como
   indica la guia; usar el MISMO plan con ejecutar=true y
   confirmacion=EJECUTAR_MUESTRA.
6. Conservar el plan y UUID para repetir sin duplicar. Tras Raw, continuar dbt
   y Spark manualmente con el lote y sus conteos realmente observados.

El ejemplo completo propone un mes y limite=1; no presupone que tenga datos.
No reutilizar el UUID validado con otros filtros. No disparar cargas anuales
completas ni aumentar topes para demostrar backfill.

El puente actual solo admite ingesta. Coordinar dbt/Spark requeriria ampliar
el protocolo Windows, la custodia de secretos y el control de concurrencia.
No se monta una clave ni un socket Docker en Kestra para resolverlo.

## Infraestructura existente

| Servicio | Imagen fijada | Funcion y puertos |
|---|---|---|
| postgres | postgres:18.6-bookworm | Persistencia Kestra; sin puerto publicado |
| kestra | kestra/kestra:v2.0.9 | Orquestador; 127.0.0.1:8080 configurable |
| spark | apache/spark:3.5.8-scala2.12-java17-python3-ubuntu | Runtime PySpark local; sin puerto publicado |

Requisitos: Windows, PowerShell 5.1 para el worker, Docker Desktop con
contenedores Linux y Compose v2, VPN, .NET System.Data.SqlClient y entornos
Python ya preparados. El worker/host usa snowflake-connector-python 5.2.0.
dbt usa .venv-dbt separada: dbt-core 1.11.11 y dbt-snowflake 1.11.3.
No hay instalaciones automaticas.

Spark permanece en espera al iniciar Compose; eso no inicia un job. El trabajo
OBT ya fue probado manualmente segun la evidencia anterior.

Comandos de operacion manual, conservando los montajes de ingesta:

~~~powershell
docker compose --env-file .env -f docker-compose.yml -f docker-compose.ingesta.yml up -d
docker compose --env-file .env -f docker-compose.yml -f docker-compose.ingesta.yml ps
docker compose --env-file .env -f docker-compose.yml -f docker-compose.ingesta.yml stop
~~~

No ejecutarlos durante una carga. No usar down -v ni recrear recursos ya
verificados como parte de esta actualizacion. Kestra local esta en
http://127.0.0.1:8080/; usar el puerto configurado si es diferente.

## Guias y archivos

- [Ingesta Raw](docs/ingesta_raw.md): preparacion, HMAC, ledger y worker.
- [Orquestacion y evidencia](docs/orquestacion.md): retry, backfill y pendientes.
- [Modelo dbt](docs/dbt_modelo.md): Bronze/Silver/Gold, estrella y ejecucion manual.
- [Spark/OBT](docs/spark_obt.md): lanzadores y controles; sus pendientes de ejecucion
  originales quedan actualizados por el estado real de este README.
- [Validacion Raw](docs/validar_ingesta.sql) y
  [validacion OBT](docs/validar_obt.sql): controles agregados manuales.
- [Fase 1](docs/avance_fase_1.md): evidencia historica de infraestructura.
- [Snowflake setup](docs/snowflake_setup.sql), [Raw setup](docs/raw_setup.sql) y
  [OBT setup](docs/obt_setup.sql): preparacion documentada. No volver a ejecutarla
  para alterar el entorno actual.

Snowflake es externo. Existen PSET2_CAYAMBE, RAW/BRONZE/SILVER/GOLD/OBT,
COMPUTE_WH X-Small (auto_suspend=300 y auto_resume=true), rol y usuario de
servicio PSET2_PIPELINE_ROLE/PSET2_PIPELINE_SVC. La autenticacion por clave
cifrada se verifico desde Python y Kestra. La configuracion actual se conserva.

## Seguridad y limites

.env y .env.kestra.secrets son privados: nunca distribuirlos, mostrarlos,
copiarlos a documentos ni versionarlos, tampoco sus valores codificados.
Conservar claves fuera del repositorio y el HMAC privado existente. El worker
solicita credenciales en entrada oculta y carga el HMAC desde el archivo DPAPI
privado ya preparado. No se leyeron esos secretos para esta tarea.

No compartir .runtime, datos municipales, logs completos o salidas expandidas
de docker compose config/docker inspect. .gitignore excluye secretos, entornos,
datos y resultados; no sustituye las ACL. No ampliar permisos, exponer puertos,
montar el socket Docker ni cambiar TLS para facilitar la orquestacion.

HMAC es seudonimizacion, no anonimato. Fechas/importes pueden reidentificar.
El backfill captura el estado actual por periodo fiscal, incluidos movimientos
posteriores; no reconstruye saldos historicos ni valida una fecha efectiva
universal de emision.

## Pendientes de validacion

Ya se validaron la importacion de Flows y la planificacion sin carga. Falta
validar el rechazo de planes inseguros y errores permanentes. Luego, bajo
ejecucion manual explicita, demostrar un backfill acotado y su reutilizacion.
La recuperacion transitoria real sigue pendiente; no se acredita con una simple
repeticion exitosa.

Recopilar execution.id, revisiones, intentos, Inputs, Gantt y resumenes seguros.
Conservar separadas las evidencias manuales de dbt y Spark, vinculadas al mismo
UUID. Registrar digests de imagenes, reproduccion desde cero y una futura
coordinacion integral segura; no se crea el PDF final en esta tarea.

## Demostración con datos 100 % sintéticos (sin VPN)

Se ha validado una **modalidad adicional con datos ficticios**:
`kestra/flows/demo_sintetico_raw.yml` genera 10 obligaciones y 6 movimientos
ficticios en la base PSET2_DEMO_SINTETICO, separada de PSET2_CAYAMBE. Permite continuar manualmente con
los modelos dbt existentes y el trabajo PySpark/OBT. No utiliza la VPN ni
extrae datos de SQL Server municipal. No reproduce la extracción SQL Server del
proyecto real: simula la fuente con consultas sintéticas ejecutadas por Kestra.

Instrucciones, dependencias, resultados finales y guardarraíles en
[demo/README.md](demo/README.md). La evidencia sintética del lote
`11111111-2222-4333-8444-555555555555` se conserva separada de la evidencia
original del flujo municipal documentada arriba. La demo reutilizó la cuenta
y el usuario de servicio del estudiante con una base exclusiva:
`PSET2_DEMO_SINTETICO`. Para reproducirla, el docente debe configurar su propia
cuenta Snowflake y el entorno descrito en la guía; no basta con clonar el repositorio.


