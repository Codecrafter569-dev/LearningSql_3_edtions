drop table if exists dept_salaries;
create table dept_salaries(
emp_name text,
department text,
salary numeric(10,2)
);

insert into dept_salaries values
('Alice', 'Eng', 95000),
('Bob',   'Eng', 87000),
('Carla', 'Eng', 110000);

select emp_name,salary , first_value(salary) over (partition by department order by salary ASC) as lowest_in_dept from dept_salaries;

