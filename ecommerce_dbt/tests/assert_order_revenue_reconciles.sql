-- Test singular: el net_revenue agregado en fct_orders debe coincidir
-- exactamente con la suma de net_revenue de sus lineas validas en
-- fct_order_items. Si esto falla, hay un bug en la logica de agregacion.

with items as (
    -- sum(net_revenue) ignora nulos igual que en fct_orders.item_agg, asi
    -- que NO filtramos por is_valid_item aqui: is_valid_item tambien tiene
    -- en cuenta flags (cliente huerfano, fecha de pedido ausente) que no
    -- afectan al calculo del importe en si.
    select
        order_id,
        round(sum(net_revenue), 2) as items_net_revenue
    from {{ ref('fct_order_items') }}
    group by 1
),

orders as (
    select order_id, net_revenue
    from {{ ref('fct_orders') }}
)

select
    orders.order_id,
    orders.net_revenue        as orders_net_revenue,
    coalesce(items.items_net_revenue, 0) as items_net_revenue
from orders
left join items on orders.order_id = items.order_id
where abs(orders.net_revenue - coalesce(items.items_net_revenue, 0)) > 0.01
