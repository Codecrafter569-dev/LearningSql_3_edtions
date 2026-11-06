drop table if exists dept_salaries2;

create table dept_salaries2(
emp_name text,
department text,
salary numeric(10,2)
);
insert into dept_salaries2 values
('Alice', 'Eng', 95000),
('Bob',   'Eng', 87000),
('Carla', 'Eng', 110000);

select emp_name,salary,last_value(salary) over(
partition by department order by salary asc ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as highest_in_dept from dept_salaries2;



