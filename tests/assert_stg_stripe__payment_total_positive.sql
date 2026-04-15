/*
To run only this test: dbt test --select stg_stripe__payment
*/

select
    order_id, 
    sum(payment_amount) as total_amount 
from {{ ref('stg_stripe__payment') }}
group by order_id 
having sum(payment_amount) < 0