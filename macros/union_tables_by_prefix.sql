{# https://docs.getdbt.com/reference/dbt-jinja-functions/execute?version=1.12 
'execute' ensures the query is executed when it can be.
#}
{%- macro union_tables_by_prefix(database, schema, prefix) -%}
    {{ log('Running union_tables_by_prefix with database ' ~ database ~ ', schema = ' ~ schema ~ ', prefix ' ~ prefix, info=true) }}
    {%- set tables=dbt_utils.get_relations_by_prefix(database=database, schema=schema, prefix=prefix) -%}

    {# print statement to select from all tables, union all - example even though they don't have same columns.  #}
    {%- for table in tables -%}
        {%- if not loop.first %}
            union all 
        {%- endif %}
        {%- set columns = adapter.get_columns_in_relation(table) %}
            select {{ columns[0].name }} as id
            from {{ table.database }}.{{ table.schema }}.{{ table.name }}
    {%- endfor -%}
    

    {%- if execute -%}
        {%- for table in tables -%}

            {# print all columns in each table #}
            {%- set columns = adapter.get_columns_in_relation(table) -%}
            {{ log('Columns for ' ~ table.name ~ ': ' ~ columns | map(attribute='name') | list, info=true) }}


            {# print sample raw in each table #}
            {%- set preview_query %}
                select * from {{ table.database }}.{{ table.schema }}.{{ table.name }} limit 2
            {%- endset -%}

            {%- set results = run_query(preview_query) -%}
            {{ log('Preview for ' ~ table.name ~ ':', info=true) }}
            {%- for row in results.rows -%}
                {{ log('  ' ~ row.values(), info=true) }}
            {%- endfor -%}
        
        {%- endfor -%}
    {%- endif -%}
    
{%- endmacro -%}

