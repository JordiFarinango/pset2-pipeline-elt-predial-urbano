# Plantilla de configuracion NO secreta. No contiene credenciales.
# Establecer la ruta real solo en la sesion local; no editarla en Git.
$env:SNOWFLAKE_ACCOUNT = 'xsdiwiv-xz59673'
# $env:SNOWFLAKE_PRIVATE_KEY_FILE = 'C:\ruta-privada-fuera-del-proyecto\clave-cifrada.p8'
$env:PSET2_MAX_OBLIGACIONES = '10000'
$env:PSET2_MAX_MOVIMIENTOS = '100000'
# SQL Server queda fijado al servidor de pruebas. Las tres credenciales se
# solicitan de forma segura al arrancar el worker; no se cargan archivos .env.
