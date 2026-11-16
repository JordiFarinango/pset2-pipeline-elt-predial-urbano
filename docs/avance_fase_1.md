# Avance de fase 1 — infraestructura y conexion Snowflake

Consolidado el 14 de noviembre de 2026. Fuente de la evidencia: resultados de
ejecuciones reales comunicados por el responsable del proyecto en esta tarea.
No se repitieron conexiones ni ejecuciones durante esta consolidacion. No se
aportaron identificadores de ejecucion, capturas ni logs; no se inventan anexos
o fechas de ejecucion. Este documento es una transcripcion del resultado
reportado, no una nueva certificacion independiente del entorno.

## Funcionamiento efectivamente probado, segun la evidencia aportada

| Componente | Resultado reportado |
|---|---|
| Docker Compose | Inicio local correcto |
| PostgreSQL | Healthy |
| Kestra 2.0.9 | Operativo; Flow `hola_pset2` completado correctamente |
| Snowflake | Base `PSET2_CAYAMBE`; esquemas RAW, BRONZE, SILVER, GOLD y OBT existentes |
| Warehouse | `COMPUTE_WH`, X-Small, `auto_suspend=300`, `auto_resume=true` |
| Rol | `PSET2_PIPELINE_ROLE`: USAGE en base, warehouse y cinco esquemas; CREATE TABLE en los cinco esquemas |
| Usuario | `PSET2_PIPELINE_SVC`, TYPE=SERVICE, con el rol indicado |
| Clave publica nombrada | `PSET2_PIPELINE_KEY`, registrada y ACTIVE; sin material de clave en este documento |
| Python -> Snowflake | Conexion correcta con usuario de servicio y clave privada cifrada |
| Kestra -> Snowflake | Flow `usfq.pset2.verificar_snowflake` completado; aproximadamente 5,97 segundos |

La consulta de sesion devolvio:

| Funcion consultada | Alias del Flow | Resultado real reportado |
|---|---|---|
| CURRENT_USER() | USUARIO | PSET2_PIPELINE_SVC |
| CURRENT_ROLE() | ROL | PSET2_PIPELINE_ROLE |
| CURRENT_DATABASE() | BASE_DATOS | PSET2_CAYAMBE |
| CURRENT_WAREHOUSE() | WAREHOUSE | COMPUTE_WH |

Esta consulta comprueba autenticacion y contexto de sesion; no prueba carga de
datos ni materializacion de tablas. Los 5,97 segundos corresponden a una
ejecucion reportada, no a un benchmark ni a una garantia de rendimiento.

## Configuracion preparada y conservada

- `docker-compose.yml` y `kestra/application.yaml` se conservaron sin cambios.
  Compose ya referencia el archivo privado `.env.kestra.secrets`.
- `kestra/flows/verificar_snowflake.yml` guarda exactamente el Flow proporcionado
  como exitoso. Guardarlo en Git no lo importa ni sincroniza con Kestra.
- `docs/snowflake_setup.sql` documenta el aprovisionamiento manual, por roles y
  en orden. No se ejecuto; no certifica una reproduccion completa en otra cuenta.
- El registro de la clave publica queda separado y comentado; necesita material
  publico local autorizado y no debe repetirse sobre la clave activa existente.
- `.gitignore` excluye `.env`, `.env.kestra.secrets`, `.venv/` y material de claves.
  Se revisaron sus reglas por lectura; no se leyeron secretos ni se comprobo el
  indice Git. Ignorar archivos no elimina versiones previamente registradas.

## Preparado pero todavia no probado

- Spark tiene el contenedor iniciado, pero no ha ejecutado ningun trabajo.
  `local[2]` y el entorno Java/Python siguen siendo configuracion preparada.
- No hay ingesta municipal ni carga Raw implementada o validada en esta fase.
- No hay modelos dbt Bronze/Silver/Gold, modelo estrella ni OBT construidos.
- No se ha probado el conector Spark-Snowflake ni la orquestacion completa.
- No estan fijados digests de imagenes ni demostrada la recuperacion de volumenes
  o la reproduccion del entorno desde cero.

## Seguridad y limitaciones

`.env` y `.env.kestra.secrets` son privados y nunca deben distribuirse, adjuntarse
o incluirse en Git. Tampoco las claves privadas, passphrases ni versiones
codificadas de secretos. No se inspeccionaron sus contenidos en esta tarea.
El Flow usa los nombres logicos `SNOWFLAKE_PRIVATE_KEY` y
`SNOWFLAKE_PRIVATE_KEY_PASSWORD` mediante `secret()`, sin incorporar sus valores.

Los permisos documentados son los reportados; no se auditaron otros grants ni
se ampliaron permisos. USAGE y CREATE TABLE no prueban por si solos todos los
permisos futuros de carga, acceso a tablas existentes, stages o transformacion.

Continuan las limitaciones de los datos tributarios previamente identificadas:
no existe una fecha efectiva de emision universalmente validada, no se ha
demostrado reconstruccion universal del pago completo a 90 dias y no deben
generarse etiquetas predictivas aun. El reloj adelantado del SQL Server de
pruebas no debe utilizarse automaticamente como corte real.

## Siguientes etapas

1. Autorizar formalmente la extraccion minimizada, el destino, la retencion y
   los accesos; confirmar el contrato de 27/35 columnas y la precision de fechas.
2. Aprobar el entorno local de seudonimizacion y la custodia/version de HMAC,
   preservando las claves compuestas completas antes de cualquier transferencia.
3. Diseñar captura, lotes, idempotencia, reconciliacion y controles de calidad;
   decidir y verificar solo los permisos adicionales necesarios para cargar Raw.
4. Implementar y validar ingesta con Kestra, sin mostrar identificadores reales.
5. Preparar dbt, capas Bronze/Silver/Gold y modelo dimensional; despues validar
   Spark-Snowflake y construir la OBT. Mantener el control de informacion futura.

La fase 1 queda documentada. La ingesta municipal sigue pendiente de autorizacion
y de implementacion; la conexion verificada no la autoriza por si misma.
