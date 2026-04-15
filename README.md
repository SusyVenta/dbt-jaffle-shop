# Overview

This repo contains follow-along code from the official dbt course https://learn.getdbt.com/learn/course/dbt-fundamentals 
using Databricks as data storage solution.

## Tests

https://hub.getdbt.com/metaplane/dbt_expectations/latest/
https://hub.getdbt.com/dbt-labs/dbt_utils/latest/

dbt test --select source:jaffle_shop
dbt test --select source:*


## additional source columns added

alter table raw.jaffle_shop.orders add column _etl_loaded_at TIMESTAMP;
UPDATE raw.jaffle_shop.orders SET "_etl_loaded_at" = current_timestamp() WHERE _etl_loaded_at IS NULL;
select * from raw.jaffle_shop.orders limit 10;

alter table raw.stripe.payment add column _etl_loaded_at TIMESTAMP;
UPDATE raw.stripe.payment SET _etl_loaded_at = current_timestamp() WHERE _etl_loaded_at IS NULL;
select * from raw.stripe.payment limit 10;