drop table if exists orders;
create table orders(
order_id serial primary key,
user_id integer,
amount numeric(10,2),
order_date date
);

insert into orders(user_id , amount,order_date) values
(1, 500, '2024-01-05'),
(1, 700, '2024-01-10'),
(2, 700, '2024-01-15'),
(2, 300, '2024-01-03'),
(3, 900, '2024-01-08'),
(3, 450, '2024-01-02'),
(4, 450, '2024-01-12'),
(4, 600, '2024-01-20');

select * from orders;

select user_id , order_id, amount , sum(amount) over (partition by user_id) as user_total from orders;

select user_id , amount , sum(amount) over w as total,
avg(amount) over w as avg_amt
from orders window w as (partition by user_id);

select user_id , amount , order_date , row_number() over (partition by user_id order by amount desc) as rn  from orders;

select user_id , order_date , amount , sum(amount) over (partition by user_id order by order_date) as running_total from orders;

select user_id , order_date , amount , first_value(amount) over (partition by user_id order by order_date) as first_orders_amt from orders;


select user_id , order_date , amount , last_value(amount) over( partition by user_id order by order_date rows between unbounded preceding and unbounded following)
as last_order_amt from orders;

select user_id , amount , order_date , rank() over(partition by user_id order by amount desc) as rnk from orders where user_id = 3;

select user_id , amount , order_date , dense_rank() over (partition by user_id order by amount desc) as rnk from orders where user_id > 1;


select user_id , amount , order_date , lag(amount ,1) over (partition by user_id order by order_date) as prev_amount,
lead(amount , 1) over (partition by user_id order by order_date) as next_amount from orders;

select user_id , amount , order_date , cume_dist() over (partition by user_id order by amount) as cume_dists from orders where user_id = 3;


select user_id , amount , ntile(2) over (order by amount desc) as helf from orders;

select user_id , amount , order_date , avg(amount) over (
partition by user_id order by order_date rows between 1 preceding and 1 following ) as moving_avg  from orders;


select user_id , amount , sum(amount) over (
partition by user_id order by amount range between current row and current row ) as sum_of_tied_peer from orders where user_id = 3;