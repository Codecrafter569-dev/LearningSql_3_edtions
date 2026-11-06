drop table if exists orders;
create table orders(
order_id serial primary key,
customer_id integer not null,
total_amount numeric(10,2) not null,
status text not null default 'pending'
);

insert into orders(customer_id,total_amount,status) values
(1, 120.00, 'pending'),
(2, 45.50, 'pending'),
(3, 80.00, 'pending'),
(1, 75.00, 'shipped');

insert into orders(customer_id,total_amount,status) values
(4,99.9,'pending')
returning order_id,total_amount;

select * from orders;

