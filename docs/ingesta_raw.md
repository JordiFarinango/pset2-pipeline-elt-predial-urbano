# Ingesta batch hasta Raw: muestra real validada y orquestacion preparada

15 de noviembre de 2026. El responsable confirmo SUCCESS con 10 obligaciones
y 6 movimientos para 8e977e06-ce56-4b4d-9781-cdf6766fb79c, y repeticion con
reutilizado=true sin duplicacion. No se repitieron esas operaciones aqui.
Los nuevos reintentos selectivos y el backfill manual siguen pendientes de
importacion y validacion: ver [orquestacion.md](orquestacion.md).
No se ejecutaron instalaciones, builds, pruebas, Docker ni conexiones durante
esta actualizacion. La fase 1 conserva su evidencia historica propia.

## Arquitectura

~~~text
Kestra (Process runner: submit.sh)
 -> solicitudes/respuestas en carpeta local .runtime/bridge
 -> worker Windows PowerShell 5.1
 -> SELECT SQL Server por VPN / System.Data.SqlClient
 -> HMAC y fechas diarias en memoria Windows
 -> tuberia stdin privada -> Python -> Snowflake Raw
 -> commit de ambas tablas + ledger -> resumen agregado -> Kestra
~~~

Arrancar el worker no extrae datos. Una solicitud del Flow dispara la extraccion
y carga; Kestra espera y marca fallo si el worker falla. No hay servicio HTTP de
extraccion, puerto nuevo ni socket Docker. Compose base, application.yaml y los
Flows verificados se conservan. El override agrega solo dos montajes a Kestra.
Activarlo manualmente requiere recrear ese contenedor; PostgreSQL y volumenes
persistentes se conservan.

El puente solo almacena parametros, identificadores operativos y contadores.
Las filas protegidas no pasan por archivos ni almacenamiento de Kestra. Los
identificadores originales permanecen en la memoria del lector .NET: nunca se
envian al subproceso Python o a Snowflake.

## Contrato y proteccion

ingesta/contract.json enumera las 27/35 columnas confirmadas en la auditoria.
El SELECT usa esa lista fija, nunca SQL recibido de Kestra. Al ejecutar, el
lector comprueba tipos .NET, longitudes y precision/escala. No se verifico otra
vez la fuente durante el desarrollo.

Filtro: AVA_FECHA >= fiscal_desde AND AVA_FECHA < fiscal_hasta. El limite aplica
a obligaciones ordenadas por la PK COMPLETA; se recuperan TODOS sus movimientos
mediante los cuatro componentes, sin filtrar estados o documentos. El limite
no recorta pagos por separado.

La muestra inicial de 10 es determinista, no estadisticamente representativa.
No garantiza contener pagos/abonos. Si devuelve cero movimientos, la ruta de
pagos no quedara validada: ampliar otro lote o periodo.

HMAC-SHA-256 utiliza un secreto independiente de exactamente 32 bytes aleatorios.
Canonizacion v1: JSON comprimido de un array ordenado de cadenas tipadas,
UTF-8, Windows PowerShell 5.1, con version y dominio separados:

- Obligacion: clave catastral exacta del padre, AVA_FECHA completa representada
  con siete posiciones fraccionarias .NET, PRO_CODIGO y SECUENCIAL_AR invariantes.
- Movimiento: dominio distinto, id protegido del padre, IMP_CODIGO y fecha/hora
  completa IMP_FECHA_PAGO. Se canonizan las claves del padre del JOIN SQL para
  evitar diferencias por collation, mayusculas o espacios de la FK.

La estabilidad depende de la misma PK, secreto, version y canonizacion. Una
correccion de la PK cambia el id derivado y requiere reconciliacion, no equivale
necesariamente a una nueva obligacion de negocio.

No se genera un id adicional de persona o predio. De AVA_FECHA solo se transmite
ANIO_FISCAL; no se transfieren claves originales o numeros municipales de factura.
Fechas destino DATE; importes NUMBER(16,2), mediante texto decimal invariante
y Decimal Python, nunca float. Se conservan nulos, signos, codigos y anomalias.
No se impone una ecuacion contable no reconciliada entre componentes y total.
HMAC es seudonimizacion, NO anonimizacion: importes y fechas pueden reidentificar.

Destino: 28 campos en obligaciones y 35 en movimientos, incluidos LOTE_ID,
CAPTURADO_EN (UTC del ejecutor, TIMESTAMP_TZ(3)) e ID_VERSION. CAPTURADO_EN marca
el inicio del intento confirmado, antes de leer SQL; no es fecha efectiva de
emision ni instante de un snapshot transaccional.

## Preparacion manual, solo cuando autorices la validacion

Ejecutar desde el pset_2 EXISTENTE. Usar Windows PowerShell 5.1 para los scripts.
No cambiar ExecutionPolicy ni elevar privilegios para sortear errores.

1. Requisitos: VPN activa, .NET System.Data.SqlClient, Python 3.11+ (recomendado
   3.12) en la .venv existente y conector Snowflake 5.2.0. No se inspecciono el
   entorno virtual. Si autorizas instalar manualmente la dependencia:

~~~powershell
.\.venv\Scripts\python.exe -m pip install -r .\ingesta\requirements.txt
~~~

La dependencia directa esta fijada; falta lock transitivo tras validar plataforma.
No hay instalaciones automaticas en los scripts o Flows.

2. Configuracion no secreta para esta sesion:

~~~powershell
. .\ingesta\config.example.ps1
$env:SNOWFLAKE_PRIVATE_KEY_FILE = 'C:\RUTA_PRIVADA_FUERA_DEL_PROYECTO\clave-cifrada.p8'
~~~

Sustituir la ruta por la ubicacion autorizada existente, absoluta y fuera de
pset_2. No copiar la clave al proyecto; debe permanecer cifrada. Cuenta por
defecto xsdiwiv-xz59673. Usuario, rol, warehouse, base y tablas quedan fijados
al destino autorizado. La plantilla no contiene secretos.

3. Preparar puente y tablas, sin extraer:

~~~powershell
powershell.exe -NoProfile -File .\ingesta\Prepare-Bridge.ps1
powershell.exe -NoProfile -File .\ingesta\Initialize-Raw.ps1
~~~

Prepare-Bridge crea directorios dentro de .runtime y restringe sus ACL al
usuario actual y SYSTEM. Initialize-Raw pide la passphrase con entrada oculta y
ejecuta docs/raw_setup.sql con el rol de servicio. Solo crea las dos tablas y
el ledger si faltan; no altera usuarios, claves, warehouse o esquemas existentes.
Se requieren CREATE TABLE y propiedad de estas tablas por PSET2_PIPELINE_ROLE;
no se conceden permisos automaticamente. Si una tabla existente tiene otro
contrato, falla sin reemplazarla. Un administrador sin ese rol no necesita
recibirlo: utilizar el inicializador autenticado con el servicio.

4. Sin ejecuciones activas en Kestra, activar manualmente los montajes:

~~~powershell
docker compose --env-file .env -f docker-compose.yml -f docker-compose.ingesta.yml up -d --no-deps kestra
~~~

Mantener ambos archivos Compose al operar esta fase para conservar montajes.
.env y .env.kestra.secrets permanecen privados y no se sobrescriben. No usar down -v.

5. Comprobaciones minimas de TCP preparadas, NO ejecutadas por Codex:

~~~powershell
Test-NetConnection -ComputerName 172.23.7.22 -Port 1433 -InformationLevel Quiet
docker compose --env-file .env -f docker-compose.yml -f docker-compose.ingesta.yml exec -T kestra bash -c 'timeout 5 bash -c "exec 3<>/dev/tcp/172.23.7.22/1433"'
~~~

El primero comprueba Windows. El segundo devuelve codigo 0 si Docker abre TCP,
sin autenticar ni consultar datos: no acredita TLS o autenticacion. Si falla
Docker, esta arquitectura sigue usando Windows. Si falla Windows, detener y
revisar VPN/ruta; no cambiar firewall ni seguridad automaticamente. El montaje
del puente protegido tambien necesita validarse con Docker Desktop. No se
presupone que los contenedores hereden la VPN.

6. Importar mediante la UI local de Kestra el archivo
   kestra/flows/ingesta_raw_urbano.yml. No reemplazar los Flows de fase 1.
   Guardar/importar el YAML no dispara ingesta.

## Primera carga y segunda ejecucion

En una terminal Windows PowerShell dedicada, con las variables anteriores:

~~~powershell
powershell.exe -NoProfile -File .\ingesta\Start-Worker.ps1
~~~

Ingresar en los prompts ocultos la credencial SQL sim2001 y la passphrase de la
clave Snowflake. El worker actual carga el HMAC existente desde el archivo
DPAPI privado ya preparado para el usuario Windows; no pide generar otro HMAC.
Conservar el mismo secreto de 32 bytes para siguientes arranques. No copiarlo
al proyecto ni reutilizar contrasenas como HMAC.
El worker no lee .env ni .env.kestra.secrets. La passphrase pasa al subproceso
en su entorno privado en memoria, sin argumentos o archivos. El host debe ser
confiable: un administrador puede inspeccionar procesos.

En OTRA terminal, disparar el Flow:

~~~powershell
$lote = [guid]::NewGuid().ToString('D')
powershell.exe -NoProfile -File .\ingesta\Invoke-Ingesta.ps1 -LoteId $lote -FiscalDesde '2024-01-01' -FiscalHasta '2025-01-01' -Limite 10 -KestraEmail 'TU_CORREO_ADMIN_KESTRA'
~~~

Sustituir KestraEmail por el correo local; la contrasena se pide en dialogo,
nunca como argumento. Agregar -Port si no es 8080. El helper solo llama a la
API LOCAL de Kestra, no extrae datos. Alternativa: ejecutar el Flow en la UI
con los mismos cuatro inputs. Conservar el UUID mostrado para reconciliacion.

Esperar SUCCESS y revisar resumen.json en Kestra: obligaciones, movimientos,
ids_nulos, duplicados, huerfanos, reutilizado y segundos. No contiene filas
ni identificadores municipales. Un primer commit debe tener reutilizado=false.
La politica nueva puede terminar en WARNING si se recupero mediante retry.
Los ceros de calidad solo se reportan si pasaron las comprobaciones.

Repetir EXACTAMENTE el ultimo comando con el mismo $lote, rango y limite.
No generar otro UUID para este ensayo. Debe dar SUCCESS y reutilizado=true,
con las mismas cantidades y sin nuevas filas. El reintento confirmado valida
el destino y evita leer SQL Server otra vez. Esto fue comunicado como resultado
real del lote validado; cada reproduccion adicional debe comprobarse.

Ejecutar manualmente docs/validar_ingesta.sql sustituyendo el UUID: compara
ledger, cantidades, unicidad por lote, ids nulos, huerfanos y lotes duplicados.
No usar SELECT * ni exportar registros para comprobar. Si hay cero movimientos,
la ruta de pagos sigue pendiente de validar.

## Consistencia e idempotencia

- Fuente: dos SELECT parametrizados (conteos equivalentes y CTE TOP con LEFT
  JOIN completo). Sin procedimientos, tablas temporales o NOLOCK. Conexion 15 s,
  SELECT 60 s, Encrypt=True y TrustServerCertificate=True solo en pruebas.
  ApplicationIntent=ReadOnly no sustituye permisos SQL realmente restringidos.
- Antes de enviar filas se controlan cantidades y topes. Los ids distintos
  leidos se comparan con el conteo fuente previo. Si difieren, no hay commit.
- READ COMMITTED no garantiza una instantanea comun entre conteo y lectura.
  Cambios con igual cantidad pueden pasar inadvertidos. Se necesita fuente
  estable o una futura estrategia de snapshot aprobada; no se cambio esa politica.
- INSERT parametrizados en bloques de 200; ambas tablas y ledger se confirman
  juntos. No hay DDL en el lote, stages o CSV. Un fallo revierte los INSERT.
- Si el commit tiene respuesta ambigua, reintentar el MISMO UUID y revisar
  ledger antes de regenerarlo. No borrar filas para resolverlo.
- El ledger registra filtros, captura, versiones, key_tag no secreto (HMAC de
  constante de control), cantidades y digest del contenido protegido. Un UUID
  confirmado con otro contrato se rechaza. No cambiar HMAC bajo la misma
  ID_VERSION si ya existen lotes; la rotacion requiere una decision explicita.
- Conservar .runtime/batches de forma privada. Si se pierde un manifiesto pero
  existe el lote remoto, el conflicto exige reconciliacion; no inventar captura.
- Requisito de UNICO ESCRITOR: bloqueo exclusivo del worker local, Flow con
  concurrency=1 y cola serial. No arrancar otro worker en otro equipo ni escribir
  directamente en estas tablas. No hay mutex distribuido y Snowflake no impone
  UNIQUE en tablas estandar. Esta limitacion es parte del contrato operativo.
- La verificacion de un lote confirmado comprueba cantidades, unicidad y
  correspondencia, no una auditoria contra modificaciones manuales de importes.

## Backfill y reintentos selectivos

Usar el nuevo Flow manual backfill_raw_urbano segun
[orquestacion.md](orquestacion.md). Por defecto solo valida parametros: hasta
3 periodos disjuntos de hasta 31 dias y 1 a 10 obligaciones por periodo, con
30 como maximo total. Requiere UUID explicito por periodo; los reintentos
conservan ese UUID. La demostracion no permite limite=0 ni aumenta topes.
Todos los movimientos de las obligaciones seleccionadas conservan el tope
local existente; excederlo provoca fallo, no truncamiento silencioso.

El Flow individual anterior conserva su contrato (incluido limite=0), pero
NO debe usarse esa opcion para esta demostracion ni cargar anos completos.
La politica de retry solo crea otra solicitud ante SQL_TRANSITORIO reconocido
y terminal. Los errores permanentes, desconocidos o ambiguos exigen revision.
No se modifica SQL, HMAC, ledger, transacciones o validaciones de calidad.

Mismo rango con UUID nuevo representa nueva captura, no nueva obligacion/pago.
No sumar snapshots de distintos lotes en analisis financiero: elegir la captura
pertinente. Los conjuntos de ids residen en memoria y cada solicitud vence a
los 30 minutos; planificar particiones para volumenes superiores.

Se captura el estado ACTUAL, incluidos movimientos posteriores al periodo
fiscal. Un backfill no reconstruye estados historicos. Siguen sin validarse
fecha efectiva universal de emision y pago completo a 90 dias; no generar
etiquetas predictivas ni usar automaticamente el reloj adelantado del SQL Server.

## Seguridad, cancelacion y pendientes

Solo usuarios confiables deben administrar Kestra o escribir el puente: pueden
solicitar extracciones mientras el worker este armado. No ampliar ACL a Everyone
ni publicar servicios para resolver problemas de Docker Desktop sin revisar
seguridad. El contenedor no recibe credenciales municipales o HMAC.

Los errores son codigos saneados; no habilitar debug, transcripts, dumps de
filas o inspecciones de entornos. Raw y su historial de consultas contienen
informacion fiscal seudonimizada: restringir acceso y definir retencion.

No hay cancelacion inmediata del proceso Windows al cancelar Kestra. Se verifica
el plazo antes de commit, pero cancelar temprano puede dejar completar un lote.
Revisar ledger antes de repetir. Detener el worker preferiblemente entre lotes;
si se interrumpe durante carga, reconciliar el resultado antes de volver a iniciar.

La primera carga 10/6 y su reutilizacion ya fueron reportadas exitosas.
Pendiente de evidencia NUEVA: importacion de las revisiones, modo planificacion,
rechazo de planes inseguros, retry transitorio selectivo, backfill acotado y
repeticion de ese mismo plan. No se declara validada esa ampliacion.

## Referencias oficiales

- [Process runner](https://kestra.io/docs/task-runners/types/process-task-runner).
- [Shell y outputs](https://kestra.io/docs/how-to-guides/shell).
- [API de ejecuciones](https://kestra.io/docs/workflow-components/execution).
- [Transacciones](https://docs.snowflake.com/en/sql-reference/transactions).
- [Connector Python](https://docs.snowflake.com/en/developer-guide/python-connector/python-connector-api).
- [Dependencia 5.2.0](https://pypi.org/project/snowflake-connector-python/5.2.0/).
