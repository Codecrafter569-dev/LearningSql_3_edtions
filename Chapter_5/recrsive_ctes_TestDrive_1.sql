drop table if exists employees;
CREATE TABLE employees (
    employee_id   SERIAL PRIMARY KEY,
    employee_name TEXT NOT NULL,
    manager_id    INTEGER REFERENCES employees(employee_id)
);

INSERT INTO employees (employee_name, manager_id) VALUES
('Nora (CEO)', NULL),
('Liam (VP Sales)', 1),
('Priya (Sales Rep)', 2),
('Tom (Sales Rep)', 2),
('Grace (VP Eng)', 1),
('Sam (Engineer)', 5);

WITH RECURSIVE org_chart AS (
    SELECT employee_id, employee_name, manager_id, 1 AS depth
    FROM employees
    WHERE employee_name = 'Nora (CEO)'

    UNION ALL

    SELECT e.employee_id, e.employee_name, e.manager_id, oc.depth + 1
    FROM employees e
    JOIN org_chart oc ON e.manager_id = oc.employee_id
)
SELECT employee_id, employee_name, depth
FROM org_chart
ORDER BY depth, employee_id;
