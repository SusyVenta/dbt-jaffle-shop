# Overview

This repo contains follow-along code from the official dbt course https://learn.getdbt.com/learn/course/dbt-fundamentals 
using Databricks as data storage solution.

https://learn.getdbt.com/learning-paths/dbt-certified-developer
https://www.getdbt.com/dbt-certification


Reference repo (outdated): https://github.com/dbt-labs/dbt-Fundamentals-finished-project

## Tests

https://hub.getdbt.com/metaplane/dbt_expectations/latest/
https://hub.getdbt.com/dbt-labs/dbt_utils/latest/

Before running tests, run `dbt run`, which builds all models in DAG order. 

`dbt test --select source:jaffle_shop`
`dbt test --select source:*`

`dbt test --select test_type:generic`
`dbt test --select test_type:singular`

## `dbt build`

To run models and test on them progressively, in DAG order, use `dbt build`.
If any test fails, build fails so faulty data does not reach final dashboards.

`dbt build` runs:
- dbt run 
- dbt test
- dbt seed: loads csv into WH tables
- dbt snapshot: tracks SCD in your tables


How to build models only including and upstream of a certain model: `dbt build --select +dim_customers`


## additional source columns added

alter table raw.jaffle_shop.orders add column _etl_loaded_at TIMESTAMP;
UPDATE raw.jaffle_shop.orders SET "_etl_loaded_at" = current_timestamp() WHERE _etl_loaded_at IS NULL;
select * from raw.jaffle_shop.orders limit 10;

alter table raw.stripe.payment add column _etl_loaded_at TIMESTAMP;
UPDATE raw.stripe.payment SET _etl_loaded_at = current_timestamp() WHERE _etl_loaded_at IS NULL;
select * from raw.stripe.payment limit 10;

## Documentation

- in .yml files you can provide `description` for:
  - tables and views
  - sources
  - columns 


## Deployment 

- configure environments (Orchestration -> Environments): https://fh556.us1.dbt.com/deploy/70471823551914/projects/70471823574907/environments 

## [Materialization](https://docs.getdbt.com/docs/build/materializations?version=1.12)

- tables
- views - default
- ephemeral models: rendered as CTE that can be imported by other models. Nothing is actually built in the DW
- materialized views

can be specified in:
- dbt_project.yml at folder level 
- models .yml file in model folders - overrides dbt_project.yml
- at the top of a specific model with `{{ config(materialized=‘table’) }}`

## Jinja 

Pythonic templating language.

`{% %}` some operation is happening. Invisible to end user.

`{{}}`  something is printed to the user

``` 
{% set temperature = 30 %}

{% if temperature > 25 %}
a refreshing sorbet

{% else %}

{% endif %}
```

printing a list of numbers:
```
{% for i in range(26) %}
    select {{ i }} as number {% if not loop.last %} union all {% endif %}

{% endfor %}
```

printing set variables:

``` 
{# This is a comment #}
{% set day = "Wednesday %}
{% set day_1 = "Tuesday %}
{% set all_days = ["Monday", "Tuesday"] %}

Is it {{ day }} or {{ day_1}}? The first day is {{ all_days[0] }}

{%- for day in all_days -%}
    {{ day }}
{% endfor %}
```

dictionaries are also supported.

By default, each code line is rendered as space. To avoid that, use dashes: `{%-  -%}`

pivoting:

```
with payments as (
    select * from {{ ref('stg_payments')}}
    where status = 'success'
),

pivoted as (
    select 
        order_id,
        {%- set payment_methods = ["bank_transfer", "cupon"] -%}
        {%- for pm in payment_methods -%}
            sum(case when payment_method = {{ pm }} then payment_amount else 0 end) as {{ pm }}_amount
             {%- if not loop.last -%}
                ,
            {% endif %}
        {%- endfor -%}
        
    from payments
    group by 1
)

select * from pivotd
```

https://jinja.palletsprojects.com/en/stable/templates/

Can use templating to refer to the stage (if prod, do something): https://docs.getdbt.com/docs/build/custom-target-names?version=1.12#dbt-cloud-ide

## Macros 

Write generic reusable logic in one file. 
The macro can be referenced from different models. 
Can also import macros in existing packages.
They are a feature of Jinja. Same as a function. 

See macros/ folder

Tradeoff: DRY with macros vs readability

## packages 

hub.getdbt.com
