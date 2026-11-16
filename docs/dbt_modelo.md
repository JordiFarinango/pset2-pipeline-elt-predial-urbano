# dbt Bronze -> Silver -> Gold: modelo y validacion

Implementado en archivos el 15 de noviembre de 2026. No se instalaron paquetes,
ejecutaron modelos/pruebas ni consulto Snowflake en esta tarea. No se afirma
funcionamiento dbt hasta una validacion real.

## Evidencia de entrada y limites de la evidencia

El responsable reporto ejecuciones reales de ingesta 2024 con 10 obligaciones,
6 movimientos, cero ids nulos, duplicados u huerfanos. Un segundo disparo del
mismo UUID devolvio reutilizado=true y una consulta independiente confirmo
10/6 filas y un registro en INGESTA_LOTES. Esa evidencia valida Raw, no los
modelos dbt nuevos. El UUID no fue proporcionado en la solicitud: debe
introducirse el real, nunca elegir MAX(fecha), el ultimo lote o inventar uno.
No se leyeron archivos privados para descubrirlo.

Fuentes de verdad leidas: ingesta/contract.json (raw-v1, 27/35 columnas fuente)
y docs/raw_setup.sql (28/35 campos destino con trazabilidad). No se modifica
SQL Server, Raw, Docker, Flows de Kestra o claves/permisos.

## Instalacion manual y entorno

Elegido: Python 3.12, dbt-core 1.11.11 y dbt-snowflake 1.11.3, fijados en
dbt/requirements.txt. Las publicaciones de ambas dependencias declaran Python
3.12; no se presupone compatibilidad con Python 3.14. El lanzador py consultado
en esta sesion no enumero interpretes; esto no demuestra que el Python del
equipo del usuario no exista. No se ejecuto el Python de la ingesta ni se
inspecciono su entorno virtual.

Crear un entorno SEPARADO dentro del pset_2 existente. No instalar dbt en la
.venv del worker que ya funciona. Los siguientes comandos son para ejecucion
manual autorizada, desde pset_2:

~~~powershell
$python312 = Read-Host 'Ruta al python.exe autorizado de Python 3.12'
& $python312 --version
# Continuar solo si corresponde a Python 3.12.
& $python312 -m venv .venv-dbt
.\.venv-dbt\Scripts\python.exe -m pip install -r .\dbt\requirements.txt
Set-Location .\dbt
$dbt = '..\.venv-dbt\Scripts\dbt.exe'
. .\environment.example.ps1
. .\Set-SessionSecrets.ps1
~~~

Si no hay Python 3.12, preparar su instalacion manualmente antes de continuar;
no se descarga ni instala automaticamente. El requisito directo esta fijado;
la resolucion transitiva y compatibilidad efectiva requieren validacion local.
No hay packages.yml ni paquetes dbt externos: no se necesita dbt deps.

## Credenciales y permisos

profiles.yml es una plantilla versionable SIN secretos. Utiliza variables:

| Variable | Uso |
|---|---|
| DBT_SNOWFLAKE_ACCOUNT | XSDIWIV-XZ59673 |
| DBT_SNOWFLAKE_USER | PSET2_PIPELINE_SVC |
| DBT_SNOWFLAKE_ROLE | PSET2_PIPELINE_ROLE |
| DBT_SNOWFLAKE_DATABASE | PSET2_CAYAMBE |
| DBT_SNOWFLAKE_WAREHOUSE | COMPUTE_WH |
| DBT_ENV_SECRET_PRIVATE_KEY_PATH | Ruta privada absoluta de la clave cifrada existente, fuera de pset_2 |
| DBT_ENV_SECRET_PRIVATE_KEY_PASSPHRASE | Passphrase privada |

El helper solicita las dos ultimas mediante entrada oculta, solo para la
sesion; no lee la clave ni .env/.env.kestra.secrets. Las variables con prefijo
DBT_ENV_SECRET se usan solo en profiles.yml para el tratamiento/redaccion de
secretos de dbt. No copiar valores al proyecto ni a los logs. Los administradores
del host pueden inspeccionar entornos: se requiere un equipo confiable.

No usar ACCOUNTADMIN. Las macros rechazan otro usuario, rol, cuenta, base o
warehouse. generate_schema_name devuelve SOLO BRONZE, SILVER o GOLD, evitando
el esquema concatenado BRONZE_SILVER y sin escribir en RAW.
Todos los modelos son TABLE, no VIEW, para usar los CREATE TABLE ya reportados.
Se requieren USAGE de base/warehouse/esquemas, SELECT sobre las tres fuentes y
propiedad/capacidad de reemplazo de los modelos creados por el servicio.
No se verificaron ni modificaron grants. Si faltan, detener y avisar: no
conceder permisos o cambiar de rol para sortear el error.

## Seleccion del lote y comandos

Desde dbt/, en la MISMA sesion donde se establecieron variables:

~~~powershell
$lote = Read-Host 'UUID real del lote confirmado de 10 obligaciones y 6 movimientos'
$vars = "{lote_id: '$lote', expected_obligaciones: 10, expected_movimientos: 6}"
& $dbt debug --profiles-dir . --vars $vars
& $dbt build --profiles-dir . --vars $vars
& $dbt test --profiles-dir . --vars $vars
& $dbt docs generate --profiles-dir . --vars $vars
~~~

No ejecutar sin autorizacion. dbt debug conecta a Snowflake; build materializa
tablas; test y docs generate consultan Snowflake. No basta dbt parse o compile
como prueba: algunas macros realizan lecturas al compilar con execute=true.
No se ejecutaron aqui esos comandos.

La macro de arranque y el modelo br_lote_confirmado exigen UUID valido en
minusculas, exactamente una fila de ledger con COMMIT_EN no nulo, contexto de
servicio y cantidades Raw concordantes. Tambien comprueban unicidad/ids y
movimientos huerfanos. expected_* es opcional para otros lotes; si se suministra
debe coincidir. No hay fallback. Un fallo de lote se produce antes de construir
los modelos mediante dbt build/run.

Para revisar capas por separado, manteniendo SIEMPRE el mismo UUID:

~~~powershell
& $dbt build --profiles-dir . --vars $vars --select tag:bronze --indirect-selection cautious
& $dbt build --profiles-dir . --vars $vars --select tag:silver --indirect-selection cautious
& $dbt build --profiles-dir . --vars $vars --select tag:gold --indirect-selection cautious
& $dbt test --profiles-dir . --vars $vars
~~~

cautious evita seleccionar pruebas multicapa antes de construir sus padres.
El build completo es la ruta recomendada y el test final completo es obligatorio
para validar la ruta por etapas. No sustituir pruebas por comparar solo 10/6.
Un UUID distinto debe tomarse de otro lote confirmado y usar sus cantidades.
No ejecutar comandos simultaneos para lotes distintos.

Las tablas de salida conservan solo UN lote seleccionado por ejecucion completa,
sin append ni incremental. Repetir build reemplaza esos modelos; Raw historico
permanece intacto. Los modelos no deduplican, imputan o eliminan anomalias: las
violaciones de clave/cantidad causan errores.

## Modelos implementados

| Capa/esquema | Modelo | Grano |
|---|---|---|
| BRONZE | br_lote_confirmado | Un registro confirmado del UUID seleccionado |
| BRONZE | br_obligaciones | Una obligacion de ese lote, proyeccion explicita Raw |
| BRONZE | br_movimientos | Un movimiento de ese lote, proyeccion explicita Raw |
| SILVER | sl_obligaciones | Una obligacion, valores originales y flags de calidad |
| SILVER | sl_movimientos | Un movimiento, valores originales y flags |
| SILVER | sl_resumen_movimientos_por_obligacion | Una fila por obligacion, incluso sin movimientos |
| GOLD | dim_fecha | Una fecha observada y un miembro 0 para NULL |
| GOLD | dim_contexto_tributario | Una combinacion distinta de origen y codigos, diferenciando NULL |
| GOLD | fct_obligaciones | Una fila por obligacion protegida del lote |
| GOLD | fct_movimientos | Una fila por movimiento protegido del lote |

Los SELECT contienen columnas explicitas. models/sources.yml documenta los
campos Raw; models/schema.yml documenta origen, significado conservador y pruebas
de los campos proyectados. No se exponen identificadores municipales originales.

Bronze normaliza nombres: IM_/IMP_ de componentes pasan a importe_*; IM_TOTAL a
total_obligacion_declarado e IMP_TOTAL a total_movimiento_declarado. Las fechas
llevan sufijo _declarada. No se deduce una semantica tributaria por el nombre:
BASURA no se renombra como tasa de basura y ADO_GLOB_2011 sigue sin catalogo
completo. No se agregan nombres, contactos, propietarios o claves catastrales.

Silver conserva NUMBER(16,2), NULL y signos. Las observaciones de fechas,
importes y combinaciones de estado/anulacion se agregan como flags, sin filtrar.
Fecha NULL sigue NULL; solo la FK dimensional usa el miembro desconocido 0.
La fecha futura se contrasta con el dia UTC de CAPTURADO_EN, no GETDATE del
SQL Server ni el reloj actual cambiante de la ejecucion dbt.

## Estrella y claves

Se implementa una constelacion de dos estrellas con dimensiones compartidas:

~~~mermaid
erDiagram
    dim_fecha ||--o{ fct_obligaciones : "5 roles de fecha declarada"
    dim_fecha ||--o{ fct_movimientos : "6 roles de fecha declarada"
    dim_contexto_tributario ||--o{ fct_obligaciones : contexto_key
    dim_contexto_tributario ||--o{ fct_movimientos : contexto_key
    fct_obligaciones ||--o{ fct_movimientos : "obligacion_id dentro del lote"
    dim_fecha {
        number fecha_key PK
        date fecha
        boolean es_fecha_desconocida
        string lote_id
    }
    dim_contexto_tributario {
        string contexto_key PK
        string origen
        string estado_codigo
        string condicion_codigo
        string tipo_documento_codigo
        string tipo_movimiento_codigo
        string lote_id
    }
    fct_obligaciones {
        string obligacion_id PK
        string contexto_key FK
        number fecha_emision_key FK
        number fecha_pago_actual_key FK
        decimal total_obligacion_declarado
        number n_movimientos
        decimal suma_total_movimientos_declarados
        string lote_id
    }
    fct_movimientos {
        string movimiento_id PK
        string obligacion_id FK
        string contexto_key FK
        number fecha_pago_key FK
        decimal total_movimiento_declarado
        decimal saldo_declarado
        string lote_id
    }
~~~

Las PK/FK del diagrama son LOGICAS y verificadas mediante tests, no restricciones
fisicas que Snowflake imponga. El grano presupone un solo lote; entre capturas
la identidad debe combinarse con lote_id. La cardinalidad es una dimension a
cero/muchos hechos y una obligacion a cero/muchos movimientos.

dim_fecha usa clave YYYYMMDD, conserva dias anomales y no inventa un calendario
continuo ni fechas efectivas. Rol obligacion: emision, creacion, modificacion,
pago actual y anulacion. Rol movimiento: pago, emision, creacion, modificacion,
anulacion y proceso. Todas son fechas declaradas.

dim_contexto_tributario es una dimension tecnica de codigos literales, NO un
catalogo de significados validados. SHA-256 de un array ordenado incluye origen,
valores y booleanos de nulidad para evitar colisiones NULL/cadena vacia. Se
aplica a categorias, no a identificadores personales. Las etiquetas de negocio
no verificadas no se inventan; F/AB/FA no constituyen un target ni pago neto.

## Medidas y reglas de agregacion

- Total de obligacion: valor declarado actual en la captura. Se puede sumar
  una vez por obligacion de un mismo lote para describir esa poblacion; no
  llamarlo total originalmente emitido o saldo actual.
- Componentes del movimiento y total declarado: preservados sin corregir.
  Las sumas de todos los estados son descriptivas, no pagos netos conciliados.
- El resumen agrega primero el lado muchos por obligacion_id/lote_id. Tiene
  cantidades, documentos AB/FA, codigos F/A, sumas NUMBER(38,2) de total,
  principal, recargo, descuento, interes y costas, y extremos de fecha declarada.
- Cero movimientos produce conteos 0 y sumas/fechas NULL. Todos los totales
  nulos tambien producen suma NULL, distinguible mediante n_movimientos y
  n_totales_informados. Las sumas ignoran NULL explicitamente, no los convierten
  en valores monetarios cero. No se suma saldo_declarado entre movimientos.
- fct_obligaciones incorpora el resumen ya agregado mediante relacion uno a uno.
  No sumar medidas de obligaciones despues de unir el detalle de movimientos:
  se multiplicarian por el numero de filas. Para la futura OBT, Spark debera
  usar el hecho de obligaciones o agregar movimientos antes del JOIN.
- No sumar capturas sucesivas como nuevas obligaciones/pagos ni descartar
  anulaciones, reversos o documentos cuyo significado sigue incompleto.

## Pruebas preparadas

Errores criticos: not_null y unique para claves; relationships para lotes,
obligaciones, contextos y los once roles de fecha; formato de ids protegidos;
ledger/UUID; conciliacion de cantidades en cada capa; conservacion exacta de
TODOS los campos base entre Raw/Bronze/Silver/Gold mediante EQUAL_NULL;
reconciliacion por obligacion del resumen y hecho; claves dimensionales y
miembro 0; tipos y precision/escala monetaria en INFORMATION_SCHEMA.

Advertencias: fechas nulas/de proceso, fechas previas a 1901 o futuras respecto
a captura, cronologia inconsistente, totales/principal negativos, A sin fecha
de anulacion o F con ella, y codigos fuera de los valores observados en auditoria.
No se asume que los negativos sean ilegales o que AB/FA certifiquen pago.
Los codigos nuevos son advertencias y se conservan, no accepted_values criticos.

Las pruebas SQL personalizadas solo devuelven controles y contadores agregados.
store_failures=false evita guardar filas fallidas. No usar --store-failures,
dbt show sobre hechos ni logs DEBUG; revisar antes de compartir cualquier
artefacto. Las pruebas no fueron ejecutadas; no se inventan PASS, WARN o duraciones.

## Linaje implementado

~~~mermaid
flowchart LR
    R1["RAW.RAW_URBANO_OBLIGACIONES"] --> B1[br_obligaciones]
    R2["RAW.RAW_URBANO_MOVIMIENTOS_PAGO"] --> B2[br_movimientos]
    R3["RAW.INGESTA_LOTES"] --> BL[br_lote_confirmado]
    R1 --> BL
    R2 --> BL
    BL --> B1
    BL --> B2
    B1 --> S1[sl_obligaciones]
    B2 --> S2[sl_movimientos]
    S1 --> SR[sl_resumen_movimientos_por_obligacion]
    S2 --> SR
    S1 --> F1[fct_obligaciones]
    SR --> F1
    S2 --> F2[fct_movimientos]
    S1 --> D1[dim_fecha]
    S2 --> D1
    BL --> D1
    S1 --> D2[dim_contexto_tributario]
    S2 --> D2
~~~

## Evidencia academica y limites pendientes

Tras ejecucion real autorizada, conservar privadamente el UUID, versiones,
salida de dbt debug, resumen PASS/WARN/ERROR, resultados agregados 10/6 y
artefactos target/run_results.json, manifest.json, catalog.json e index.html.
Generar docs despues del build/test completo del MISMO lote. target/ y logs/
estan ignorados: revisar/redactar antes de adjuntar evidencias; no distribuir
credenciales, claves, perfiles privados ni filas de contribuyentes.

Materializar todos los modelos no es una transaccion global: un fallo deja
tablas parciales hasta un build completo exitoso del mismo lote. No consumir
Gold si fallan pruebas criticas ni ejecutar dos builds concurrentes. Las
advertencias requieren interpretacion y documentacion, no ocultarlas con filtros.

Persisten falta de emision efectiva universal, conciliacion historica completa,
cobertura limitada del lote 10/6 y perdida del orden intradiario por DATE.
No se construye target de impago a 90 dias. Los campos de estado/pago/cancelacion
son informacion actual/posterior y no se acreditan como predictores disponibles
al origen. Gold esta preparado para analisis, no para entrenar sin control temporal.
Spark y OBT no se implementaron.

Al cerrar la sesion local:

~~~powershell
Remove-Item Env:DBT_ENV_SECRET_PRIVATE_KEY_PATH,Env:DBT_ENV_SECRET_PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
~~~

## Fuentes oficiales de configuracion

- [dbt Core 1.11.11, Python declarado](https://pypi.org/project/dbt-core/1.11.11/).
- [dbt Snowflake 1.11.3, Python declarado](https://pypi.org/project/dbt-snowflake/1.11.3/).
- [Variables privadas de entorno dbt](https://docs.getdbt.com/reference/dbt-jinja-functions/env_var).
- [Generacion de esquemas](https://docs.getdbt.com/docs/build/custom-schemas).
