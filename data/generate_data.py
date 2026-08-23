"""
Genera datos crudos sinteticos para un negocio de e-commerce ficticio ("Nortia Store").

El dataset se genera con semilla fija (reproducible) e incluye a proposito
problemas de calidad de datos tipicos de sistemas operacionales reales:
duplicados, nulos, formatos inconsistentes, referencias huerfanas y outliers.
Estos problemas se detectan y corrigen mas adelante en el proyecto dbt
(capa staging), lo que le da sentido real a los tests de calidad.

Uso:
    python data/generate_data.py

Salida:
    data/raw/customers.csv
    data/raw/products.csv
    data/raw/orders.csv
    data/raw/order_items.csv
"""

import random
from datetime import timedelta, date
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

SEED = 42
random.seed(SEED)
np.random.seed(SEED)
fake = Faker("es_ES")
Faker.seed(SEED)

OUT_DIR = Path(__file__).parent / "raw"
OUT_DIR.mkdir(parents=True, exist_ok=True)

N_CUSTOMERS = 3000
N_PRODUCTS = 600
N_ORDERS = 12000

START_DATE = date(2023, 1, 1)
END_DATE = date(2025, 12, 31)

COUNTRY_VARIANTS = {
    "Spain": ["Spain", "SPAIN", "spain", "ES", "Espana"],
    "Mexico": ["Mexico", "MX", "mexico", "México"],
    "Argentina": ["Argentina", "AR", "argentina"],
    "Colombia": ["Colombia", "CO", "colombia"],
    "Chile": ["Chile", "CL", "chile"],
}

CATEGORY_MAP = {
    "Electronica": ["Auriculares", "Portatiles", "Smartphones", "Accesorios"],
    "Hogar": ["Cocina", "Decoracion", "Muebles"],
    "Moda": ["Camisetas", "Pantalones", "Calzado", "Accesorios de moda"],
    "Deporte": ["Fitness", "Ciclismo", "Running"],
    "Belleza": ["Cuidado facial", "Maquillaje", "Perfumes"],
}
CATEGORY_CASING_VARIANTS = lambda c: random.choice([c, c.upper(), c.lower()])

CHANNELS = ["web", "app", "marketplace"]
PAYMENT_METHODS = ["tarjeta", "paypal", "transferencia", "contrareembolso"]
ORDER_STATUSES = ["created", "paid", "shipped", "delivered", "cancelled", "refunded"]
ORDER_STATUS_WEIGHTS = [0.03, 0.07, 0.10, 0.68, 0.07, 0.05]


def random_date(start: date, end: date) -> date:
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))


# ---------------------------------------------------------------------------
# customers
# ---------------------------------------------------------------------------
def build_customers(n: int) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        first = fake.first_name()
        last = fake.last_name()
        country_clean = random.choice(list(COUNTRY_VARIANTS.keys()))
        country_dirty = random.choice(COUNTRY_VARIANTS[country_clean])

        email = f"{first}.{last}@{fake.free_email_domain()}".lower()
        # ~4% de emails nulos (fallo de captura en el formulario)
        if random.random() < 0.04:
            email = None
        # ~3% con espacios / mayusculas raras (fallo de import CRM)
        elif random.random() < 0.03:
            email = f"  {email.upper()}  "

        signup_date = random_date(START_DATE, END_DATE)
        # ~2% sin fecha de alta
        if random.random() < 0.02:
            signup_date = None

        rows.append(
            {
                "customer_id": i,
                "first_name": first,
                "last_name": last,
                "email": email,
                "country": country_dirty,
                "city": fake.city(),
                "signup_date": signup_date,
                "marketing_opt_in": random.choice([True, False, None]),
            }
        )

    df = pd.DataFrame(rows)

    # ~1.5% de clientes duplicados por completo (bug de sincronizacion del CRM)
    dupes = df.sample(frac=0.015, random_state=SEED)
    df = pd.concat([df, dupes], ignore_index=True)
    return df


# ---------------------------------------------------------------------------
# products
# ---------------------------------------------------------------------------
def build_products(n: int) -> pd.DataFrame:
    rows = []
    categories = list(CATEGORY_MAP.keys())
    for i in range(1, n + 1):
        category = random.choice(categories)
        subcategory = random.choice(CATEGORY_MAP[category])
        unit_cost = round(np.random.uniform(3, 150), 2)
        margin = np.random.uniform(1.3, 2.8)
        unit_price = round(unit_cost * margin, 2)

        # ~2% sin precio (producto recien creado, aun sin publicar)
        if random.random() < 0.02:
            unit_price = None
        # ~1% con coste negativo (error de tipeo en el ERP)
        if random.random() < 0.01:
            unit_cost = -abs(unit_cost)

        rows.append(
            {
                "product_id": i,
                "product_name": f"{subcategory} {fake.word().capitalize()} {i}",
                "category": CATEGORY_CASING_VARIANTS(category),
                "subcategory": subcategory,
                "unit_cost": unit_cost,
                "unit_price": unit_price,
                "is_active": random.random() > 0.05,
            }
        )

    df = pd.DataFrame(rows)
    # ~1% de productos duplicados (mismo product_id, doble alta en el ERP)
    dupes = df.sample(frac=0.01, random_state=SEED)
    df = pd.concat([df, dupes], ignore_index=True)
    return df


# ---------------------------------------------------------------------------
# orders + order_items
# ---------------------------------------------------------------------------
def build_orders_and_items(n_orders: int, customer_ids: list, product_ids: list):
    orders = []
    items = []
    item_id = 1

    # un pequeno grupo de customer_id "fantasma" que no existen en customers
    # (ej. cuenta borrada tras hacer el pedido) para forzar huerfanos
    ghost_customer_ids = [max(customer_ids) + i for i in range(1, 21)]
    ghost_product_ids = [max(product_ids) + i for i in range(1, 11)]

    for order_id in range(1, n_orders + 1):
        customer_id = random.choice(customer_ids)
        # ~0.5% de pedidos con cliente fantasma / nulo
        r = random.random()
        if r < 0.003:
            customer_id = random.choice(ghost_customer_ids)
        elif r < 0.006:
            customer_id = None

        order_date = random_date(START_DATE, END_DATE)
        # ~0.3% con fecha nula
        if random.random() < 0.003:
            order_date = None
        # ~0.2% con fecha corrupta en el futuro (bug de reloj del servidor)
        elif random.random() < 0.002:
            order_date = END_DATE + timedelta(days=random.randint(30, 400))

        status = random.choices(ORDER_STATUSES, weights=ORDER_STATUS_WEIGHTS, k=1)[0]

        orders.append(
            {
                "order_id": order_id,
                "customer_id": customer_id,
                "order_date": order_date,
                "order_status": status,
                "channel": random.choice(CHANNELS),
                "payment_method": random.choice(PAYMENT_METHODS),
            }
        )

        n_items = np.random.choice([1, 2, 3, 4, 5], p=[0.35, 0.30, 0.18, 0.11, 0.06])
        chosen_products = random.sample(product_ids, k=min(n_items, len(product_ids)))
        for product_id in chosen_products:
            quantity = int(np.random.choice([1, 1, 1, 2, 2, 3, 4], size=1)[0])
            # ~0.5% cantidad invalida (0 o negativa) por error de picking
            if random.random() < 0.005:
                quantity = random.choice([0, -1])

            discount_pct = round(np.random.choice(
                [0, 0, 0, 0.05, 0.10, 0.15, 0.20], size=1
            )[0], 2)
            # ~0.3% descuento corrupto (>1, error de formato % vs fraccion)
            if random.random() < 0.003:
                discount_pct = round(random.uniform(1.5, 5.0), 2)

            unit_price_at_order = None  # se resuelve luego, puede ir nulo a veces
            item_product_id = product_id
            # ~0.4% de lineas referencian un producto fantasma (borrado del catalogo)
            if random.random() < 0.004:
                item_product_id = random.choice(ghost_product_ids)

            items.append(
                {
                    "order_item_id": item_id,
                    "order_id": order_id,
                    "product_id": item_product_id,
                    "quantity": quantity,
                    "discount_pct": discount_pct,
                }
            )
            item_id += 1

    return pd.DataFrame(orders), pd.DataFrame(items)


def main():
    print(f"Generando datos sinteticos (seed={SEED})...")

    customers = build_customers(N_CUSTOMERS)
    products = build_products(N_PRODUCTS)
    orders, order_items = build_orders_and_items(
        N_ORDERS,
        customer_ids=customers["customer_id"].unique().tolist(),
        product_ids=products["product_id"].unique().tolist(),
    )

    # unit_price_at_order: precio del producto en el momento del pedido,
    # con algo de variacion respecto al precio de catalogo actual (~2%
    # nulo, simulando fallos del snapshot de precio del checkout)
    price_lookup = products.drop_duplicates("product_id").set_index("product_id")["unit_price"]
    prices = order_items["product_id"].map(price_lookup)
    noise = np.random.uniform(0.95, 1.05, size=len(order_items))
    order_items["unit_price_at_order"] = (prices * noise).round(2)
    null_price_mask = np.random.random(len(order_items)) < 0.02
    order_items.loc[null_price_mask, "unit_price_at_order"] = None

    customers.to_csv(OUT_DIR / "customers.csv", index=False)
    products.to_csv(OUT_DIR / "products.csv", index=False)
    orders.to_csv(OUT_DIR / "orders.csv", index=False)
    order_items.to_csv(OUT_DIR / "order_items.csv", index=False)

    print(f"  customers.csv    -> {len(customers):,} filas")
    print(f"  products.csv     -> {len(products):,} filas")
    print(f"  orders.csv       -> {len(orders):,} filas")
    print(f"  order_items.csv  -> {len(order_items):,} filas")
    print(f"Guardado en {OUT_DIR}/")


if __name__ == "__main__":
    main()
