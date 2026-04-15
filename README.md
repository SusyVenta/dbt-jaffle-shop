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

## Materialization

- tables
- views - default
- ephemeral models: rendered as CTE that can be imported by other models. Nothing is actually built in the DW

can be specified in:
- dbt_project.yml at folder level 
- models .yml file in model folders - overrides dbt_project.yml
- at the top of a specific model with `{{ config(materialized=‘table’) }}`