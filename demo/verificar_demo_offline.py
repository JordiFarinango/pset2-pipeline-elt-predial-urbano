#!/usr/bin/env python3
"""Verificación estructural sin instalar paquetes, conectarse ni cargar datos."""
from pathlib import Path
import importlib.util
import json
import re

root = Path(__file__).resolve().parents[1]
source = Path(__file__).with_name('generar_flow_sintetico.py')
spec = importlib.util.spec_from_file_location('generar_flow_sintetico',source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def check(ok, description):
    if not ok:
        raise SystemExit('FALLO: '+description)
    print('OK:',description)

contract = json.loads((root/'ingesta'/'contract.json').read_text(encoding='utf-8'))
flow = root/'kestra'/'flows'/'demo_sintetico_raw.yml'
source_yaml = flow.read_text(encoding='utf-8')
check(source_yaml == module.render(),'Flow sincronizado con generador reproducible')
check(module.LOTE == '11111111-2222-4333-8444-555555555555','UUID único exclusivo de la demo')
check(len(contract['raw']['obligaciones'])==25 and len(contract['raw']['movimientos'])==32,
      'Contrato de 25+3 columnas de obligaciones y 32+3 de movimientos')
for name,stmt in [('obligaciones',module.sql_obligaciones()),('movimientos',module.sql_movimientos())]:
    for field in contract['raw'][name]:
        check(bool(re.search(r'\bAS '+re.escape(field['name'])+r'\b',stmt)),
              f'{name}.{field["name"]} presente')
for token in ('SECRET_SNOWFLAKE_JDBC_URL', 'SECRET_SNOWFLAKE_PRIVATE_KEY_PASSWORD', 'BEGIN PRIVATE KEY',
              '172.23.7.', '8e977e06-ce56-4b4d-9781-cdf6766fb79c'):
    check(token not in source_yaml,'No contiene '+token)
check('PSET2_CAYAMBE' not in source_yaml and 'PSET2_DEMO_SINTETICO' in source_yaml,
      'Todas las consultas del Flow estan en la base DEMO aislada')
check('LOWER(SHA2' in module.sql_obligaciones() and 'LOWER(SHA2' in module.sql_movimientos(),
      'Identificadores sintéticos deterministas hex')
check('IFF(n=10, NULL::DATE' in module.sql_obligaciones(), 'Anomalía sintética de DQ señalada')
print('VALIDACIONES_ESTATICAS_OK (no valida SQL contra Snowflake ni la ejecución de Kestra/dbt/Spark)')
