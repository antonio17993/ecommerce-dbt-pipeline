#!/usr/bin/env bash
# Reconstruye el pipeline completo de principio a fin:
#   1. genera los datos crudos sinteticos
#   2. corre el proyecto dbt (modelos + tests) contra DuckDB
#   3. genera la documentacion de dbt
#   4. ejecuta el notebook de analisis de negocio
#
# Uso:
#   pip install -r requirements.txt
#   bash scripts/run_pipeline.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> 1/4 Generando datos sinteticos..."
python3 data/generate_data.py

echo "==> 2/4 Ejecutando dbt build (modelos + tests)..."
mkdir -p warehouse
cd ecommerce_dbt
export DBT_PROFILES_DIR="$(pwd)"
dbt build

echo "==> 3/4 Generando documentacion de dbt (dbt docs serve para verla)..."
dbt docs generate
cd "$ROOT_DIR"

echo "==> 4/4 Ejecutando el notebook de analisis..."
jupyter nbconvert --to notebook --execute --inplace \
    notebooks/business_analysis.ipynb \
    --ExecutePreprocessor.timeout=120

echo ""
echo "Listo. Para explorar:"
echo "  - dbt docs:   cd ecommerce_dbt && DBT_PROFILES_DIR=\$(pwd) dbt docs serve"
echo "  - notebook:   jupyter notebook notebooks/business_analysis.ipynb"
echo "  - base:       warehouse/ecommerce.duckdb (DuckDB, se puede abrir con 'duckdb warehouse/ecommerce.duckdb')"
