with source as (
    select * from {{ source('raw', 'order_items') }}
),

cleaned as (
    select
        order_item_id,
        order_id,
        product_id,

        quantity                                            as quantity_raw,
        case when quantity > 0 then quantity else null end  as quantity,
        quantity is null or quantity <= 0                   as is_invalid_quantity,

        discount_pct                                        as discount_pct_raw,
        case
            when discount_pct between 0 and 1 then discount_pct
            else null
        end                                                  as discount_pct,
        discount_pct is null or discount_pct not between 0 and 1
                                                               as is_invalid_discount,

        unit_price_at_order,
        unit_price_at_order is null                          as is_missing_price
    from source
)

select * from cleaned
