-- PREPARACION MANUAL OPCIONAL, solo en la cuenta propia del profesor.
-- No ejecutado en la auditoria. No usar para reconfigurar la cuenta del estudiante.
-- No crea/consulta PSET2_CAYAMBE ni copia datos. No contiene claves o contrasenas.
-- Revisar primero la cuenta activa en la UI de Snowflake.
USE ROLE ACCOUNTADMIN;
CREATE ROLE IF NOT EXISTS PSET2_PIPELINE_ROLE;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE PSET2_PIPELINE_ROLE;
CREATE USER IF NOT EXISTS PSET2_PIPELINE_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = PSET2_PIPELINE_ROLE
  DEFAULT_WAREHOUSE = COMPUTE_WH;
GRANT ROLE PSET2_PIPELINE_ROLE TO USER PSET2_PIPELINE_SVC;
-- Permite a la jerarquia administrativa asumir el rol para preparar las tablas.
GRANT ROLE PSET2_PIPELINE_ROLE TO ROLE SYSADMIN;

-- Registrar SEPARADAMENTE la clave PUBLICA propia del usuario de servicio,
-- mediante el mecanismo admitido en esta cuenta. No incluir aqui material
-- criptografico, passphrases ni la clave del estudiante.
-- IF NOT EXISTS no corrige configuraciones/propiedades de objetos existentes.
-- Continuar manualmente con demo/preparar_base_demo.sql para base/esquemas/tablas.
