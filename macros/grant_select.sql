{# https://docs.getdbt.com/reference/dbt-jinja-functions/target?version=1.12 
    This is supposed to be run on Snowflake so it fails on Databricks
#}
{% macro grant_select(schema=target.schema, role=target.role) %}
    {% set sql %}
        {{ log("Granting select on schema " ~ target.schema ~ " to role " ~ target.role, info=true) }}
        grant usage on schema {{ schema }} to role {{ role }} ;
        grant select on all tables in schema to role {{ role }} ;
        grant select on all views in schema to role {{ role }} ;

        
    {% endset %}

    {% do run_query(sql) %}
{% endmacro %}