{{
    config(
        materialized='table'
    )
}}

with items as (
    select * from {{ ref('fct_order_items') }}
    where is_valid_item
),

orders as (
    select * from {{ ref('fct_orders') }}
    where counts_as_revenue
      and not is_missing_order_date
),

revenue_items as (
    select
        items.*,
        orders.order_date
    from items
    inner join orders on items.order_id = orders.order_id
),

final as (
    select
        date_trunc('month', order_date)                     as month,
        category,
        channel,
        count(distinct order_id)                            as n_orders,
        sum(quantity)                                        as units_sold,
        round(sum(net_revenue), 2)                           as net_revenue,
        round(sum(discount_amount), 2)                       as discount_amount,
        round(sum(net_revenue) / nullif(count(distinct order_id), 0), 2)
                                                              as avg_order_value
    from revenue_items
    group by 1, 2, 3
)

select * from final
order by month, category, channel
