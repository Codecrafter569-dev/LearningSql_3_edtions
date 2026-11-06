DROP TABLE IF EXISTS employees;


CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) UNIQUE ,
  salary  NUMERIC(10,2),
  hired_at DATE DEFAULT CURRENT_DATE
);

INSERT INTO employees(name,email,salary)
VALUES('Vikash','alice@mail.com',5500.0);

INSERT INTO employees(name,email,salary)
VALUES('Asis','asiskumar@gmail.com',60000.0);

INSERT INTO employees(name,email,salary)
VALUES 
      ('Shahile','shahilekumar@gmail.com',35000.0),
      ('Yash','yashrange@gmail.com',45000.0),
      ('Nafisa','nafisakumari@gmail.com',60500.0),
      ('Bob','bobKumar@gmail.com',46000.0);

SELECT * FROM employees;

SELECT name, salary  
FROM employees;

SELECT name 
FROM employees;

SELECT salary 
FROM employees;

SELECT name , salary 
FROM employees
WHERE salary > 50000;

SELECT name , salary
FROM employees
ORDER BY salary DESC;

SELECT name 
FROM employees LIMIT 3;

SELECT name , salary
FROM employees LIMIT 2;

UPDATE employees
SET salary = 70000.0
WHERE name = 'Vikash';

UPDATE employees
SET salary = 80000.90
WHERE name = 'Bob';

SELECT name , salary  
FROM employees
WHERE salary  > 70000;

SELECT * FROM employees;

SELECT name, salary
FROM employees
WHERE name = 'Bob';

UPDATE employees
SET email = 'bobristerking@gmail.com'
WHERE name = 'Bob';

SELECT name , email 
FROM employees
WHERE name = 'Bob';

DELETE FROM employees
WHERE name = 'Vikash';

--DELETE FROM employees;
DROP TABLE IF EXISTS departments;
CREATE TABLE departments(
id  SERIAL PRIMARY KEY,
name  VARCHAR(100)
);

ALTER TABLE employees
  ADD COLUMN dept_id  INT REFERENCES departments(id);
  
SELECT e.name ,e.salary , d.name AS department
FROM employees e
JOIN departments d ON e.dept_id  = d.id;

INSERT INTO departments(name)
VALUES('RKIASSINDIUOS');

SELECT * FROM employees;


SELECT 
     COUNT(*)   AS total_employees,
     AVG(salary)  AS average_salary,
     MAX(salary)  AS highest_salary,
     MIN(salary) AS lowest_salary,
     SUM(salary) AS total_payroll
FROM employees;

SELECT dept_id , AVG(salary)  AS average_salary
FROM employees
GROUP BY dept_id
HAVING AVG(salary) > 5000;


BEGIN;
UPDATE employees SET salary  = salary + 500 
WHERE name ='Asis';
UPDATE employees SET salary = salary - 500
WHERE name = 'Bob';
COMMIT;