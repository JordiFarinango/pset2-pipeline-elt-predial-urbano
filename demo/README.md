# PSet #2: demostración académica con datos sintéticos

La ejecución validada reutilizó la cuenta Snowflake del estudiante con base
exclusiva **PSET2_DEMO_SINTETICO**. El flujo municipal permanece en
**PSET2_CAYAMBE**, sin cambios. La reproducción en otra cuenta requiere la
preparación descrita abajo y **no ha sido validada en una cuenta diferente**.

## Justificación académica y protección de la información

La implementación original utilizó una instancia de pruebas de SQL Server del
Municipio de Cayambe que contiene información real de contribuyentes y
obligaciones tributarias. Por confidencialidad, privacidad y seguridad
institucional, el repositorio público no incluye registros originales,
extracciones, respaldos ni credenciales municipales. La seudonimización HMAC
del pipeline original no equivale a anonimización irreversible y no elimina
el riesgo de reidentificación mediante cruces de información.

Para permitir la evaluación académica se añadió una demo con registros
completamente ficticios, generados de forma determinista. Conserva el contrato
de columnas necesario para probar las transformaciones; no representa ni
reproduce contribuyentes reales. El Flow usa constantes, secuencias y SHA-256
sobre etiquetas ficticias públicas, sin consultar ni muestrear la fuente municipal.
Los registros de negocio son deterministas; metadatos como `COMMIT_EN` y
`OBT_PROCESADO_EN` dependen del instante de ejecución.

La demo no necesita VPN, usuario municipal ni conexión al SQL Server original.
Complementa la implementación real, pero no sustituye ni demuestra la extracción
desde SQL Server. Su recorrido es:

```text
Kestra (SQL sintético) -> Snowflake RAW -> dbt Bronze/Silver/Gold (manual)
                     -> puente Python Windows -> PySpark local -> Snowflake OBT
```

Spark transforma los datos en el contenedor; el puente Python lee Gold y publica
OBT con el conector Python de Snowflake. No se usa un conector Spark-Snowflake
nativo ni se entregan claves privadas al contenedor Spark.

## Evidencia final verificada — 15 de noviembre de 2026

La demo **comienza en Kestra con datos ficticios, no en SQL Server**. Kestra
genera los datos sintéticos y confirma el lote en RAW. A continuación, dbt y
PySpark se ejecutan **manualmente y en ese orden**; no se acredita una
orquestación integral automática.

- Lote sintético: `11111111-2222-4333-8444-555555555555`.
- Base exclusiva: `PSET2_DEMO_SINTETICO`.
- Kestra: **SUCCESS**, 5 tareas completadas.
- Snowflake RAW: **10 obligaciones, 6 movimientos sintéticos, lote confirmado**.
- dbt: **10 modelos, 113 pruebas, 123 PASS, 1 WARN, 0 ERROR, 0 SKIP**.
- Advertencia conservada: `observaciones_calidad`.
- PySpark: **SUCCESS**, 10 filas OBT, 6 movimientos, 0 identificadores nulos,
  0 duplicados, 0 diferencias de importes y agregados.

Los resultados reales verificados fueron comunicados por el responsable.
Esta actualización es documental: no se ejecutaron pruebas, builds ni nuevas
ingestas. La evidencia sintética no demuestra la extracción desde SQL Server
ni sustituye la evidencia original del flujo municipal.

## Requisitos y preparación de una cuenta propia

Esta guía procede de una auditoría de lectura del 16 de noviembre de 2026.
No es evidencia de una instalación desde cero ni de ejecución en otra cuenta.
Los comandos siguientes son instrucciones para una reproducción futura;
no se ejecutaron durante la auditoría.

### Entorno local

- Windows y PowerShell 5.1, Git, Python 3.12 para los entornos locales, Docker
  Desktop con contenedores Linux y Compose v2. El puente usa `msvcrt` y una
  tubería local de Docker Desktop; no se acredita ejecución en Linux/macOS.
- Acceso a Internet para dependencias/imágenes y a la cuenta Snowflake propia;
  warehouse con capacidad de ejecutar consultas y políticas de red compatibles.
  Snowflake puede generar consumo facturable.
- Imágenes fijadas en Compose: Kestra `v2.0.9`, PostgreSQL
  `18.6-bookworm` y Spark `3.5.8-scala2.12-java17-python3-ubuntu`.
  No hay instalación automática ni lock completo de dependencias transitivas/digests.

En un clon nuevo, desde la raíz `pset_2`, preparar los entornos separados:

```powershell
py -3.12 -m venv .venv-dbt
.\.venv-dbt\Scripts\python.exe -m pip install -r .\dbt\requirements.txt
py -3.12 -m venv .\spark\.venv
.\spark\.venv\Scripts\python.exe -m pip install -r .\spark\requirements-host.txt
```

dbt fija `dbt-core==1.11.11` y `dbt-snowflake==1.11.3`; el host Spark exige
`snowflake-connector-python==5.2.0`. PySpark y Java se usan desde la imagen,
sin instalarlos en Windows. En el equipo del estudiante, conservar los entornos
ya preparados; no modificar el del worker municipal.

### Objetos y permisos Snowflake

`preparar_base_demo.sql` **no crea el rol, el usuario, el warehouse ni las claves**.
Un administrador de la cuenta del profesor debe preparar primero:

| Objeto/requisito | Contrato del código actual |
|---|---|
| Usuario de servicio | `PSET2_PIPELINE_SVC`, con autenticación por clave pública propia y rol asignado |
| Rol | `PSET2_PIPELINE_ROLE` |
| Warehouse | `COMPUTE_WH`, con `USAGE` para el rol; X-Small es la configuración documentada |
| Base exclusiva | `PSET2_DEMO_SINTETICO`; no requiere crear `PSET2_CAYAMBE` |
| Esquemas | RAW, BRONZE, SILVER, GOLD, OBT con `USAGE, CREATE TABLE` para el rol |
| Tablas | El SQL de demo crea tres tablas RAW (incluido ledger) y una OBT vacías bajo el rol de servicio; dbt crea las tablas intermedias |
| Acceso efectivo | Kestra: lectura/inserción RAW; dbt: lectura RAW y creación/reemplazo de sus tablas; puente: lectura Gold/ledger y `SELECT, INSERT, DELETE` en OBT |

Los nombres de usuario, rol, warehouse y base son **exactos**, no meramente
equivalentes: `dbt/macros/lote_y_destino.sql` y `spark/publish_obt.py` los validan.
Cambiar solo las variables por otros nombres será rechazado. Para otra cuenta,
crear esos nombres dentro de ella; usar nombres distintos requeriría cambios
funcionales fuera del alcance de esta entrega.

Como referencia administrativa, `../docs/snowflake_setup.sql` documenta creación
de rol, warehouse, usuario y registro separado de clave pública para el entorno
original. **No ejecutar ese archivo completo para la demo**: también crea y
concede acceso a `PSET2_CAYAMBE`. El administrador debe preparar únicamente los
objetos compartidos indicados arriba en su propia cuenta, asignar el rol al
usuario de servicio y conceder `USAGE` sobre `COMPUTE_WH`.
Debe poder asumir `PSET2_PIPELINE_ROLE` para completar el SQL de demo.

Registrar una clave pública propia en el usuario de servicio mediante el
mecanismo de autenticación admitido en su cuenta, conservando la clave privada
cifrada y su passphrase fuera del repositorio. No se proporciona una clave
utilizable ni se ha verificado esa configuración en la cuenta del docente.

Después, ejecutar `demo/preparar_base_demo.sql` en Snowflake: comienza con
`USE ROLE ACCOUNTADMIN` y luego cambia a `PSET2_PIPELINE_ROLE`. La sesión de
preparación necesita acceso a ambos roles; no basta con iniciar con cualquier
rol equivalente sin adaptar esa instrucción en una copia local. Los procesos
de Kestra/dbt/Spark deben ejecutarse con el rol de servicio, nunca como administrador.
El SQL usa `IF NOT EXISTS`: no corrige objetos existentes con contrato incorrecto.
Si las tablas pertenecen a otro rol, revisar propiedad y permisos efectivos.

### Kestra, secretos y configuración local

En un clon nuevo, copiar manualmente `.env.example` a `.env` y completar las
contraseñas locales de PostgreSQL y Kestra y el correo de acceso. No reutilizar
credenciales municipales. Compose también exige `.env.kestra.secrets`, aunque
no existe una plantilla con valores: debe prepararse de forma privada.

El Flow referencia `secret('SNOWFLAKE_PRIVATE_KEY')` y
`secret('SNOWFLAKE_PRIVATE_KEY_PASSWORD')`. En el despliegue local por variables
de entorno, preparar las entradas `SECRET_SNOWFLAKE_PRIVATE_KEY` y
`SECRET_SNOWFLAKE_PRIVATE_KEY_PASSWORD` en `.env.kestra.secrets` con la
codificación Base64 que espera Kestra, preservando los saltos de línea de la
clave privada PEM cifrada dentro del valor decodificado. Cada valor Base64 debe
ocupar una sola línea del archivo de entorno, según la
[guía oficial de secretos de Kestra](https://kestra.io/docs/how-to-guides/secrets).
Base64 no cifra ni protege el secreto. La mera ruta
de la clave usada por dbt no satisface `privateKey` del Flow. Verificar la
resolución de secretos en la instalación propia; no registrar valores ni
comandos que los expongan en el historial. La auditoría no leyó esos archivos.

En una copia local del Flow para importar al Kestra del profesor, adaptar las
**cuatro** URL `jdbc:snowflake://...` a su endpoint Snowflake. El YAML versionado
contiene la cuenta del estudiante codificada en esas cuatro tareas; no consume
`PSET2_DEMO_ACCOUNT`. Conservar en todas `username: PSET2_PIPELINE_SVC`,
`role: PSET2_PIPELINE_ROLE`, `warehouse: COMPUTE_WH` y
`database: PSET2_DEMO_SINTETICO`. Conservar también las referencias SQL completas
a esa base y el UUID sintético. No importar ni ejecutar los Flows municipales.

Para un entorno nuevo, levantar solo el Compose base, sin el override municipal:

```powershell
docker compose --env-file .env -f docker-compose.yml up -d
docker compose --env-file .env -f docker-compose.yml ps
```

En `http://127.0.0.1:8080/` (o el puerto configurado), iniciar sesión con las
credenciales locales e importar la copia adaptada como Flow
`usfq.pset2.demo_sintetico_raw`. Ejecutarlo desde la interfaz y revisar sus cinco
tareas y `outputs.comprobar_lote_sintetico.row`: se espera `ESTADO=OK`,
10 obligaciones, 6 movimientos, 1 lote y 0 huérfanos. La quinta tarea exige esos
conteos. Iniciar Compose no ejecuta el Flow ni el trabajo Spark.
La disponibilidad del plugin `io.kestra.plugin.jdbc.snowflake.Query` y la
conexión/clave deben comprobarse en ese Kestra; no se construyen imágenes aquí.

Spark exige `.runtime` privada, sin herencia de ACL y con acceso solo del usuario
Windows actual y SYSTEM. Para un clon nuevo, el helper existente prepara esos
directorios sin conectarse a SQL Server ni iniciar el worker:

```powershell
powershell.exe -NoProfile -File .\ingesta\Prepare-Bridge.ps1
```

No ejecutarlo para alterar un entorno municipal activo. No compartir `.runtime`
ni ampliar sus ACL para evitar un error. El override `docker-compose.ingesta.yml`
y sus montajes del puente municipal no son necesarios para la demo.

## Secuencia manual de ejecución

1. Completar la preparación de Snowflake y ejecutar el SQL de demo como se describe arriba. No consulta las tablas municipales.
2. Importar y ejecutar el Flow adaptado en Kestra, comprobar SUCCESS y los conteos indicados. Repetir el mismo Flow es una comprobación opcional de idempotencia, no una condición para continuar.
3. En **PowerShell nueva sesión**, desde la raíz del proyecto, indicar la cuenta propia y configurar la sesión privada. En la ejecución validada ambas variables de cuenta correspondían a la cuenta del estudiante; aquí se solicitan para evitar reutilizarla por accidente:

```powershell
$env:PSET2_DEMO_ACCOUNT = Read-Host 'Identificador de tu cuenta Snowflake (organizacion-cuenta)'
$env:DBT_SNOWFLAKE_ACCOUNT = $env:PSET2_DEMO_ACCOUNT
$env:PSET2_SYNTHETIC_DEMO = 'I_ACKNOWLEDGE_SYNTHETIC'
$env:DBT_SNOWFLAKE_USER = 'PSET2_PIPELINE_SVC'
$env:DBT_SNOWFLAKE_ROLE = 'PSET2_PIPELINE_ROLE'
$env:DBT_SNOWFLAKE_DATABASE = 'PSET2_DEMO_SINTETICO'
$env:DBT_SNOWFLAKE_WAREHOUSE = 'COMPUTE_WH'
# El helper solicita ruta absoluta de la clave propia fuera del proyecto y passphrase en entrada oculta.
Set-Location .\dbt
. .\Set-SessionSecrets.ps1
$lote = '11111111-2222-4333-8444-555555555555'
$vars = "{lote_id: '$lote', expected_obligaciones: 10, expected_movimientos: 6}"
& '..\.venv-dbt\Scripts\dbt.exe' debug --profiles-dir . --vars $vars
& '..\.venv-dbt\Scripts\dbt.exe' build --profiles-dir . --vars $vars
Set-Location ..
```

Continuar solo si dbt termina sin errores y conserva visible el WARN
`observaciones_calidad`. El test está configurado con severidad `warn` y el
dataset incluye anomalías intencionales, como una fecha de emisión nula.
`debug` comprueba la conexión; no sustituye el `build` ni sus pruebas.

4. En **la misma PowerShell**, desde la raíz, con Gold completo, tabla OBT preparada y contenedor Spark encendido:

```powershell
powershell.exe -NoProfile -File .\spark\Run-OBT.ps1 -LoteId '11111111-2222-4333-8444-555555555555' -EsperadasObligaciones 10 -EsperadosMovimientos 6 -Python "$PWD\spark\.venv\Scripts\python.exe"
```

El parámetro `-Python` selecciona el entorno host creado arriba. El lanzador usa
`.venv\Scripts\python.exe` si se omite, apropiado solo si ese entorno ya cumple
los requisitos. `-NoProfile` hereda las variables de entorno del proceso padre;
una ventana nueva requiere configurar otra vez la sesión. Esperar un resumen
con `status=success`, `filas_obt=10`, `movimientos=6`, `ids_nulos=0`,
`duplicados=0`, `diferencias_importes=0` y `diferencias_agregados=0`.

5. Verificar en Snowflake con la cuenta propia y rol de servicio:

```sql
SELECT COUNT(*) FILAS, COUNT(DISTINCT OBLIGACION_ID) IDS_UNICOS,
       COALESCE(SUM(N_MOVIMIENTOS),0) MOVIMIENTOS,
       COALESCE(COUNT_IF(OBLIGACION_ID IS NULL),0) IDS_NULOS,
       COUNT(*) - COUNT(DISTINCT OBLIGACION_ID)
         - COALESCE(COUNT_IF(OBLIGACION_ID IS NULL),0) DUPLICADOS
FROM PSET2_DEMO_SINTETICO.OBT.OBT_URBANO_OBLIGACIONES
WHERE LOTE_ID='11111111-2222-4333-8444-555555555555';
```

Se espera `FILAS=10`, `IDS_UNICOS=10`, `MOVIMIENTOS=6`, `IDS_NULOS=0`,
`DUPLICADOS=0`. Esta consulta comprueba conteos; las diferencias monetarias y de
agregados las controla el puente antes del commit. Para revisión SQL independiente,
adaptar en una copia local de `../docs/validar_obt.sql` **todas** las referencias
`PSET2_CAYAMBE` a `PSET2_DEMO_SINTETICO` y el UUID al lote sintético antes de
ejecutarla: el archivo original apunta a la base municipal. No ejecutarlo sin
adaptación ni presentar el simple conteo como una reconciliación completa.

**Resultados reales verificados:** Kestra SUCCESS (5 tareas), RAW con 10
obligaciones, 6 movimientos y lote confirmado; dbt con 10 modelos y 113 pruebas
(123 PASS, 1 WARN en `observaciones_calidad`, 0 ERROR, 0 SKIP); PySpark SUCCESS
con 10 filas OBT, 6 movimientos, 0 identificadores nulos, 0 duplicados y 0
diferencias de importes y agregados. La repetición para comprobar idempotencia
del paso 2 es una instrucción de reproducción; no se declara verificada por
estos resultados finales.

## Alcance, seguridad y reproducibilidad

- Demo comienza en Kestra, que genera SQL de datos sintéticos; no extrae SQL Server ficticio y no se debe presentar como origen SQL Server → Kestra.
- Este paquete añade guardarraíl: dbt y Spark exigen `PSET2_SYNTHETIC_DEMO` y base `PSET2_DEMO_SINTETICO`. En modo original siguen usando `PSET2_CAYAMBE`. La cuenta puede ser la misma; los datos se aíslan por base.
- El Flow apunta explícitamente a la base sintética. dbt y Spark solo seleccionan esa base cuando `PSET2_SYNTHETIC_DEMO=I_ACKNOWLEDGE_SYNTHETIC`; además exigen que `DBT_SNOWFLAKE_ACCOUNT` coincida con `PSET2_DEMO_ACCOUNT`. Sin ese opt-in el código selecciona el contrato municipal original, por lo que debe verificarse la sesión antes de ejecutar. No cargar `dbt/environment.example.ps1` ni `spark/config.obt.example.ps1` para esta demo: sus valores corresponden al destino original.
- El repositorio no da acceso a la cuenta del estudiante. Otra cuenta exige configurar los objetos con los nombres exactos, la clave pública/privada propia, secretos de Kestra y las cuatro URL JDBC. La lectura del código permite describir esa adaptación, pero no demuestra que haya funcionado en otra cuenta.
- Un solo publicador por host/proyecto; no existe mutex distribuido y Snowflake no impone unicidad en tablas estándar. Evitar builds/publicaciones simultáneos. Los MERGE de RAW solo insertan ausentes; no reparan filas existentes alteradas. Las tareas JDBC son separadas, sin una transacción única para todo el Flow.
- Es una muestra técnica de 10/6, sin representatividad estadística, cobertura histórica ni validación predictiva. La repetición de la demo y la instalación desde cero en otra cuenta no se acreditan por los resultados aportados. El WARN `observaciones_calidad` permanece visible.
- No distribuir `.env`, `.env.kestra.secrets`, claves, passphrases ni `.runtime`; no mostrar entornos o logs expandidos. La auditoría es de lectura y no certifica la ausencia de información sensible en todo el historial. Las referencias operativas municipales señaladas en el README principal requieren revisión institucional separada; no son necesarias para evaluar esta demo.
- Validación offline: `py -3.12 .\demo\verificar_demo_offline.py`. No prueba realmente Snowflake, Kestra, dbt ni Spark.
