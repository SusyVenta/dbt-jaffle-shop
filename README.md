# Overview

This repo contains follow-along code from the official dbt course https://learn.getdbt.com/learn/course/dbt-fundamentals 
using Databricks as data storage solution.

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