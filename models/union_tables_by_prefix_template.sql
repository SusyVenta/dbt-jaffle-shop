-- depends_on: {{ ref('stg_jaffle_shop__customers') }}
-- depends_on: {{ ref('stg_jaffle_shop__orders') }}
-- depends_on: {{ ref('stg_stripe__payment') }}
{{ union_tables_by_prefix(database=target.database, schema=target.schema, prefix='stg') }}