with recursive countdown as (
select 20 as current_number

union all
select current_number - 1
from countdown
where current_number > 1
)

select current_number from countdown;