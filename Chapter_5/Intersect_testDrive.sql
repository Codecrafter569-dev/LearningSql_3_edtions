drop table if exists orders;

create table orders(
order_id serial primary key,
customer_id integer not null,
order_month text not null
);
insert into orders(customer_id,order_month) values
(1, 'January'), (2, 'January'), (3, 'January'),
(1, 'February'), (3, 'February'), (4, 'February');

select customer_id from orders where order_month = 'January'
intersect
select customer_id from orders where order_month = 'February';

