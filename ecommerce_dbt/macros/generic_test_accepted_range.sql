{% test accepted_range(model, column_name, min_value=none, max_value=none, inclusive=true) %}
{#
    Test generico propio (equivalente simplificado a dbt_utils.accepted_range)
    para no depender de un paquete externo: el sandbox de esta sesion no
    tiene salida de red hacia hub.getdbt.com. Falla si algun valor no nulo
    de la columna cae fuera del rango [min_value, max_value].
#}

with validation as (
    select {{ column_name }} as value_field
    from {{ model }}
    where {{ column_name }} is not null
),

validation_errors as (
    {%- set conditions = [] %}
    {%- if min_value is not none %}
        {%- do conditions.append(
            'value_field < ' ~ min_value if inclusive else 'value_field <= ' ~ min_value
        ) %}
    {%- endif %}
    {%- if max_value is not none %}
        {%- do conditions.append(
            'value_field > ' ~ max_value if inclusive else 'value_field >= ' ~ max_value
        ) %}
    {%- endif %}
    select value_field
    from validation
    where {{ conditions | join(' or ') }}
)

select * from validation_errors

{% endtest %}
