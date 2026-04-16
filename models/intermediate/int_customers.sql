-- imports
with
    customers as (select * from {{ ref("stg_jaffle_shop__customers") }}),
    orders as (select * from {{ ref("int_orders") }}),

    customer_order_ids as (
        select
            customer_id,
            array_agg(order_id) as customer_order_ids
        from orders
        group by customer_id
    ),

    customer_orders as (
        select
            orders.*,
            customers.full_name,
            customers.last_name,
            customers.first_name,
            customer_order_ids.customer_order_ids,
            min(order_date) over (
                partition by orders.customer_id
            ) as customer_first_order_date,
            min(valid_order_date) over (
                partition by orders.customer_id
            ) as customer_first_non_returned_order_date,
            max(valid_order_date) over (
                partition by orders.customer_id
            ) as customer_most_recent_non_returned_order_date,
            count(*) over (partition by orders.customer_id) as customer_order_count,
            sum(nvl2(valid_order_date, 1, 0)) over (
                partition by orders.customer_id
            ) as customer_non_returned_order_count,
            sum(nvl2(valid_order_date, total_amount_paid, 0)) over (
                partition by orders.customer_id
            ) as customer_total_lifetime_value
        from orders
        inner join customers on orders.customer_id = customers.customer_id
        inner join customer_order_ids on orders.customer_id = customer_order_ids.customer_id
    ),

    customer_average_order_value as (
        select
            *,
            {{ function("safe_divide") }} (
                customer_total_lifetime_value, customer_non_returned_order_count
            ) as customer_avg_non_returned_order_value
        from customer_orders
    )

select *
from customer_average_order_value