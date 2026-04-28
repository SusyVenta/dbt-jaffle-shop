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
`dbt test --select test_type:data` - not nulls, expected values, unique, ...
`dbt test --select test_type:unit` - runs unit tests. Expects the output of a model to align with some provided sample data. 
`dbt test --select int_customers --store-failures` - materializes the results of this test into the DW. Can then go to the dbt Insights tab and query `select * from analytics.dbt_ventafri.not_null_stg_jaffle_shop__customers_null_test;`

Best way to run tests: `dbt build --fail-fast`: immediately cancels dbt run if you have a failure. Any failure stops the run immediately, even for unrelated models.  

Data tests = assertions made on models, sources, seeds, or snapshots in a dbt projects.
SQL satements that if produce result rows make the test fail. 
dbt ensures data quality through a testing framework. 
Why test:
    - ensure code works as expected 
    - produce accurate data 
    - build trust with stakeholders 
    - save time for future development

What makes a good test:
    - automated
    - fast 
    - reliable 
    - informative
    - focused

Types:
    - standard: unique / not null / accepted values 
    - contents of the data 
    - constraints of the table 
    - grain of the table 
    - compare different tables 
    - freshness of data -> warn / error 
    - compare new refactored models vs legacy ones: dbt audit_helper package 

More types:
    - singular test: custom SQL to test a specific model 
    - generic test: custom SQL to test multiple models. You can use these to override dbt's own generic tests (not nulls, unique, etc).

Packages: 
    - dbt_expectations
    - dbt_utils
    - dbt_meta_testing
    - audit_helper
    - [dbt-coverage](https://github.com/dbt-checkpoint/dbt-checkpoint)
        A bunch of hooks to run locally before you actually commit changes
    - [dbt_dataquality](hub.getdbt.com/divergent-insights/dbt_dataquality/latest/)
    - [dbt-project-evaluator](https://github.com/dbt-labs/dbt-project-evaluator)

https://docs.getdbt.com/blog/how-to-build-a-mature-dbt-project-from-scratch?version=1.12

`dbt_meta_testing` package to validate we are in line with testing expectations we created in the team. 
    - Can enforce test coverage. Specify required coverage in dbt_project.yml 
    - To exclude one model - at the top of the model add:
        ```
        {{ config(required_tests=None) }}
        ```
    - `dbt run-operation required_tests` - can be integrated in the CI build: `dbt run-operation required_tests --args "{'models':'$(dbt list -m state:modified --state target)'}"`

Tests can be defined in:
- models/*.yml : only generic tests. Can schedule in production. 
- custom tests in /test dir. .sql files. 
- source freshness tests in /staging/*_sources.yml --> `dbt source freshness` can be scheduled in production

When to test:
    - in development - to find bugs before opening a pull request
    - pre-commit hooks
    - automatically as an approval AND/OR CI check in your PR. Fail deployment if tests fail. 
    - in production with notification failures

## `dbt build`

To run models and test on them progressively, in DAG order, use `dbt build`.
If any test fails, build fails so faulty data does not reach final dashboards.

`dbt build` runs:
- dbt run 
- dbt test
- dbt seed: loads csv into WH tables
- dbt snapshot: tracks SCD in your tables


How to build models only including and upstream of a certain model: `dbt build --select +dim_customers`

## Sources 

Importing existing sources: can use the [generate_source](https://github.com/dbt-labs/dbt-codegen/tree/0.14.0/#generate_source-source) yaml from codegen library 
Create a new file template containing `{{ codegen.generate_source(schema_name= 'jaffle_shop', database_name= 'raw') }}` and run it for each schema.
Never hardoce tables. Always use `from {{ source('<source name>', '<table name>') }}`

### additional source columns added

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
- incremental models: `{{ config(materialized=incremental, incremental_strategy="append") }}` 
  - Materialization strategy to only load new or changed data since your last run. 
  - Recommended for very large tables with millions of rows, to reduce time and compute. 
  - `{{ this }}`: currently existing database object mapped to this model.
  - `is_incremental()` macro: returns true if 1) the model already exists in the db 2) the `--full-refresh` flag is not passed 3) the running model is configured with materialized='incremental'
     ``` 
        {% if is_incremental() %}
        where updated_at > (select max(updated_at) from {{ this }})
        {% endif %}
     ```
     see stg__stripe_payment model
  - When working with incremental models, we define a cut-off time for what constitutes new data (e.g. all data arriving after the most recently collected `loaded_at` timestamp).    
  - What if data shows up late? Strategies:
    - Append only: widen cut-off date: `where updated_at > (select dateadd(day, -3, max(updated_at) from {{ this }})` --> end up with duplicated records if you just append. `insert into`. `{{ config(materialized=incremental, incremental_strategy="append") }}`. Best for immutable event streams.
    - Merge/upsert: use a primary key to deduplicate data in case of overlap. Adds new records or merge on existing ones. Needs to do a full table scan. `merge into table`. `{{ config(materialized=incremental, incremental_strategy="merge", unique_key='order_id') }}`. Best for models doing a small number of updates each run and when append would create duplicates. 
    - Delete + insert: delete certain existing rows and then add new ones based on primary key. Equivalent of merge/upsert when the first is not supported in the data platform. Requires full table scan. `{{ config(materialized=incremental, incremental_strategy="delete+insert", unique_key='order_id') }}`
    - Insert_overwrite: replace entire partitions. Only scans configured partitions. Much more efficient than merge in BigQuery. Similar to delete + insert on other platforms.  `{{ config(materialized=incremental, incremental_strategy="insert_overwrite", unique_key='order_id', partitioned_by={"field": "order_date", "data_type": "date", "granularity": "day"}) }}`
    - microbatch: divide data into atomic, time-bound units e.g. day. Splits large models into multiple time-bounded queries: batches. Best for very large time-series datasets. Uses insert/overwrite or delete+insert depending on platform. dbt processes current batch (e.g. current day) + any other units of time configured in your lookback window. 
        - `{{ config(materialized=incremental, incremental_strategy="microbatch", unique_key='order_id', event_time="order_date", begin="2026-02-03", batch_size="day") }}`
        - can rerun only specific batches: `dbt run --select fct_orders --event-time-start "2026-01-01" --event-time-end "2026-04-01"`
  - What if data arrives really late? 
    - The goal of incremental models is to approximate the 'true' table in a fraction of the runtime. Recommended strategy:
      - Perform an analysis on the arrival time of the data. How much later does p90 data arrive? What about the very last arrival? 
      - Figure out your organization's tolerance for correctness 
      - Set the cutoff based on these two inputs 
      - Once a week, perform a full-refresh run to get the true table 
    - Trade-off: close enough and performant 
    - Good candidates: 
      - immutable event-streams: append only, no updates 
      - if there are updates, a reliable updated_at field 
    - Recommendation: start materializing as view --> table --> incremental model
    - Pick strategy based on:
        - data platform constraints: https://docs.getdbt.com/reference/resource-configs?version=1.12 
        - data volume
        - reliability of primary key
    - https://docs.getdbt.com/docs/build/incremental-strategy?version=1.12
  - Can configure incremental models to deal with schema changes:
    dbt_project.yml :
    ```
        models:
            +on_schema_change: "sync_all_columns"
    ```

    at the top of the model:
    ```
        {{config(materialized='incremental', unique_key='date_day', on_schema_change='fail')}}
    ```
    on_schema_change options:
        - ignore: default behavior. new columnw will not appear in target table. removed columns will cause the run to fail. 
        - fail: triggers an error message when source and target differ. 
        - append_new_columns: new columns are appended to the target table. if columns are removed form the source, they continue to exist in the target table but are no longer populated. 
        - sync_all_columns: adds any new columns to the existing table and removes any columns that go missing in source. The same behavior applies to data type changes. Might require full table scan (BigQuery).
  - Incremental jobs best practices:
    - A CI job is triggered when a Git pull request is merged. 
    - 
    - `dbt build --select state:modified+`. Only rebuilds models that changed in last merge + models that depend on changes.
    - Because your CI job is building modified models into a PR-specific schema, on the first execution of dbt build --select state:modified+, the modified incremental model will be built in its entirety because it does not yet exist in the PR-specific schema and is_incremental will be false. Not ideal: slow and expensive. Can avoid by using `dbt clone --select state:modified+,config.materialized:incremental,state:old` before `dbt build --select state:modified+`
      Clones all the pre-existing incremental models that have been modified or are downstream of another module that has been modified.
      state:old --> new incremental models to run with a full refresh since they don't exist yet in prod. 

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
dbt additional Jinja function available: https://docs.getdbt.com/reference/dbt-jinja-functions-context-variables?version=1.12
    - e.g.: https://docs.getdbt.com/reference/dbt-jinja-functions/run_query?version=1.12 see macros/run_select
## Macros 

Write generic reusable logic in one file. 
The macro can be referenced from different models. 
Can also import macros in existing packages.
They are a feature of Jinja. Same as a function. 

See macros/ folder

Tradeoff: DRY with macros vs readability

Calling a macro:
- from a model: `{{ cents_to_dollars("amount", 4) }}`
- standalone: `dbt run-operation grant_select`

## packages 

hub.getdbt.com

add to packages.yml then run `dbt deps`

## Best practices

- Use sources and reference models instead of hardcoding sources. 
- Use format button / automatic linting and formatting tools 
- Use CTEs instead of subqueries. Use this structure: first import CTEs, then logical CTEs, then final CTEs, then final `select * from final`. 
- Use comments to clarify logic 
- Use fully qualified table names and references 
- Split transformations into stage type:
    - staging: casting, renaming fields on sources 
    - intermediate (optional)
    - marts 
- file names should start either with `fct` (facts, main events) or `dim` (descriptinve context)
- descriptive variables, CTEs, column names.
- specify selected columns explicitly instead of select * 
- Rename all variables once instead of multiple times throughout the logic 
- Filter as early as possible as much as possible. Keep least amount of data.

## Onboarding existing models and auditing diff with new refactored models 

https://hub.getdbt.com/dbt-labs/audit_helper/latest/

- `audit_helper.compare_row_counts` 
- compare column values: `audit_helper.compare_all_columns`

## User-defined Functions (UDFs)

functions native to the data platform. 
https://docs.getdbt.com/docs/build/udfs?version=1.12

referenced using `{{ function(...) }}`

## Snapshots - Slowly Changing Dimensions type 2 

Snapshots implement type 2 SCD on immutable source tables. 
You create a separate table that keeps track of all changes happened in your source table. 
Track how a rows have changed over time.
Configured in /snapshots folder in .yml files. 
Should be handled with dedicated permissions so they cant be dropped and users know they're not the official tables.

https://docs.getdbt.com/docs/build/snapshots?version=1.12

Can identify changes by comparing columns or using an updated_at field (preferred). 

Can select from snapshot tables using the ref macro, but can't preview or compile their SQL . 
Snapshot tables are a clone of the source + additional meta fields.
Snapshots need to be run twice to actually capture changes:  `dbt snapshot`:
 - first time: creates initial snap table, all columns from select statement, dbt-meta fields added, dbt_valid_to = null 
 - subsequent runs: check for changed records, update dbt_valid_to_column on changed records, isert updated records, dbt_valid_to = null or new record 

`dbt build` automatically snapshots all snapshots

from 'return_pending' to 'returned'
```
update raw.jaffle_shop.orders 
set status = 'returned' 
where id = 23;
```

`dbt snapshot`

`select * from analytics.dbt_sventafridda.order_snapshot;` or in dbt `select * from {{ ref('order_snapshot') }}` --> both changes are there 

## Analyses

- In analysis folder. SQL files. Support jinja. Are not built when running `dbt build`, don't have tests, are not materialized. 
- Can be compiled with `dbt compile`
- Useful for 
    - running one-off queries against DW
    - training queries 
    - auditing / refactoring. Build a refactored model to then compare with original source before replacing it. 

## Seeds 

- CSV files in the /data folder 
- short amounts of data to be loaded into the DW as a table by running `dbt seed`
- Can be referenced with 'ref' macro 
- Use case example: country codes, employee email addresses for small companies 
- Not designed for large or frequently changin data (better to use an API in that case)

## Exposures 

- Way to provide visibility on how dbt models are used downstream e.g. by dashboards
- Allow to easily identify POCs behind relevant models and metrics and therefore dashboards
- YAML-defined resources that appear as a node in the lineage graph and represent downstream consumers of data models like:
    - BI dashboards, data science notebooks, or external applications 
- Allows to populate a dedicated page in the docs - catalog - with context relevant to data consumers 
- Exposure files should be listed in the models/exposures/ dir 
- https://docs.getdbt.com/docs/build/exposures?version=1.12
- To ensure that your data that feeds into your exposures have been run recently, run: `dbt run --select +exposure:*`
- to preview data of a metric that feeds an exposure: `dbt sl query --metrics order_total`

## State 

- dbt is by design 
    - idempotent: executing `dbt build` command multiple times with the same data, produces the same results 
    - stateless: each `dbt build` command runs independenty of the results of the previous build  
- dbt does store state: a detailed, point in time view of project resources (nodes), db objects, and invocation results (artifacts)
- dbt stores the following every time you execute `dbt build`:
    - `manifest.json` - state of the resource files (models, sources, tests)
    - `run_results.json` - state of the results of a command that was run 
- We might want to leverage state to:
    - build only new or recently modified models: `dbt run --select model_b+` or `dbt run --select state:modified+` checks wat changed vs last run and runs everythign downstream of it
    - troubleshooting issues in the DAG: 
        - `dbt retry`: automatically retries what failed in the previous execution 
            - run_results.json is used to know what passed / failed in the last run 
            - the same selectors of the prior command will be passed through 
            - can be applied to: build, compile, clone, docs generate, seed, snapshot, test, run, run-operation

## dbt Mesh 

Choices:
- single monolithic project architecture: your team interacts with a single dbt project. 
    - ok when project is small or when the same team members support different business functions at the same time. 
- dbt Mesh: a pattern that enables domain data ownership of your data assets without creating silos. 
    - domain teams: can operate at different velocities, can expose their models to other teams 
    - central data teams get visibility into the full lineage of transformations, are not a bottleneck for domain teams, run in a single platform 
    - it's an architectural pattern supported by a number of features like:
        - model governance:
            - **Model contracts** : 
                - every model can have a contract that defines guarantees around data shape so changes dont break downstream models. 
                - allow you to guarantee the shape of your model: columns names and data types 
                - if the model does not have the initially defined columns and dtypes, you get an error when doing dbt run 
                - defined in .yml files by ilsting all columns, dtypes, constraints (e.g. not null - platform specific)
                - constraints are pre-flight check vs tests are post-hoc checks
                - see `models/marts/finance/_fct_orders.yml`
            - **Model versions**: 
                - when a model's contract changes in a way that's not backwards compatible, it should be reflected with a new version. Model versions also allow deprecating models.
                - a model version is a separate sql file containing the new version of a model
                - allow to test pre-release tests in production and give people time to migrate
                - 2 ways to specify version: 
                    - diff only (recommended) - see `models/marts/marketing/dim_customers.yml`
                    - fully specified
                - by default, the latest model reference is queried 
                - to specify: `{{ ref('dim_customers', v=1) }}`
                - to run: 
                    - all versions: `dbt run --select dim_customers`
                    - run a specific version: `dbt run --select dim_customers_v2`
                    - run latest version: `dbt run -s dim_customers version:latest`
            - **Groups and access modifiers**: 
                - models can have private or public access levels, and they can be grouped. 
                - You can control who can reference which models, from both centralized and decentralized project structures. 
                - groups = DAG nodes that are related to one another and owned by a specific team. A way for a business to organize models based on ownership.
                    - defined in a .yml file: either models yml or dedicated yml 
                    - for each group you need to define at least: name and owner with a name and email address.
                    - each model can only belong to one group. can specify in models yml file. Can also specify at folder level (dbt_project.yml)
                    - see `models/groups.yml` and `models/marts/_fct_orders.yml`
                - access modifiers: 
                    - which models can access a specific model
                    - 3 types:
                        - public - can be accessed by models in any group, package, or project 
                        - protected: DEFAULT - can be accessed by models in same project or group 
                        - private: can only be accessed by models in same group
                    - they are a separate config wrt DW permissions or dbt platform permissions!

        - data discovery via dbt catalog: once correct permissions on a model have been set to share the model, the intended consumers can explore available models via the catalog. 
        - cross-project reference: 
            - add external project in `dependencies.yml` - supports declaring another dbt project as a dependency. 
            - https://docs.getdbt.com/docs/mesh/govern/project-dependencies?version=1.12
            - `{{ ref('external_project', 'public_model') }}` 
            - to successfully reference a model, the model needs to be public and at least one successful job for that model must have run.
            - can trigger a job to run after another job has finished, even if the other job is from a different project.

