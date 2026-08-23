with customers as (
    select * from {{ ref('stg_customers') }}
)

select
    customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name                          as full_name,
    email,
    is_missing_email,
    country,
    city,
    signup_date,
    is_missing_signup_date,
    date_trunc('month', signup_date)                        as signup_month,
    coalesce(marketing_opt_in, false)                       as marketing_opt_in,
    marketing_opt_in is null                                as is_missing_marketing_opt_in
from customers
