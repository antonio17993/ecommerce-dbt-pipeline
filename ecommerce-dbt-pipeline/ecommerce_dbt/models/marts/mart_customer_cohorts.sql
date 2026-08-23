{{
    config(
        materialized='table'
    )
}}

with customers as (
    select
        customer_id,
        signup_month
    from {{ ref('dim_customers') }}
    where signup_month is not null
),

cohort_size as (
    select
        signup_month                                        as cohort_month,
        count(distinct customer_id)                          as cohort_customers
    from customers
    group by 1
),

orders as (
    select
        customer_id,
        date_trunc('month', order_date)                     as order_month
    from {{ ref('fct_orders') }}
    where counts_as_revenue
      and not is_missing_order_date
      and not is_missing_customer
),

customer_orders as (
    select
        customers.customer_id,
        customers.signup_month                              as cohort_month,
        orders.order_month,
        date_diff('month', customers.signup_month, orders.order_month)
                                                              as period_number
    from customers
    inner join orders on customers.customer_id = orders.customer_id
    where orders.order_month >= customers.signup_month
),

activity as (
    select
        cohort_month,
        period_number,
        count(distinct customer_id)                          as active_customers
    from customer_orders
    group by 1, 2
),

final as (
    select
        activity.cohort_month,
        activity.period_number,
        cohort_size.cohort_customers,
        activity.active_customers,
        round(
            activity.active_customers * 1.0 / nullif(cohort_size.cohort_customers, 0), 4
        )                                                    as retention_rate
    from activity
    inner join cohort_size on activity.cohort_month = cohort_size.cohort_month
)

select * from final
order by cohort_month, period_number
