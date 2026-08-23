with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        cast(order_date as date)                            as order_date_raw,
        lower(trim(order_status))                           as order_status,
        lower(trim(channel))                                as channel,
        lower(trim(payment_method))                          as payment_method
    from source
),

cleaned as (
    select
        order_id,
        customer_id,
        customer_id is null                                 as is_missing_customer,

        order_date_raw,
        case
            when order_date_raw is null then null
            when order_date_raw > cast('{{ var("max_valid_order_date") }}' as date) then null
            else order_date_raw
        end                                                  as order_date,

        order_status,
        channel,
        payment_method
    from renamed
),

final as (
    select
        *,
        -- is_missing_order_date se calcula sobre la fecha YA LIMPIA:
        -- cubre tanto la fecha nula de origen como la fecha futura
        -- corrupta que se ha puesto a null (evita el bug de referenciar
        -- la columna cruda dentro del mismo select donde se redefine).
        order_date is null                                  as is_missing_order_date,
        order_date_raw is not null
            and order_date_raw > cast('{{ var("max_valid_order_date") }}' as date)
                                                              as is_future_order_date
    from cleaned
)

select * from final
