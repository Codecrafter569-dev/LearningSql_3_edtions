DROP TABLE IF EXISTS languages;
DROP TABLE IF EXISTS customer;
CREATE TABLE languages(
language_id  SMALLINT PRIMARY KEY,
langu_name  CHAR(20) NOT NULL,
last_update  TIMESTAMP NOT NULL DEFAULT now()
);

INSERT INTO languages(language_id,langu_name)
VALUES 
 (1, 'English'),
 (2, 'Italian'),
 (3, 'Japanese'),
 (4, 'Mandarin'),
 (5, 'French'),
 (6, 'German'),
  (7,'.....Hindi....');

CREATE TABLE customer(
customer_id  SERIAL PRIMARY KEY,
  first_name VARCHAR(20) NOT NULL,
  last_name VARCHAR(20) NOT NULL
);

INSERT INTO customer(first_name,last_name)
VALUES  ('Mary', 'Smith'),
 ('Patricia', 'Johnson'),
 ('Linda', 'Williams');


SELECT first_name , last_name 
FROM customer 
WHERE last_name = 'Zibrelin';

SELECT first_name , last_name
FROM customer 
WHERE last_name = 'Smith';

SELECT 1+1 AS sum_result;


SELECT * FROM languages;

SELECT * FROM customer;

INSERT INTO customer(first_name,last_name)
VALUES ('John','Smith'),
('Anne','Smith');

SELECT last_name , count(*) AS num_customers
FROM customer
WHERE last_name = 'Smith'
GROUP BY last_name
HAVING count(*) > 1
ORDER BY last_name;

SELECT * FROM customer;

SELECT langu_name FROM languages;

SELECT language_id,
 'COMMON' AS languages_usages,
  language_id * 3.1415927 AS lang_pi_value,
 upper(langu_name) AS language_name
FROM languages;


SELECT language_id,
       'COMMON',
       language_id * 3.1415927,
       upper(langu_name)
FROM languages;


SELECT language_id,
 'COMMON' AS languages_usages,
  language_id * 3.1415927 AS lang_pi_value,
 upper(langu_name) AS language_name
FROM languages
WHERE language_id < 3;


SELECT version(),
       current_user,
       current_database();


SHOW server_version;
SELECT current_setting('server_version') AS server_version,
       session_user,
       current_database();


