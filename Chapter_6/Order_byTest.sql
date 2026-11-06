drop table if exists daily_sales;

create table daily_sales(
sale_date date primary key,
revernue numeric(10,2)
);
insert into daily_sales values 
('2026-07-01', 1000),
('2026-07-02', 1500),
('2026-07-03', 800);
select sale_date,revernue,sum(revernue) over (order by sale_date) as running_total from daily_sales;


