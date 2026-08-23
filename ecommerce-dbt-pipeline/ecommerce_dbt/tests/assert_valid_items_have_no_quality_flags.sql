-- Test singular: ninguna linea marcada como is_valid_item = true puede
-- tener a la vez algun flag de calidad activo. Protege contra una
-- regresion futura en la logica de fct_order_items.

select *
from {{ ref('fct_order_items') }}
where is_valid_item
  and (
      is_invalid_quantity
      or is_invalid_discount
      or is_missing_price
      or is_orphan_product
      or is_missing_order_date
  )
