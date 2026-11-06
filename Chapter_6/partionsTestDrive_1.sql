drop table if exists emplyee;
create table emplyee(
emp_id serial primary key,
emp_name text not null,
departments text not  null,
salary numeric(10,2) not null
);

insert into emplyee(emp_name,departments,salary)
values ('Alice', 'Engineering', 95000),
('Bob',   'Engineering', 87000),
('Carla', 'Engineering', 110000),
('Dev',   'Sales',       62000),
('Erin',  'Sales',       71000);

select emp_name,departments,salary , row_number() over w as rank_in_dept, avg(salary) over w as dept_avg_salary from emplyee window w as (partition by departments order by salary desc);


