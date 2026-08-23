with products as (
    select * from {{ ref('stg_products') }}
),

final as (
    select
        product_id,
        product_name,
        category,
        subcategory,
        unit_cost,
        is_cost_corrected,
        unit_price,
        is_missing_price,
        case
            when unit_price is null or unit_price = 0 then null
            else round((unit_price - unit_cost) / unit_price, 4)
        end                                                  as margin_pct,
        case
            when unit_price is null then 'unknown'
            when unit_price < 30 then 'low'
            when unit_price < 100 then 'medium'
            else 'high'
        end                                                  as price_tier,
        is_active
    from products
)

select * from final
