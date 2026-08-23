with orders as (
    select * from {{ ref('stg_orders') }}
),

items as (
    select * from {{ ref('fct_order_items') }}
),

item_agg as (
    select
        order_id,
        count(*)                                            as n_items,
        sum(case when is_valid_item then 1 else 0 end)      as n_valid_items,
        sum(gross_amount)                                   as gross_revenue,
        sum(discount_amount)                                as discount_amount,
        sum(net_revenue)                                    as net_revenue,
        bool_or(not is_valid_item)                          as has_data_quality_issue
    from items
    group by 1
),

final as (
    select
        orders.order_id,
        orders.customer_id,
        orders.is_missing_customer,
        orders.order_date,
        orders.is_missing_order_date,
        orders.is_future_order_date,
        orders.order_status,
        orders.channel,
        orders.payment_method,

        coalesce(item_agg.n_items, 0)                       as n_items,
        coalesce(item_agg.n_valid_items, 0)                 as n_valid_items,
        coalesce(item_agg.gross_revenue, 0)                 as gross_revenue,
        coalesce(item_agg.discount_amount, 0)               as discount_amount,
        coalesce(item_agg.net_revenue, 0)                   as net_revenue,
        coalesce(item_agg.has_data_quality_issue, false)
            or orders.is_missing_customer
            or orders.is_missing_order_date                 as has_data_quality_issue,

        orders.order_status in ('paid', 'shipped', 'delivered')
                                                              as counts_as_revenue
    from orders
    left join item_agg on orders.order_id = item_agg.order_id
)

select * from final
