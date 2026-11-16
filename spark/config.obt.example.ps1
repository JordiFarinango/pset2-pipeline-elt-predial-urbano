# Configuracion publica opcional. Secretos: variables privadas de sesion existentes.
$env:DBT_SNOWFLAKE_ACCOUNT = 'XSDIWIV-XZ59673'
$env:DBT_SNOWFLAKE_USER = 'PSET2_PIPELINE_SVC'
$env:DBT_SNOWFLAKE_ROLE = 'PSET2_PIPELINE_ROLE'
$env:DBT_SNOWFLAKE_DATABASE = 'PSET2_CAYAMBE'
$env:DBT_SNOWFLAKE_WAREHOUSE = 'COMPUTE_WH'
$env:PSET2_DOCKER_PIPE = 'npipe:////./pipe/dockerDesktopLinuxEngine'
# Si tu Docker Desktop usa la tuberia local anterior:
# $env:PSET2_DOCKER_PIPE = 'npipe:////./pipe/docker_engine'
# Reutilizar DBT_ENV_SECRET_PRIVATE_KEY_PATH y DBT_ENV_SECRET_PRIVATE_KEY_PASSPHRASE.
# No guardar sus valores en este archivo ni pasarlos en argumentos.
