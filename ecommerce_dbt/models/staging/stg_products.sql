with source as (
    select * from {{ source('raw', 'products') }}
),

deduplicated as (
    -- ~1% de productos dados de alta dos veces en el ERP con el mismo product_id
    select *
    from source
    qualify row_number() over (
        partition by product_id
        order by unit_price nulls last
    ) = 1
),

cleaned as (
    select
        product_id,
        trim(product_name)                                  as product_name,
        {{ title_case('trim(category)') }}                  as category,
        {{ title_case('trim(subcategory)') }}                as subcategory,

        -- un coste negativo es un error de tipeo del ERP: se corrige a su
        -- valor absoluto y se deja constancia con un flag para auditoria
        case when unit_cost < 0 then abs(unit_cost) else unit_cost end as unit_cost,
        unit_cost < 0                                        as is_cost_corrected,

        unit_price,
        unit_price is null                                   as is_missing_price,
        is_active
    from deduplicated
)

select * from cleaned
