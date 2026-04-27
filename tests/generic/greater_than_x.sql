{% test greater_than_x(_model, column_name, x) %}

select 
    {{ column_name }} 
from {{ _model }}
where {{ column_name }}  < {{ x }}

{% endtest %}