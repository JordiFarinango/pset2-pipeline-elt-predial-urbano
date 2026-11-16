# Apache Spark y OBT urbana

Codigo preparado el 15 de noviembre de 2026; NO ejecutado durante esta tarea.
No se instalaron dependencias, invoco Docker/Spark ni conecto con Snowflake.
No se declara exito hasta completar la ejecucion y validacion manual.

## Estado de entrada reportado

El responsable confirmo ingesta 10 obligaciones/6 movimientos e idempotencia,
y dbt build con 10 modelos, 113 pruebas de datos, 123 PASS, 1 WARN y 0 ERROR.
La advertencia observaciones_calidad se conserva. Es evidencia aportada de las
fases anteriores, no una prueba de este nuevo job Spark.

Se inspeccionaron Compose, spark-defaults.conf, modelos dbt reales, configuracion
dbt, docs/dbt_modelo.md e ingesta/contract.json. El contrato nuevo enumera las
57 columnas de FCT_OBLIGACIONES, 50 de FCT_MOVIMIENTOS y dimensiones implementadas.
No se inspeccionaron .env, .env.kestra.secrets, claves privadas o datos fiscales.

## Decision de integracion

Se estudio primero el conector nativo. La documentacion soporta Spark 3.5 y
Scala 2.12, y muestra autenticacion con una copia descifrada de la clave en
memoria mediante pem_private_key. No es una incompatibilidad criptografica:
requiere descifrado protegido y dependencias adicionales. Tambien exige USAGE
y CREATE STAGE sobre los esquemas de lectura/escritura. CREATE STAGE no figura
en los permisos reportados y no se concedio ni comprobo.

Por esa diferencia con los permisos existentes y para mantener la clave fuera
del contenedor, se implementa expresamente la alternativa acotada:

~~~mermaid
flowchart LR
    G["Snowflake Gold + ledger confirmado"] --> H["Puente Python Windows: I/O acotado"]
    H --> S["Contenedor existente: PySpark 3.5.8"]
    S --> A["groupBy movimientos por obligacion/lote"]
    A --> J["JOIN con obligaciones y dimensiones unicas"]
    J --> V["Validacion Spark y resultado protegido"]
    V --> H
    H --> O["Transaccion: OBT_URBANO_OBLIGACIONES"]
~~~

No se afirma que se haya probado y fallado el conector nativo. No hay fallback
silencioso en tiempo de ejecucion: la implementacion usa siempre el puente
documentado, sin nuevos grants ni dependencias JDBC. La opcion nativa estudiada
para una futura revision es:

| Componente nativo estudiado, NO instalado/usado | Version |
|---|---|
| spark-snowflake Scala 2.12 / Spark 3.5 | net.snowflake:spark-snowflake_2.12:3.2.0-spark_3.5 |
| JDBC declarado por ese build oficial | net.snowflake:snowflake-jdbc:4.0.2 |

No se recomienda migrar sin revisar compatibilidad, parches y permisos vigentes.

## Dependencias realmente utilizadas

| Ubicacion | Dependencia |
|---|---|
| Docker existente | apache/spark:3.5.8-scala2.12-java17-python3-ubuntu |
| Contenedor | PySpark 3.5.8 y bibliotecas Python estandar de la imagen; sin pip, pandas, Arrow o JAR nuevos |
| Runtime JVM | Spark 3.5.8, Scala 2.12 y Java 17; comprobados por el codigo al ejecutarse |
| Windows | Python 3.11+ y snowflake-connector-python==5.2.0 |
| Windows | Cliente Docker Compose existente, solo para exec sobre spark |

El parche Scala efectivo y Spark app id se obtendran del runtime y quedaran
en el resumen real; no se inventa un resultado de inspeccion del contenedor.
El puente no necesita PySpark instalado en Windows.
Se fija una tuberia LOCAL de Docker Desktop para no transmitir registros a un
contexto remoto accidental: PSET2_DOCKER_PIPE usa
npipe:////./pipe/dockerDesktopLinuxEngine. Si tu instalacion usa la tuberia local
anterior, permite npipe:////./pipe/docker_engine. No se aceptan endpoints TCP
remotos; seleccionar la tuberia no cambia configuraciones de Docker.

## Archivos

- spark/Run-OBT.ps1: lanzador manual; credenciales solo de entorno privado.
- spark/publish_obt.py: lectura explicita Gold/ledger, transporte a Spark,
  validacion independiente y publicacion transaccional en OBT.
- spark/run_container.py: transporte stdin -> archivos privados en tmpfs ->
  spark-submit -> resultado IPC. No autentica ni transforma datos de negocio.
- spark/build_obt.py: trabajo PySpark con agregaciones, JOIN y validaciones.
- spark/obt_common.py y obt_contract.json: tipos, columnas y limites explicitos.
- spark/requirements-host.txt y config.obt.example.ps1: dependencias y plantilla
  publica, sin secretos.
- docs/obt_setup.sql y validar_obt.sql: preparacion y controles agregados.

Compose, spark-defaults.conf, Kestra, ingesta y dbt se conservan sin cambios.
El montaje existente ./spark:/workspace/spark:ro hace visibles los archivos;
no es necesario recrear servicios o construir imagenes.

## Configuracion y primera ejecucion manual

Ejecutar desde la carpeta pset_2 EXISTENTE, con Docker Desktop y spark iniciados,
Gold construido para el lote y dbt sin ejecuciones concurrentes.

El Python por defecto es la .venv del proyecto, que debe tener el conector
fijado ya utilizado para la ingesta. No modificar el entorno del worker para
resolver dependencias. Si necesitas otro entorno, solo tras autorizar su
instalacion manual:

~~~powershell
$pythonHost = Read-Host 'Ruta a un Python 3.11+ autorizado'
& $pythonHost -m venv .\spark\.venv
.\spark\.venv\Scripts\python.exe -m pip install -r .\spark\requirements-host.txt
# En los comandos siguientes agregar:
# -Python "$PWD\spark\.venv\Scripts\python.exe"
~~~

No se ejecutaron estos comandos. La nueva .venv queda ignorada por las reglas
existentes; no se agrega PySpark al host ni se instalan paquetes en el contenedor.
La resolucion transitiva/digests de imagen sigue pendiente de consolidacion.

Reutilizar las variables privadas existentes de dbt. Si hace falta otra sesion:

~~~powershell
. .\spark\config.obt.example.ps1
. .\dbt\Set-SessionSecrets.ps1
~~~

El helper existente pide la ruta absoluta de la clave cifrada y su passphrase
con entrada oculta. No lee archivos .env ni la clave. Las variables requeridas
son DBT_ENV_SECRET_PRIVATE_KEY_PATH y DBT_ENV_SECRET_PRIVATE_KEY_PASSPHRASE.
Las variables publicas DBT_SNOWFLAKE_* deben corresponder a la cuenta
XSDIWIV-XZ59673, usuario PSET2_PIPELINE_SVC, rol PSET2_PIPELINE_ROLE, base
PSET2_CAYAMBE y warehouse COMPUTE_WH. El puente rechaza otro destino.
No pasar credenciales mediante argumentos, ficheros del proyecto o YAML.

La carpeta .runtime privada, preparada en la ingesta, debe conservar sus ACL:
usuario Windows actual y SYSTEM. El lanzador valida esas ACL y mantiene un
bloqueo local de publicacion; no las amplia ni inspecciona sus datos.

Preparar una vez la tabla con el propio usuario/rol de servicio:

~~~powershell
powershell.exe -NoProfile -File .\spark\Run-OBT.ps1 -PrepararTabla
~~~

Este comando ejecutara docs/obt_setup.sql, exclusivamente CREATE TABLE IF NOT
EXISTS en OBT. No altera tablas preexistentes, usuarios, claves, warehouse o
grants. Si el contrato no coincide, falla sin reemplazarlo.

Ejecutar el job sobre el UUID REAL ya confirmado, que no fue incluido en esta
solicitud y no se obtiene leyendo archivos privados:

~~~powershell
$lote = Read-Host 'UUID real del lote 10 obligaciones / 6 movimientos'
powershell.exe -NoProfile -File .\spark\Run-OBT.ps1 -LoteId $lote -EsperadasObligaciones 10 -EsperadosMovimientos 6
~~~

Ese comando iniciara el trabajo Spark REAL dentro del contenedor existente.
No ejecutar run_container.py directamente en una consola: su stdout es un
canal privado de registros protegidos dirigido exclusivamente al puente.
Run-OBT.ps1 solo muestra el resumen agregado final. No usar debug, transcripts,
capturas de stdout del transporte o inspeccion de entornos.

El resumen, si todas las comprobaciones y commit terminan, incluira motor
pyspark_dataframes, Spark/Scala/Java efectivos, spark_app_id, lote_id, filas_obt,
obligaciones/movimientos y diferencias nulas. Los resultados esperados son
10/6, 10 filas OBT y ceros de errores: NO son resultados obtenidos aun.

## Lecturas y transformaciones

El puente lee solo columnas enumeradas y filtra SIEMPRE por UUID. Exige una
fila de INGESTA_LOTES con COMMIT_EN no nulo, cantidades positivas/coherentes y
presencia completa de ese lote en Gold. No selecciona automaticamente el ultimo.
Tambien comprueba contrato de columnas/tipos antes de recoger filas.

PySpark crea DataFrames con StructType explicito: DecimalType(16,2) para
componentes y DecimalType(38,2) para sumas, sin pandas ni floats. Se activa ANSI
y se deshabilita perdida de precision decimal. Capturas TIMESTAMP_TZ se
transportan como ISO UTC para no perder la zona y se escriben como TIMESTAMP_TZ(3).

En Spark se realizan:

1. Validaciones de claves unicas/no nulas, lote/captura/version, relaciones,
   contexto y once roles de fecha. Se conserva el miembro fecha desconocida 0.
2. groupBy(obligacion_id,lote_id) sobre TODOS los movimientos; sin excluir
   estados, signos, documentos o anomalias.
3. Recalculo de los seis conteos, seis sumas y dos extremos de fecha existentes
   en Gold; comparacion por obligacion contra FCT_OBLIGACIONES.
4. Sumas adicionales de los otros componentes, conteo de saldos informados,
   contextos distintos y movimientos con algun flag de calidad.
5. LEFT JOIN del agregado contra obligaciones, y JOIN con dimensiones unicas.
   Las cantidades se comprueban despues para detectar multiplicacion.
6. Indicadores descriptivos de presencia, fechas desconocidas, advertencias y
   dias entre el primer/ultimo movimiento declarado.

No hay pushdown de esas transformaciones a Snowflake: el job no usa un conector
Spark-Snowflake; los SELECT del puente solo transportan Gold. Los GROUP BY SQL
que aparecen al final son controles independientes del resultado, no construyen
la OBT. El codigo no usa show(), SQL CTAS de la OBT o collect() ilimitado.

## Grano, columnas y significado

Destino: PSET2_CAYAMBE.OBT.OBT_URBANO_OBLIGACIONES.
Grano logico: (LOTE_ID, OBLIGACION_ID), una obligacion de una captura.
90 campos explicitos en obt_contract.json:

- Los 57 campos Gold de obligacion se conservan: id HMAC, lote/version/captura,
  anio fiscal, componentes, total declarado, fechas, codigos, flags, FK y resumen
  de movimientos. El resumen se recalcula realmente en Spark y se contrasta.
- 13 sumas adicionales de componentes de movimiento, sin sumar SALDO.
- Cantidades de saldos informados, contextos y movimientos con advertencias.
- tiene_movimientos, tiene_documentos_ab, tiene_movimientos_estado_a,
  tiene_totales_nulos y obligacion_con_advertencias.
- dias_entre_movimientos_declarados, origen del contexto y atributos de las
  fechas de emision/pago actual (anio, mes, dia ISO, miembro desconocido).
- OBT_VERSION y OBT_PROCESADO_EN (UTC del ejecutor).

Los conteos son cero cuando no hay movimientos; las sumas y extremos de fecha
permanecen NULL sin valores observados. Todos los importes conservan signo;
no se sustituyen importes ausentes por cero. Las dimensiones no fabrican
semanticas para los estados. Un documento AB/FA o una suma de totales no
certifica cancelacion completa, pago neto ni saldo actual.

No se agrega un target a 90 dias. Fechas efectivas e historial completo siguen
sin validarse. Los estados actuales y eventos posteriores no se consideran
automaticamente predictores disponibles al origen. El lote 10/6 es una muestra
tecnica, no una demostracion de cobertura municipal.

## Publicacion e idempotencia

Tras el exito de Spark, se abre una transaccion: DELETE unicamente WHERE
LOTE_ID=UUID, INSERT parametrizados de las filas resultantes, validaciones y
COMMIT. No hay overwrite global, TRUNCATE o reemplazo de otros lotes. Un fallo
revierte la sustitucion del lote y conserva su version anterior.

Se vuelven a comprobar conteos, unicidad, dinero/campos Gold, agregados y
cantidad de filas de otros lotes antes de commit. Solo escribe en OBT.
La tabla debe ser propiedad del rol de servicio, con SELECT/INSERT/DELETE
efectivos; CREATE TABLE en OBT permite prepararla con ese mismo rol.
Se necesitan SELECT en Gold/ledger y USAGE ya reportados. No se verificaron
grants ni se cambiaron permisos. No se necesita CREATE STAGE con este puente.

Para demostrar idempotencia, repetir EXACTAMENTE el comando del job con el
mismo $lote, sin volver a crear UUID ni repetir ingesta/dbt. La segunda ejecucion
vuelve a procesar realmente con Spark y reemplaza solo ese lote. Filas/ids,
importes y metricas deben permanecer iguales; OBT_PROCESADO_EN cambia.

Ejecutar manualmente docs/validar_obt.sql con el UUID, antes/despues:
cantidades Gold/OBT, ledger, unicidad, nulos, conservacion de valores,
reconciliacion de agregados y control HASH_AGG excluyendo el instante de proceso.
Se esperan 10 obligaciones, 6 movimientos representados y cero diferencias;
el control agregado y otros lotes deben permanecer iguales. El hash es solo
un control auxiliar, no prueba criptografica o anonimizacion.

## Limites y seguridad

Esta es una solucion ACOTADA de laboratorio, no una ruta distribuida escalable
de transferencia. Recoge Gold en memoria de Windows y crea DataFrames desde
listas en el driver Spark. El resultado se recorre con toLocalIterator y
regresa al puente para INSERT por bloques de 200.
Topes fijos: 1.000 obligaciones, 10.000 movimientos, 20.000 filas por dimension
y 32 MiB por mensaje. Si se superan, falla, no trunca. El limite de bytes se
comprueba despues de recoger el conjunto acotado por filas. Para escalar se
necesita revisar memoria y un conector distribuido autorizado.

Los registros ya seudonimizados pasan por pipes privados y por archivos modo
0600 en un directorio 0700 del /tmp existente (tmpfs). Se eliminan al salir
normalmente o por excepcion; un corte abrupto puede requerir revisar los
procesos y limpiar el tmpfs manualmente. No se escriben datos en el repositorio,
Windows o un bind mount de resultados. La clave privada y passphrase permanecen
en Windows; no entran al contenedor, imagen, argumentos o SparkConf.
Docker Compose usa su .env local habitual sin imprimir su contenido.

Timeout: Spark 20 minutos, puente Docker 22,5 minutos, lanzador 30 minutos.
Abortar el cliente Docker no garantiza detener instantaneamente un exec remoto;
el proceso aislado no tiene credenciales para publicar. Si hubo un commit
ambiguo, revisar OBT y repetir el mismo UUID. No recrear infraestructura para
resolverlo automaticamente.

Solo un publicador local por proyecto/host: bloqueo de archivo .runtime.
No hay mutex distribuido y Snowflake no impone UNIQUE en tablas estandar.
No ejecutar publicadores desde otros equipos ni dbt builds concurrentes:
Gold se lee en varias consultas y no constituye un snapshot global transaccional.
No se concede acceso a nuevos usuarios. Raw/Bronze/Silver/Gold no se modifican.

Importes/fechas/HMAC permiten reidentificacion por cruces. Restringir OBT, el
host, tmpfs/swap e historial de consultas. No distribuir filas, claves, variables
privadas o dumps. El puente sanea errores y descarta mensajes internos JVM/SDK;
revisar dependencias y permisos ante fallo sin habilitar dumps de registros.

Pendiente: ejecucion real, compatibilidad del runtime, conectividad/permisos
efectivos, preparacion de tabla, primer 10/6, segundo disparo y evidencia SQL.
No hay nueva orquestacion Kestra de Spark en esta tarea ni PDF final.

## Referencias oficiales

- [Requisitos y CREATE STAGE del conector](https://docs.snowflake.com/en/user-guide/spark-connector-install).
- [Clave cifrada y pem_private_key](https://docs.snowflake.com/en/user-guide/spark-connector-use#using-key-pair-authentication-key-pair-rotation).
- [Build 3.2.0: Spark/Scala y JDBC 4.0.2](https://github.com/snowflakedb/spark-snowflake/blob/v3.2.0/build.sbt).
- [Runner Python de Spark 3.5.8](https://github.com/apache/spark/blob/v3.5.8/core/src/main/scala/org/apache/spark/deploy/PythonRunner.scala).
- [Conector Python 5.2.0](https://pypi.org/project/snowflake-connector-python/5.2.0/).
