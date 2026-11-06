DROP TABLE IF EXISTS employees;
DROP DOMAIN IF EXISTS email_address CASCADE;

CREATE DOMAIN email_address AS TEXT
CHECK (
    VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
);

CREATE TABLE employees (
    id INTEGER PRIMARY KEY,
    full_name TEXT NOT NULL,
    email email_address NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    department VARCHAR(30),
    salary NUMERIC(10,2) NOT NULL,
    tenure_years REAL,
    hired_on DATE DEFAULT CURRENT_DATE,
    last_login TIMESTAMPTZ
);

-- =====================================================
-- Sample Data
-- =====================================================

INSERT INTO employees (
    id,
    full_name,
    email,
    department,
    salary,
    tenure_years,
    hired_on,
    last_login
)
VALUES
(
    1,
    'Ada Lovelace',
    'ada@example.com',
    'Engineering',
    95000.50,
    3.5,
    '2022-11-01',
    NOW()
),
(
    2,
    'Alan Turing',
    'alan@example.com',
    'Research',
    88000.00,
    5.2,
    '2021-03-15',
    NOW() - INTERVAL '2 days'
),
(
    3,
    'Grace Hopper',
    'grace@example.com',
    'Engineering',
    102000.75,
    8.0,
    '2018-06-20',
    NULL
);

select * from employees;

select * from employees where upper(full_name) like 'A%';

select * from employees where is_active = true;

select * from employees where is_active = false;

select sum(salary) as total_payroll from employees;

select full_name , to_char(hired_on,'dd-mm-yyyy') as hired_on from employees;


select full_name , last_login as login_with_timezone,
last_login::timestamp as login_with_timezone from employees;

SET TIME ZONE 'Europe/Paris';

SELECT
    full_name,
    last_login
FROM employees;


