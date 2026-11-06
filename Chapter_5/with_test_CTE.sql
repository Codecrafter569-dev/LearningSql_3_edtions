drop table if exists orders;

create table orders(
orders_id serial primary key,
customer_id integer not null,
total_amount numeric(10,2) not null,
status text not null default 'pending'
);


insert into orders(customer_id,total_amount,status) values
(1, 120.00, 'pending'),
(2, 45.50, 'pending'),
(3, 80.00, 'pending'),
(1, 75.00, 'shipped');

with high_value_orders as (
select * from orders where total_amount > 100
)
select * from high_value_orders;

with low_value_orders as(
select * from orders where total_amount < 50
)
select * from low_value_orders;