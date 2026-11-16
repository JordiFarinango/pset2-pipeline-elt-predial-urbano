{% macro lote_id_sql() %}
  {% set value = var('lote_id', '') %}
  {% if value is not string or not modules.re.fullmatch('[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', value) %}
    {{ exceptions.raise_compiler_error("Debe proporcionar lote_id: UUID real en minusculas, sin seleccion automatica.") }}
  {% endif %}
  {{ return("'" ~ value ~ "'") }}
{% endmacro %}

{% macro validar_destino() %}
  {# El modo DEMO solo se habilita mediante opt-in explicito. #}
  {% set demo = env_var('PSET2_SYNTHETIC_DEMO', '') == 'I_ACKNOWLEDGE_SYNTHETIC' %}
  {% set db_esperada = 'PSET2_DEMO_SINTETICO' if demo else 'PSET2_CAYAMBE' %}
  {% if demo %}
    {% set esperado = env_var('PSET2_DEMO_ACCOUNT', '') | upper %}
    {% if esperado == '' %}
      {{ exceptions.raise_compiler_error("Demo exige declarar explicitamente la cuenta Snowflake.") }}
    {% endif %}
  {% else %}
    {% set esperado = 'XSDIWIV-XZ59673' %}
  {% endif %}
  {% if target.type != 'snowflake' or target.account | upper != esperado
        or target.user | upper != 'PSET2_PIPELINE_SVC'
        or target.role | upper != 'PSET2_PIPELINE_ROLE'
        or target.database | upper != db_esperada
        or target.warehouse | upper != 'COMPUTE_WH' %}
    {{ exceptions.raise_compiler_error("Perfil fuera del usuario/rol/destino autorizado; no se ejecutara como administrador.") }}
  {% endif %}
{% endmacro %}

{% macro generate_schema_name(custom_schema_name, node) -%}
  {%- do validar_destino() -%}
  {%- set name = (custom_schema_name if custom_schema_name is not none else target.schema) | trim | upper -%}
  {%- if name not in ['BRONZE', 'SILVER', 'GOLD'] -%}
    {{ exceptions.raise_compiler_error("Esquema dbt no autorizado: solo BRONZE, SILVER o GOLD.") }}
  {%- endif -%}
  {{ name }}
{%- endmacro %}

{% macro validar_lote() %}
  {% do validar_destino() %}
  {% set lote = lote_id_sql() %}
  {% if execute %}
    {% set context = run_query("select current_user(),current_role(),current_database(),current_warehouse()") %}
    {% if context.rows[0][0] != 'PSET2_PIPELINE_SVC' or context.rows[0][1] != 'PSET2_PIPELINE_ROLE'
          or context.rows[0][2] != ('PSET2_DEMO_SINTETICO' if env_var('PSET2_SYNTHETIC_DEMO', '') == 'I_ACKNOWLEDGE_SYNTHETIC' else 'PSET2_CAYAMBE') or context.rows[0][3] != 'COMPUTE_WH' %}
      {{ exceptions.raise_compiler_error("Contexto Snowflake distinto del autorizado.") }}
    {% endif %}
    {% set ledger_sql %}
      select count(*) as n, count(commit_en) as confirmados,
             min(obligaciones) as obligaciones, min(movimientos) as movimientos
      from {{ source('raw_cayambe','ingesta_lotes') }} where lote_id={{ lote }}
    {% endset %}
    {% set result = run_query(ledger_sql) %}
    {% if result.rows[0][0] != 1 or result.rows[0][1] != 1 %}
      {{ exceptions.raise_compiler_error("Lote inexistente, no confirmado o duplicado en INGESTA_LOTES.") }}
    {% endif %}
    {% set n_u = result.rows[0][2] %}
    {% set n_p = result.rows[0][3] %}
    {% if n_u is none or n_p is none or n_u < 1 or n_p < 0 %}
      {{ exceptions.raise_compiler_error("Cantidades invalidas en ledger.") }}
    {% endif %}
    {% for name, expected in [('expected_obligaciones', n_u), ('expected_movimientos', n_p)] %}
      {% set supplied = var(name, none) %}
      {% if supplied is not none and (supplied is not number or supplied != expected) %}
        {{ exceptions.raise_compiler_error("El lote no coincide con las cantidades esperadas proporcionadas.") }}
      {% endif %}
    {% endfor %}
    {% set counts_sql %}
      select
        (select count(*) from {{ source('raw_cayambe','obligaciones') }} where lote_id={{ lote }}),
        (select count(distinct obligacion_id) from {{ source('raw_cayambe','obligaciones') }} where lote_id={{ lote }}),
        (select count(*) from {{ source('raw_cayambe','movimientos') }} where lote_id={{ lote }}),
        (select count(distinct movimiento_id) from {{ source('raw_cayambe','movimientos') }} where lote_id={{ lote }}),
        (select count(*) from {{ source('raw_cayambe','movimientos') }} p
         where p.lote_id={{ lote }} and not exists (
           select 1 from {{ source('raw_cayambe','obligaciones') }} u
           where u.lote_id=p.lote_id and u.obligacion_id=p.obligacion_id))
    {% endset %}
    {% set actual = run_query(counts_sql) %}
    {% if actual.rows[0][0] != n_u or actual.rows[0][1] != n_u
          or actual.rows[0][2] != n_p or actual.rows[0][3] != n_p or actual.rows[0][4] != 0 %}
      {{ exceptions.raise_compiler_error("Raw no concilia con el lote: cantidades, unicidad, ids o correspondencia invalidos.") }}
    {% endif %}
  {% endif %}
  {{ return("select 1 as lote_verificado") }}
{% endmacro %}

{% macro fecha_key(expression) -%}
  coalesce(to_number(to_char({{ expression }}, 'YYYYMMDD')), 0)::number(8,0)
{%- endmacro %}

{% macro contexto_key(origen, estado, condicion, documento, tipo="null") -%}
  sha2(to_json(array_construct(
    '{{ origen }}', {{ estado }} is null, coalesce({{ estado }},''),
    {{ condicion }} is null, coalesce({{ condicion }},''),
    {{ documento }} is null, coalesce({{ documento }},''),
    {{ tipo }} is null, coalesce({{ tipo }},'')
  )),256)
{%- endmacro %}
