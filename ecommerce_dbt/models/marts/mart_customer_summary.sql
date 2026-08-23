{{
    config(
        materialized='table'
    )
}}

with customers as (
    select * from {{ ref('dim_customers') }}
),

orders as (
    select * from {{ ref('fct_orders') }}
    where counts_as_revenue
      and not is_missing_order_date
      and not is_missing_customer
),

customer_orders as (
    select
        customer_id,
        count(distinct order_id)                            as lifetime_orders,
        round(sum(net_revenue), 2)                           as lifetime_net_revenue,
        min(order_date)                                      as first_order_date,
        max(order_date)                                      as last_order_date
    from orders
    group by 1
),

final as (
    select
        customers.customer_id,
        customers.full_name,
        customers.country,
        customers.signup_date,
        customers.signup_month,
        customers.marketing_opt_in,

        coalesce(customer_orders.lifetime_orders, 0)        as lifetime_orders,
        coalesce(customer_orders.lifetime_net_revenue, 0)   as lifetime_net_revenue,
        customer_orders.first_order_date,
        customer_orders.last_order_date,
        date_diff(
            'day',
            customer_orders.last_order_date,
            (select max(last_order_date) from customer_orders)
        )                                                    as days_since_last_order,

        case
            when customer_orders.lifetime_orders is null then 'never_purchased'
            when customer_orders.lifetime_orders = 1 then 'one_time'
            when customer_orders.lifetime_orders >= 2 then 'repeat'
        end                                                  as customer_type
    from customers
    left join customer_orders on customers.customer_id = customer_orders.customer_id
)

select * from final
