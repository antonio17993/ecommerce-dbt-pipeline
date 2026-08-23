with source as (
    select * from {{ source('raw', 'customers') }}
),

deduplicated as (
    -- el CRM origina ~1.5% de altas duplicadas (mismo customer_id).
    -- nos quedamos con un unico registro por cliente.
    select *
    from source
    qualify row_number() over (
        partition by customer_id
        order by signup_date nulls last
    ) = 1
),

cleaned as (
    select
        customer_id,
        {{ title_case('trim(first_name)') }}                as first_name,
        {{ title_case('trim(last_name)') }}                 as last_name,
        nullif(trim(lower(email)), '')                      as email,
        trim(email) is null or trim(email) = ''             as is_missing_email,

        country                                             as country_raw,
        case
            when upper(trim(country)) in ('SPAIN', 'ES', 'ESPANA', 'ESPAÑA') then 'Spain'
            when upper(trim(country)) in ('MEXICO', 'MX', 'MÉXICO') then 'Mexico'
            when upper(trim(country)) in ('ARGENTINA', 'AR') then 'Argentina'
            when upper(trim(country)) in ('COLOMBIA', 'CO') then 'Colombia'
            when upper(trim(country)) in ('CHILE', 'CL') then 'Chile'
            else {{ title_case('trim(country)') }}
        end                                                  as country,

        trim(city)                                          as city,
        cast(signup_date as date)                           as signup_date,
        signup_date is null                                 as is_missing_signup_date,
        marketing_opt_in
    from deduplicated
)

select * from cleaned
