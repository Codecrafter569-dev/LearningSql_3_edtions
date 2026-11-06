drop table if exists orders;

create table orders(
order_id serial primary key,
customer_id int not null,
order_date date not null,
amount numeric(10,2)
);

insert into orders(customer_id,order_date,amount)values
(1, '2026-05-01', 120.00),
(1, '2026-06-15', 340.00),
(1, '2026-06-30', 90.00),
(2, '2026-06-10', 500.00);

select * from (select * , row_number() over (partition by customer_id order by order_date desc) as rn from orders
) t where rn = 1;