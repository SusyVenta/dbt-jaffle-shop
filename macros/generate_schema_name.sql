{# 

https://docs.getdbt.com/docs/build/custom-schemas?version=1.12 
https://docs.getdbt.com/docs/build/environment-variables?version=1.12

Studio -> Orchestration --> Environments --> environment variable --> key: 'DBT_ENV_NAME'
    - project default:
    - development: 'dev'
    - prod: 'prod'

When in prod, all write to the main schema.
When in dev, each developer will write to <developer schema>_<schema name>
#}

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- set env = env_var('DBT_ENV_NAME') -%}

    {%- if custom_schema_name is none or env != 'prod' -%}

        {{ default_schema }}

    {%- else -%}

        {{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}