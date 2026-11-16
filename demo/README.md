# PSet #2: demostración con datos sintéticos EN LA MISMA CUENTA (base distinta)

La cuenta Snowflake existente se reutiliza, con base **PSET2_DEMO_SINTETICO**. El flujo municipal existente permanece en **PSET2_CAYAMBE**, sin cambios.

## Configuración rápida (solo equipo del estudiante)

1. En Snowflake ejecutar todo `demo/preparar_base_demo.sql` (rol `ACCOUNTADMIN` o roles con facultades equivalentes) para crear base, cinco esquemas, tres tablas RAW y tabla OBT, **vacías**. El SQL no lee las tablas originales.
2. En Kestra importar `kestra/flows/demo_sintetico_raw.yml` actualizado. Verificar que cada tarea tenga `database: PSET2_DEMO_SINTETICO`. Ejecutar el Flow, esperar `ESTADO=OK` (10 obligaciones, 6 movimientos, 1 lote, 0 huérfanos). Repetir para idempotencia.
3. En **PowerShell nueva sesión**, raíz del proyecto (reutilizar la clave privada y usuario de servicio existentes), ejecutar:

```powershell
$env:DBT_SNOWFLAKE_ACCOUNT = 'XSDIWIV-XZ59673'
$env:PSET2_DEMO_ACCOUNT = 'XSDIWIV-XZ59673'
$env:PSET2_SYNTHETIC_DEMO = 'I_ACKNOWLEDGE_SYNTHETIC'
$env:DBT_SNOWFLAKE_USER = 'PSET2_PIPELINE_SVC'
$env:DBT_SNOWFLAKE_ROLE = 'PSET2_PIPELINE_ROLE'
$env:DBT_SNOWFLAKE_DATABASE = 'PSET2_DEMO_SINTETICO'
$env:DBT_SNOWFLAKE_WAREHOUSE = 'COMPUTE_WH'
# No guardar credenciales en archivos versionados. La ruta debe ser una clave privada cifrada propia y existente:
$env:DBT_ENV_SECRET_PRIVATE_KEY_PATH = Join-Path $HOME '.snowflake\pset2_cayambe\rsa_key.p8'
Set-Location .\dbt
. .\Set-SessionSecrets.ps1
$lote = '11111111-2222-4333-8444-555555555555'
$vars = "{lote_id: '$lote', expected_obligaciones: 10, expected_movimientos: 6}"
& '..\.venv-dbt\Scripts\dbt.exe' debug --profiles-dir . --vars $vars
& '..\.venv-dbt\Scripts\dbt.exe' build --profiles-dir . --vars $vars
Set-Location ..
```

4. En **la misma PowerShell**: `powershell.exe -NoProfile -File .\spark\Run-OBT.ps1 -LoteId '11111111-2222-4333-8444-555555555555' -EsperadasObligaciones 10 -EsperadosMovimientos 6` (**ATENCIÓN**: `-NoProfile` inicia proceso nuevo que no hereda la modificación de variables? Sí hereda variables de entorno del padre; no ejecutar desde nueva ventana sin variables). Contenedor Spark encendido. Si falta tabla OBT, el setup SQL ya la creó.
5. Verificar:

```sql
SELECT COUNT(*) FILAS, COUNT(DISTINCT OBLIGACION_ID) IDS_UNICOS,
       COALESCE(SUM(N_MOVIMIENTOS),0) MOVIMIENTOS,
       COUNT_IF(OBLIGACION_ID IS NULL) IDS_NULOS
FROM PSET2_DEMO_SINTETICO.OBT.OBT_URBANO_OBLIGACIONES
WHERE LOTE_ID='11111111-2222-4333-8444-555555555555';
```

**Resultados esperados todavía NO validados con ejecución real:** Kestra `10/6/1/0`, dbt 10 modelos (una advertencia DQ prevista) y OBT `10/10/6/0`.

## Alcance, seguridad y reproducibilidad

- Demo comienza en Kestra, que genera SQL de datos sintéticos; no extrae SQL Server ficticio y no se debe presentar como origen SQL Server → Kestra.
- Este paquete añade guardarraíl: dbt y Spark exigen `PSET2_SYNTHETIC_DEMO` y base `PSET2_DEMO_SINTETICO`. En modo original siguen usando `PSET2_CAYAMBE`. La cuenta puede ser la misma; los datos se aíslan por base.
- Aunque se reutiliza la cuenta y el rol, los datos sintéticos nunca se insertan en `PSET2_CAYAMBE` con estos archivos; se recomienda revisar la configuración activa de Kestra antes de lanzar.
- El docente puede usar su propia cuenta Snowflake modificando únicamente `DBT_SNOWFLAKE_ACCOUNT`, `PSET2_DEMO_ACCOUNT` y el URL JDBC/clave del Flow, con rol/usuario/base/warehouse equivalentes. No se incluyen secretos ni accesos municipales.
- Validación offline: `py -3.12 .\demo\verificar_demo_offline.py`. No prueba realmente Snowflake, Kestra, dbt ni Spark.
