-- PSet #2: reproduccion manual del aprovisionamiento de fase 1.
-- DOCUMENTACION: este script no se ha ejecutado durante la consolidacion.
-- Ejecutar por bloques, en el orden indicado, con un administrador autorizado.
-- No ejecutar con el usuario de servicio ni ampliar sus permisos para hacerlo.
-- IF NOT EXISTS conserva los objetos existentes; no valida ni corrige su estado.
-- GRANT es repetible. No se usan OR REPLACE, cambios de claves ni revocaciones.

-- 1. SECURITYADMIN: crear el rol funcional.
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS PSET2_PIPELINE_ROLE;

-- 2. SYSADMIN: crear recursos si faltan.
-- COMPUTE_WH es compartido/existente: IF NOT EXISTS no altera su configuracion.
-- Para un warehouse nuevo, INITIALLY_SUSPENDED evita arrancarlo aqui.
USE ROLE SYSADMIN;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE IF NOT EXISTS PSET2_CAYAMBE;
CREATE SCHEMA IF NOT EXISTS PSET2_CAYAMBE.RAW;
CREATE SCHEMA IF NOT EXISTS PSET2_CAYAMBE.BRONZE;
CREATE SCHEMA IF NOT EXISTS PSET2_CAYAMBE.SILVER;
CREATE SCHEMA IF NOT EXISTS PSET2_CAYAMBE.GOLD;
CREATE SCHEMA IF NOT EXISTS PSET2_CAYAMBE.OBT;

-- 3. SECURITYADMIN: reproducir exclusivamente los permisos reportados.
USE ROLE SECURITYADMIN;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE PSET2_PIPELINE_ROLE;
GRANT USAGE ON DATABASE PSET2_CAYAMBE TO ROLE PSET2_PIPELINE_ROLE;
GRANT USAGE, CREATE TABLE ON SCHEMA PSET2_CAYAMBE.RAW TO ROLE PSET2_PIPELINE_ROLE;
GRANT USAGE, CREATE TABLE ON SCHEMA PSET2_CAYAMBE.BRONZE TO ROLE PSET2_PIPELINE_ROLE;
GRANT USAGE, CREATE TABLE ON SCHEMA PSET2_CAYAMBE.SILVER TO ROLE PSET2_PIPELINE_ROLE;
GRANT USAGE, CREATE TABLE ON SCHEMA PSET2_CAYAMBE.GOLD TO ROLE PSET2_PIPELINE_ROLE;
GRANT USAGE, CREATE TABLE ON SCHEMA PSET2_CAYAMBE.OBT TO ROLE PSET2_PIPELINE_ROLE;

-- 4. Crear el usuario sin contrasena y asignar su rol.
-- Los defaults son una propuesta reproducible para usuarios nuevos; no se ha
-- inspeccionado el valor actual de esos defaults en el usuario existente.
CREATE USER IF NOT EXISTS PSET2_PIPELINE_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = PSET2_PIPELINE_ROLE
  DEFAULT_WAREHOUSE = COMPUTE_WH;
GRANT ROLE PSET2_PIPELINE_ROLE TO USER PSET2_PIPELINE_SVC;

-- 5. REGISTRO SEPARADO DE CLAVE PUBLICA: no ejecutar como parte de este script.
-- Estado reportado: PSET2_PIPELINE_KEY esta registrada y ACTIVE.
-- En otro entorno se debe proporcionar la clave PUBLICA local autorizada.
-- Nunca copiar aqui la clave privada, su passphrase ni valores codificados de
-- secretos. No reemplazar ni volver a registrar una clave que ya funciona.
-- El administrador necesita MODIFY PROGRAMMATIC AUTHENTICATION METHODS sobre
-- el usuario (o privilegios administrativos equivalentes).
-- Plantilla deliberadamente comentada; ADD KEY PAIR no es idempotente:
-- ALTER USER PSET2_PIPELINE_SVC ADD KEY PAIR PSET2_PIPELINE_KEY
--   PUBLIC_KEY = '<CLAVE_PUBLICA_LOCAL_AUTORIZADA>';
-- La comprobacion administrativa del nombre/estado puede hacerse manualmente:
-- SHOW USER KEY PAIRS FOR USER PSET2_PIPELINE_SVC;
-- No persistir resultados con material criptografico en el repositorio.

-- Referencias oficiales:
-- https://docs.snowflake.com/en/sql-reference/sql/create-user
-- https://docs.snowflake.com/en/sql-reference/sql/create-warehouse
-- https://docs.snowflake.com/en/sql-reference/sql/alter-user-add-key-pair
-- https://docs.snowflake.com/en/sql-reference/sql/show-user-key-pairs
