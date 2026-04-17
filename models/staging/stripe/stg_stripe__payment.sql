{{ config(materialized="incremental", incremental_strategy="append") }}

with

    source as (
        select *
        from {{ source("stripe", "payment") }}
        {% if is_incremental() %}
            -- this filter will only be applied on an incremental run
            where _etl_loaded_at >= (select max(_etl_loaded_at) from {{ this }})
        {% endif %}

    ),

    renamed as (

        select
            id as payment_id,
            orderid as order_id,
            paymentmethod as payment_method,
            status as payment_status,
            {{ cents_to_dollars("amount", 4) }} as payment_amount,
            created as payment_created,
            _etl_loaded_at
        from source

    )

select *
from renamed
