# Solo valores publicos de configuracion. No lee archivos .env ni claves.
$env:DBT_SNOWFLAKE_ACCOUNT = 'XSDIWIV-XZ59673'
$env:DBT_SNOWFLAKE_USER = 'PSET2_PIPELINE_SVC'
$env:DBT_SNOWFLAKE_ROLE = 'PSET2_PIPELINE_ROLE'
$env:DBT_SNOWFLAKE_DATABASE = 'PSET2_CAYAMBE'
$env:DBT_SNOWFLAKE_WAREHOUSE = 'COMPUTE_WH'
# Establecer la ruta privada REAL solo en la sesion, no en este archivo:
# $env:DBT_ENV_SECRET_PRIVATE_KEY_PATH = 'C:\RUTA_PRIVADA\clave-cifrada.p8'
# La passphrase se solicita con Set-SessionSecrets.ps1; no ponerla en argumentos.
