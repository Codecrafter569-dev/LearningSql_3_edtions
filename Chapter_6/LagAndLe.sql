create table monthly_revenue(
month_start data primary key,
revenue numeric(10,2)
);

insert into monthly_revenue values
('2026-01-01', 10000),
('2026-02-01', 12000),
('2026-03-01', 9000),
('2026-04-01', 15000);
