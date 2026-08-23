{{
    config(
        materialized='table'
    )
}}

with items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

joined as (
    select
        items.order_item_id,
        items.order_id,
        items.product_id,
        orders.customer_id,
        orders.order_date,
        orders.order_status,
        orders.channel,
        orders.payment_method,

        products.category,
        products.subcategory,

        items.quantity,
        items.discount_pct,
        items.unit_price_at_order,

        -- flags de calidad heredados / detectados en el join
        items.is_invalid_quantity,
        items.is_invalid_discount,
        items.is_missing_price,
        products.product_id is null                          as is_orphan_product,
        orders.customer_id is not null
            and customers.customer_id is null                as is_orphan_customer,
        orders.is_missing_order_date,
        orders.is_future_order_date
    from items
    left join orders    on items.order_id = orders.order_id
    left join products   on items.product_id = products.product_id
    left join customers  on orders.customer_id = customers.customer_id
),

final as (
    select
        *,
        not (
            is_invalid_quantity
            or is_invalid_discount
            or is_missing_price
            or is_orphan_product
            or is_orphan_customer
            or is_missing_order_date
        )                                                    as is_valid_item,

        case
            when not (
                is_invalid_quantity or is_invalid_discount
                or is_missing_price or is_orphan_product
            )
            then round(quantity * unit_price_at_order, 2)
        end                                                  as gross_amount,

        case
            when not (
                is_invalid_quantity or is_invalid_discount
                or is_missing_price or is_orphan_product
            )
            then round(quantity * unit_price_at_order * discount_pct, 2)
        end                                                  as discount_amount,

        case
            when not (
                is_invalid_quantity or is_invalid_discount
                or is_missing_price or is_orphan_product
            )
            then round(quantity * unit_price_at_order * (1 - discount_pct), 2)
        end                                                  as net_revenue
    from joined
)

select * from final
