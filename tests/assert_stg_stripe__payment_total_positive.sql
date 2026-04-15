/*
To run only this test: dbt test --select stg_stripe__payment


Refunds have a negative amount, so the total amount should always be >= 0.
Therefore return records where this isn't true to make the test fail.
*/

select
    order_id, 
    sum(payment_amount) as total_amount 
from {{ ref('stg_stripe__payment') }}
group by order_id 
having sum(payment_amount) < 0