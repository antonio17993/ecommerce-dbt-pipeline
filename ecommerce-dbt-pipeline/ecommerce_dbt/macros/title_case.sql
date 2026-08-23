{% macro title_case(column_expr) %}
{#
    DuckDB no trae una funcion initcap() nativa (esta seria parte de la
    extension icu, que requiere descarga de red no disponible en este
    entorno). Se reimplementa "poner en mayuscula la primera letra de
    cada palabra" con funciones de lista nativas de DuckDB.
#}
array_to_string(
    list_transform(
        string_split({{ column_expr }}, ' '),
        w -> upper(left(w, 1)) || lower(right(w, length(w) - 1))
    ),
    ' '
)
{% endmacro %}
