drop table if exists orders;

create table orders(
order_id serial primary key,
customer_id integer not null,
total_amount numeric(10,2) not null,
status text not null default 'pending'
);

insert into orders(customer_id,total_amount,status)
values
(1, 120.00, 'pending'),
(2, 45.50, 'pending'),
(3, 80.00, 'pending'),
(1, 75.00, 'shipped');


with customer_totals as (
  select customer_id , sum(total_amount) as total_spent
  from orders 
  group by customer_id
)

select customer_id , total_spent
from customer_totals 
where total_spent > 100
order by total_spent desc;

