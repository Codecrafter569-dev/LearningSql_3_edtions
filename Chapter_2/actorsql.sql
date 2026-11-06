-- =====================================================
-- CLEANUP
-- =====================================================

DROP VIEW IF EXISTS customer_rentals_vw CASCADE;
DROP VIEW IF EXISTS cust_ws CASCADE;

DROP TABLE IF EXISTS rental CASCADE;
DROP TABLE IF EXISTS film_actor CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS film CASCADE;
DROP TABLE IF EXISTS actor CASCADE;
CREATE TABLE actor(
actor_id SMALLINT GENERATED ALWAYS AS IDENTITY,
first_name  VARCHAR(45) NOT NULL,
last_name  VARCHAR(45) NOT NULL,
PRIMARY KEY(actor_id)
);

CREATE TABLE film(
  film_id  SMALLINT GENERATED ALWAYS AS IDENTITY,
  title  VARCHAR(100)  NOT NULL,
  rating VARCHAR(10),
  rental_duration   SMALLINT,
  PRIMARY KEY(film_id)
);


CREATE TABLE film_actor(
actor_id  SMALLINT NOT NULL REFERENCES actor(actor_id),
film_id  SMALLINT NOT NULL REFERENCES  film(film_id),
PRIMARY KEY(actor_id,film_id)
);


CREATE TABLE customer(
customer_id SMALLINT GENERATED ALWAYS AS IDENTITY,
first_name VARCHAR(45) NOT NULL,
last_name VARCHAR(45)  NOT NULL,
email  VARCHAR(50),
  active  SMALLINT DEFAULT 1,
  
  PRIMARY KEY(customer_id)
);

CREATE TABLE rental(
  rental_id INT GENERATED ALWAYS AS IDENTITY,
  rental_date  TIMESTAMP NOT NULL,
  customer_id  SMALLINT NOT NULL REFERENCES customer(customer_id),
  PRIMARY KEY(rental_id)
);

INSERT INTO actor(first_name,last_name)
VALUES ('PENELOPE','GUINESS'),
    ('NICK','WAHLBERG'),
    ('ED','CHASE'),
    ('JOHNNY','JENKINS'),
    ('BETTE','JOHANSSON'),
    ('GRACE','JOLIE'),
    ('MATTHEW','JONES'),
    ('ANGELA','WITHERSPOON');

INSERT INTO film(title,rating,rental_duration)
VALUES
  ('ACADEMY DINOSAUR','PG',6),
    ('ACE GOLDFINGER','G',3),
    ('BLANKET BEVERLY','G',7),
    ('BORROWERS BEDAZZLED','G',8),
    ('BRIDE INTRIGUE','G',7),
    ('AGENT TRUMAN','PG',4),
    ('AIRPLANE SIERRA','PG-13',3),
    ('ALAMO VIDEOTAPE','G',6);


INSERT INTO film_actor(actor_id,film_id)
VALUES (1,1),(1,2),(1,3),
    (2,1),(2,4),
    (3,2),(3,5),
    (4,6),
    (5,6),(5,7);

INSERT INTO customer(first_name,last_name,email,active)
VALUES    ('MARY','SMITH','mary.smith@example.com',1),
    ('PATRICIA','JOHNSON','patricia.johnson@example.com',1),
    ('JESSIE','BANKS','jessie.banks@example.com',1),
    ('SANDRA','MARTIN','sandra.martin@example.com',0),
    ('JEFFERY','PINSON','jeffery.pinson@example.com',1),
    ('DANIEL','CABRAL','daniel.cabral@example.com',1),
    ('CATHERINE','CAMPBELL','catherine.campbell@example.com',1);

INSERT INTO rental(rental_date,customer_id)
VALUES
   ('2005-06-14 22:53:33', 5),  -- JEFFERY PINSON
    ('2005-06-14 23:09:38', 6),  -- DANIEL CABRAL
    ('2005-06-14 21:30:00', 7),  -- CATHERINE CAMPBELL
    ('2005-06-13 10:00:00', 1);  -- different date, should NOT appear


SELECT actor_id FROM film_actor ORDER BY actor_id;

SELECT DISTINCT actor_id FROM film_actor ORDER BY actor_id;

SELECT DISTINCT actor_id , film_id FROM film_actor;

SELECT DISTINCT actor_id FROM film_actor;

SELECT concat(cust.last_name,',',cust.first_name) AS full_name
FROM (SELECT first_name, last_name , email
FROM customer
WHERE first_name = 'JESSIE'
  )cust;

SELECT c.first_name , c.last_name , rc.rental_count
FROM customer c
INNER JOIN 
(SELECT customer_id , COUNT(*) AS rental_count
  FROM rental
  GROUP BY customer_id) rc
ON c.customer_id = rc.customer_id
ORDER BY rc.rental_count DESC;

SELECT cust.last_name || ','|| cust.first_name AS full_name 
FROM (SELECT first_name,last_name FROM customer WHERE first_name = 'JESSIE') cust;


CREATE TEMPORARY TABLE actors_j(
  actor_id SMALLINT,
  first_name VARCHAR(45),
  last_name VARCHAR(45)
);

INSERT INTO actors_j 
SELECT actor_id , first_name , last_name
FROM actor 
WHERE  last_name LIKE 'J%';

SELECT * FROM actors_j;

BEGIN;
CREATE TEMPORARY TABLE actor_j_session
ON COMMIT DROP AS SELECT actor_id , first_name , last_name
FROM actor WHERE last_name LIKE 'J%';

SELECT * FROM actor_j_session;

COMMIT;


CREATE VIEW cust_ws AS 
SELECT customer_id , first_name , last_name , active
FROM customer;

SELECT first_name , last_name
FROM cust_ws 
WHERE active  = 0;



CREATE VIEW customer_rentals_vw AS SELECT c.customer_id, c.first_name , c.last_name , r.rental_date
FROM customer c 
INNER JOIN rental r ON c.customer_id = r.customer_id;



SELECT first_name , last_name , rental_date
FROM customer_rentals_vw 
WHERE rental_date  >= '2005-06-14'
ORDER BY rental_date;

SELECT customer.first_name , customer.last_name , rental.rental_date::time AS rental_time
FROM customer
INNER JOIN rental 
ON customer.customer_id  = rental.customer_id
WHERE rental.rental_date::date = '2005-06-14';

SELECT customer.first_name,customer.last_name,
EXTRACT(HOUR FROM rental.rental_date) AS rental_hour,
date_trunc('day',rental.rental_date) AS rental_day
FROM customer
INNER JOIN rental
ON customer.customer_id = rental.customer_id
WHERE date_trunc('day',rental.rental_date) = '2005-06-14';




SELECT rental_date::time AS rental_time,
       rental_date::time AS rental_day
FROM rental;



SELECT c.first_name , c.last_name,
r.rental_date::time AS rental_time
FROM customer AS c
INNER JOIN rental AS r
ON c.customer_id = r.customer_id
WHERE r.rental_date::date = '2005-06-14';

SELECT c.first_name AS "First Name",
c.last_name AS "Last_Name",
r.rental_date::time AS "Rental Time"
FROM customer AS c
INNER JOIN rental AS r
ON c.customer_id = r.customer_id
WHERE r.rental_date::date = '2005-06-14';



SELECT c.first_name , c.last_name
FROM customer c
INNER JOIN rental r ON c.customer_id = r.customer_id;


SELECT title
FROM film 
WHERE rating = 'G' AND rental_duration >= 7;


SELECT title
FROM film
WHERE rating = 'G' OR rental_duration >= 7;


SELECT title
FROM film 
WHERE (rating = 'G' AND rental_duration >= 7) OR (rating = 'PG-13' AND rental_duration  < 4 );



INSERT INTO rental(rental_date,customer_id)
VALUES 
      ('2005-06-15 09:00:00', 5),
    ('2005-06-16 14:00:00', 5);

SELECT c.first_name , c.last_name , count(*) AS rental_count
FROM customer c
INNER JOIN rental r
ON c.customer_id = r.customer_id
GROUP BY c.first_name , c.last_name
ORDER BY rental_count DESC;


SELECT c.first_name , c.last_name , count(*) AS rental_count
FROM customer c
INNER JOIN rental r
ON c.customer_id = r.customer_id
GROUP BY c.first_name , c.last_name
HAVING count(*) >= 2;

SELECT c.first_name, c.last_name, count(*) 
FROM customer c
  INNER JOIN rental r ON c.customer_id = r.customer_id
WHERE c.active = 1                    -- row-level filter
GROUP BY c.first_name, c.last_name
HAVING count(*) >= 2;                 -- group-level filter


SELECT c.first_name, c.last_name,
       r.rental_date::time AS rental_time
FROM customer c
  INNER JOIN rental r
  ON c.customer_id = r.customer_id
WHERE r.rental_date::date = '2005-06-14'
ORDER BY c.last_name;


-- Add a customer with same last_name to show multi-column sort
INSERT INTO customer (first_name, last_name, email, active) VALUES
    ('AARON', 'CABRAL', 'aaron.cabral@example.com', 1);

INSERT INTO rental (rental_date, customer_id) VALUES
    ('2005-06-14 20:00:00', 8);  -- AARON CABRAL, customer_id=8

SELECT c.first_name, c.last_name,
       r.rental_date::time AS rental_time
FROM customer c
  INNER JOIN rental r
  ON c.customer_id = r.customer_id
WHERE r.rental_date::date = '2005-06-14'
ORDER BY c.last_name, c.first_name DESC;

SELECT first_name, last_name FROM customer ORDER BY last_name;

