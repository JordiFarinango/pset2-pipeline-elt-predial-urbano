# Orquestacion, reintentos y backfill de demostracion

Actualización estática del 16 de noviembre de 2026: se conserva el protocolo de
retry y backfill descrito aquí. Se añade por separado
`kestra/flows/ingesta_programada_urbano.yml`, con Schedule semanal deshabilitado,
plan vacío y `ejecutar=false`. No se importó ni activó. Sus condiciones de
autorización, dependencias, límites y pendientes se describen en el README
principal. Las referencias siguientes a ausencia de calendario corresponden
a los Flows originales; estos continúan sin trigger propio. La importación de
ingesta/backfill y la planificación sin carga fueron comunicadas posteriormente
como exitosas; no validan retries transitorios ni backfill con extracción real.

15 de noviembre de 2026. Cambios preparados mediante lectura y edicion de codigo.
No se importaron Flows, reiniciaron servicios ni ejecutaron pruebas o cargas.
Los resultados existentes siguientes fueron comunicados por el responsable;
no son nuevas mediciones de esta implementacion.

## Evidencia existente y alcance

Lote validado: 8e977e06-ce56-4b4d-9781-cdf6766fb79c.

| Componente | Evidencia comunicada | Alcance |
|---|---|---|
| SQL Server -> Kestra -> Raw | SUCCESS, 10 obligaciones y 6 movimientos | Una muestra fiscal; no carga historica completa |
| Repeticion del lote | reutilizado=true, sin duplicacion | Idempotencia del UUID confirmado |
| dbt Bronze/Silver/Gold | 10 modelos, 113 pruebas; 123 PASS, 1 WARN, 0 ERROR | dbt build manual; conservar el WARN de calidad |
| PySpark 3.5.8 -> OBT | Trabajo y segunda publicacion exitosos | Ejecucion manual real; no solo contenedor iniciado |
| Consulta independiente OBT | 10 filas, 10 ids unicos, 6 movimientos, 0 ids nulos | Control agregado, sin registros individuales |
| Retry selectivo y Flow de backfill nuevos | Codigo preparado | Importacion y ejecucion aun NO validadas |

No se conocen aqui IDs de ejecucion, revisiones ni duraciones adicionales.
Vincular esos comprobantes reales al UUID cuando se recopile la evidencia.

## Que orquesta Kestra

Kestra solicita, espera y comprueba el resultado de la ingesta Raw mediante
submit.sh y el worker Windows. El worker usa la VPN, protege identificadores
en memoria y publica ambas tablas y el ledger mediante el cargador existente.
Las filas nunca pasan por el puente ni por outputs de Kestra.

El backfill llama serialmente al mismo Flow de ingesta, con parametros
explicitos. No hay calendario ni carga al importar los YAML. En modo
planificacion ni siquiera se escribe una solicitud al puente.

dbt y Spark continuan MANUALES en Windows. El puente admite exclusivamente el
contrato de ingesta; no ofrece ejecucion arbitraria de comandos. dbt usa su
.venv-dbt y secretos de sesion; Run-OBT.ps1 usa la sesion Windows y el cliente
Docker local. Kestra Linux no dispone de esos lanzadores, clave ni entorno.
No existe una ruta no interactiva ya preparada para coordinarlos desde ese
puente. Incorporarla requeriria ampliar su protocolo y revisar bloqueo,
credenciales privadas del worker y saneamiento de logs dbt. No se introduce
ese cambio ni se monta un socket Docker o clave en Kestra.

Existe una arquitectura ELT con etapas verificadas por separado, NO una
orquestacion integral automatica validada.

## Politica de reintentos

ingesta_raw_urbano mantiene concurrency.limit=1 y QUEUE. La tarea
solicitar_y_esperar tiene maxAttempts=3: intento inicial y hasta dos reintentos,
esperas exponenciales de 30 y 60 segundos, maxInterval=1 minuto y
maxDuration=100 minutos. Cada intento conserva timeout=35 minutos; la solicitud
Windows vence a los 30 minutos. warningOnRetry=true permite identificar una
recuperacion como WARNING.

| Situacion | Clasificacion y accion |
|---|---|
| SqlException cuyos numeros son exclusivamente -2, 1205, 1222, 10053, 10054 o 10060 | SQL_TRANSITORIO: timeout, deadlock, espera de bloqueo o corte TCP reconocido. Reintentar de forma acotada |
| SQL 18456 | SQL_AUTENTICACION_FALLIDA: detener, no repetir credenciales |
| Certificado, permisos, parametros, esquema, topes, HMAC/contrato o calidad | Detener para revision; ninguna verificacion se desactiva |
| Fallo generico del conector Snowflake | No se clasifica como transitorio sin evidencia: revision manual |
| Cargador sin respuesta, commit ambiguo, worker ausente o resultado desconocido | No crear otra solicitud automaticamente; reconciliar ledger y worker |
| Cualquier excepcion desconocida | Codigo saneado; revision manual |

Los numeros SQL se inspeccionan solo en memoria. No se publican mensajes,
consultas, trazas, claves, filas ni valores fiscales.

La distincion usa el protocolo, no una propiedad retryCondition supuesta:

1. El worker publica SQL_TRANSITORIO y retryable=true solo despues de cerrar la
   lectura y terminar el proceso hijo del intento fallido.
2. submit.sh sale con codigo 1 para ese resultado reconocido; Kestra aplica
   su retry. Los fallos permanentes producen status=failed con salida de shell 0.
3. exigir_confirmacion, sin retry, exige status=success. Asi el Flow completo
   FALLA ante un error permanente aunque la tarea de transporte haya terminado.
4. Un fallo inesperado de infraestructura tambien puede activar el retry nativo,
   pero el siguiente intento NO encola otra extraccion sin respuesta transitoria
   terminal del intento anterior.

Los request_id terminan en -a0, -a1 y -a2: son identificadores de control
distintos. lote_id, rango, limite, HMAC e ID_VERSION permanecen iguales.
El script nunca genera UUID de lote. El manifiesto privado y el ledger conservan
las comprobaciones previas: un UUID con otro contrato se rechaza; un lote ya
confirmado se reutiliza antes de volver a leer SQL Server.

Si falta la respuesta anterior: INTENTO_ANTERIOR_SIN_CONFIRMAR.
Si el worker no responde: WORKER_SIN_RESPUESTA_RECONCILIAR_LEDGER. No borrar
solicitudes, resultados o manifiestos para forzar un reintento. Al recuperar
el entorno, crear otra ejecucion con EXACTAMENTE el mismo UUID y parametros,
solo despues de confirmar que no queda trabajo previo activo.

## Configuracion y despliegue manual

Desde el pset_2 existente, sin trabajos activos:

1. Conservar los montajes de docker-compose.ingesta.yml: ingesta de solo lectura
   en /opt/pset2-ingesta y puente en /opt/pset2-bridge. No se cambia Compose.
2. Detener el worker entre solicitudes y volver a iniciarlo para leer el
   clasificador nuevo. Mantener el HMAC y la clave cifrada existentes.
   Seguir docs/ingesta_raw.md; no modificar secretos ni ACL.
3. Importar primero kestra/flows/ingesta_raw_urbano.yml como nueva revision del
   Flow existente; despues importar kestra/flows/backfill_raw_urbano.yml.
   Conservar hola_pset2 y verificar_snowflake. Guardar/importar no inicia ingesta.
4. Confirmar que Kestra 2.0.9 acepta las definiciones. Se usa Loop (Kestra 2),
   no ForEach, y fromJson(item.value) para sus objetos.
5. Registrar las revisiones y no editarlas durante la demostracion.
   Subflow usa la revision vigente de ingesta_raw_urbano.

No hay nuevas dependencias. Bash usa comandos locales basicos y GNU date del
contenedor; su disponibilidad y las expresiones/plugins concretos deben
comprobarse manualmente al importar/ejecutar. No se ejecutaron aqui.

## Backfill manual, primero sin extraccion

El input plan es texto: una linea por periodo, sin cabecera ni espacios:

~~~text
UUID_EN_MINUSCULAS,YYYY-MM-DD,YYYY-MM-DD,limite
~~~

El ultimo dia es exclusivo y el filtro sigue siendo AVA_FECHA. Antes de
despachar cualquier subflow se valida TODO el plan:

- Entre 1 y 3 periodos ordenados, disjuntos y con UUID distintos.
- Fechas reales, entre 1900 y 2100, con hasta 31 dias por intervalo.
- Limite de 1 a 10 obligaciones por periodo, hasta 30 en total; nunca limite=0.
- Se conservan TODOS los movimientos de las obligaciones elegidas. Su cantidad
  no se conoce antes de consultar; sigue aplicando el tope local del worker.
- No se aumentan topes locales. Si se superan, se falla sin truncar movimientos.

Demostracion propuesta, aun NO ejecutada: un mes de 2024, con limite=1.
No hay evidencia aqui de que ese mes tenga obligaciones. Si esta vacio,
SIN_OBLIGACIONES_EN_RANGO requiere revision, no un exito inventado.

Generar UN UUID una vez en PowerShell y conservar la linea resultante:

~~~powershell
$loteBackfill = [guid]::NewGuid().ToString('D')
$planBackfill = "$loteBackfill,2024-01-01,2024-02-01,1"
$planBackfill
~~~

En la UI local de Kestra, ejecutar backfill_raw_urbano con:

~~~yaml
plan: 'PEGAR_LA_LINEA_GENERADA'
ejecutar: false
confirmacion: PLANIFICAR
~~~

Esto solo valida y genera plan_backfill.json con parametros y limites; NO
consulta tablas ni requiere el worker armado. Revisar el plan. Para una
demostracion REAL, cuando se decida ejecutarla, repetir los mismos parametros:

~~~yaml
ejecutar: true
confirmacion: EJECUTAR_MUESTRA
~~~

Requiere worker armado, VPN y credenciales locales privadas ya existentes.
Para esta demostracion, despues de la configuracion habitual y con el worker
detenido entre solicitudes, iniciarlo con topes de sesion reducidos:

~~~powershell
$env:PSET2_MAX_OBLIGACIONES = '10'
$env:PSET2_MAX_MOVIMIENTOS = '100'
powershell.exe -NoProfile -File .\ingesta\Start-Worker.ps1
~~~

Estos comandos son instrucciones manuales, NO se ejecutaron aqui. No editan
archivos de configuracion ni secretos. El conteo fuente rechaza el periodo si
los movimientos exceden 100, antes de enviar filas al cargador; no se recorta
el historial. Con tres periodos, el maximo configurado es 300 movimientos.
Confirmar estos topes antes de activar ejecutar=true: el Flow no puede verificar
las variables privadas del worker y no sustituye ese control local.

Cada periodo llama ingesta_raw_urbano con wait=true y transmitFailed=true,
concurrencyLimit=1; la ingesta conserva su propia cola global serial.
No se reintenta el padre/subflow entero automaticamente; los reintentos son
los selectivos de la tarea de ingesta. Un fallo hijo hace fallar al padre.

Repetir el mismo plan conserva los UUID: los periodos confirmados deben dar
reutilizado=true. No reutilizar un UUID entre periodos distintos. No asignar el
UUID validado 10/6 al ejemplo mensual: su contrato fiscal podria ser distinto.
Un plan fallido se reanuda manualmente conservando la linea original de cada
periodo, sin regenerar sus UUID.

Este backfill es una muestra de capturas por periodo fiscal, NO una extraccion
completa ni una reconstruccion de saldos historicos. Captura el estado actual
y movimientos presentes, incluso posteriores al periodo. No sumar snapshots
duplicados ni afirmar un target de impago a 90 dias.

## Continuacion manual de las etapas verificadas

Esperar a que terminen los subflows necesarios. Verificar cada UUID en ledger
con docs/validar_ingesta.sql y elegir UN lote para cada ejecucion posterior.
Usar los conteos reales de ese lote; otro periodo no necesariamente tiene 10/6.

1. Ejecutar dbt build en su sesion Windows con --vars del lote y conteos reales,
   siguiendo docs/dbt_modelo.md. Conservar la advertencia de calidad.
2. Solo tras finalizar dbt, ejecutar spark/Run-OBT.ps1 para el mismo lote, con
   EsperadasObligaciones y EsperadosMovimientos reales; ver docs/spark_obt.md.
3. Repetir la publicacion del mismo lote y comprobar docs/validar_obt.sql.

No ejecutar dbt/Spark de varios lotes en paralelo. El bloqueo de ingesta no
protege las sustituciones dbt ni los lanzadores manuales OBT.
La construccion dbt por lote no acredita una consolidacion historica multilote.

## Validacion y evidencias por obtener (NO ejecutadas)

| Comprobacion manual | Resultado esperado, no observado aqui |
|---|---|
| Importar ambos YAML | Definiciones aceptadas en Kestra 2.0.9; conservar revision |
| Backfill ejecutar=false, un periodo valido | Plan generado; sin subflow ni solicitud al puente |
| Plan solapado, UUID repetido, limite=0 o rango anual | FAILED en validar_plan, sin extraccion |
| Ingesta con lote_id=UUID_INVALIDO | FAILED en exigir_confirmacion, LOTE_INVALIDO, sin consulta ni reintento de carga |
| SQL_TRANSITORIO real y reconocido, cuando exista | Hasta 3 intentos, mismo UUID y parametros; solicitudes -a0/-a1/-a2 seriales |
| Error permanente o desconocido | Sin nueva carga automatica; codigo seguro para revision |
| Backfill real explicito, un periodo limite=1 | Cantidades reales y resumen seguro del hijo; no asumir un rango no vacio |
| Repetir ese plan identico | reutilizado=true para lotes confirmados y ausencia de duplicacion segun ledger |

No provocar fallos cambiando VPN, certificados, permisos, secretos o firewall.
La recuperacion automatica queda pendiente hasta observar una condicion
transitoria real o probarla en un entorno aislado autorizado. No presentar
una repeticion exitosa como evidencia de que hubo un retry transitorio.

Conservar capturas de Inputs, Gantt/Iterations, estado final, revisiones,
intentos y resumen.json/plan_backfill.json. Registrar execution.id, lote_id,
filtros, limite, reutilizado, contadores y duracion realmente observada.
Seguir cada enlace de ejecucion hija; no hay resumen financiero multilote.
Las evidencias dbt y Spark son manuales separadas; enlazarlas con el mismo UUID.

No adjuntar .env, .env.kestra.secrets, claves, manifiestos .runtime, dumps de
entornos, logs completos dbt/JVM, SQL con valores ni filas seudonimizadas.
Compartir metadatos operativos solo en el ambito autorizado.

## Fuentes de sintaxis consultadas

- [Retries de tareas](https://kestra.io/docs/workflow-components/retries).
- [Loop en Kestra 2](https://kestra.io/docs/migration-guide/v2.0.0/foreach-loop).
- [Objetos en Loop](https://kestra.io/docs/how-to-guides/loop).
- [Subflows](https://kestra.io/docs/workflow-components/subflows).
- [Outputs shell](https://kestra.io/docs/how-to-guides/shell).
