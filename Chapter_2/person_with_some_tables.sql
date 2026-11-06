-- Drop if exists (safe re-run)
DROP TABLE IF EXISTS favorite_food;
DROP TABLE IF EXISTS person;
DROP TYPE IF EXISTS eye_color_type;

CREATE TYPE eye_color_type AS ENUM('BR','BL','GR');

-- Create the person table
CREATE TABLE person (
    person_id   SMALLINT GENERATED ALWAYS AS IDENTITY,
    fname       VARCHAR(20)  NOT NULL,
    lname       VARCHAR(20) NOT NULL,
    eye_color   eye_color_type,
    birth_date  DATE NOT NULL,
    street      VARCHAR(30),
    city        VARCHAR(20),
    state       VARCHAR(20),
    country     VARCHAR(20),
    postal_code VARCHAR(20),
    CONSTRAINT pk_person PRIMARY KEY (person_id)
);
--CREATE TABLE fk_fav_food_person_id  FOREIGN KEY(person_id,food),

CREATE TABLE favorite_food(
person_id SMALLINT  NOT NULL,
food  VARCHAR(20)   NOT NULL,
CONSTRAINT pk_favorite_food   PRIMARY KEY (person_id,food),
CONSTRAINT fk_fav_food_person_id  FOREIGN KEY (person_id)
REFERENCES person(person_id)
  
);
  
-- INSERT data
INSERT INTO person (fname, lname, eye_color, birth_date)
VALUES ('William', 'Turner', 'BR', '1972-05-27');

INSERT INTO person (fname, lname, eye_color, birth_date, street, city, state, country, postal_code)
VALUES ('Susan', 'Smith', 'BL', '1975-11-02', '23 Maple St.', 'Arlington', 'VA', 'USA', '20220');

-- View results
INSERT INTO person(fname,lname,eye_color,birth_date)
  VALUES ('James','Holloway','GR','1990-03-26');

INSERT INTO person(fname,lname, eye_color,birth_date,city,country)
  VALUES ('Mariya','Lopez','BR','1985-07-22','Miami','USA');

--RETURNING person_id, fname, lname;
-- This will FAIL intentionally:
INSERT INTO person (fname, lname, eye_color, birth_date)
VALUES ('Bad', 'Person', 'XX', '2000-01-01');

-- ERROR: invalid input value for enum eye_color_type: "XX"
INSERT INTO favorite_food(person_id,food)  
  VALUES(1,'pizza');
INSERT INTO favorite_food(person_id,food)
  VALUES(1,'Cookies');
INSERT INTO favorite_food(person_id,food) 
  VALUES (1,'nachos');

SELECT fname,lname ,birth_date  FROM person;


INSERT INTO favorite_food(person_id,food)
  VALUES(2,'Suchii');

INSERT INTO favorite_food(person_id,food)
  VALUES(2,'tacos');


INSERT INTO favorite_food(person_id,food)
  VALUES (2,'Pasta'),
         (2,'burgers'),
         (3,'tocas'),
         (4,'Nachos'),
         (4,'Tofu');

SELECT food 
FROM favorite_food
WHERE person_id = 1
ORDER BY food;


INSERT INTO favorite_food (person_id, food)
VALUES (1, 'pizza')
ON CONFLICT DO NOTHING;
-- No error, just silently skips if already exists


SELECT p.fname, p.lname , f.food
FROM person p
JOIN favorite_food f ON p.person_id  = f.person_id
ORDER BY p.lname , f.food;


SELECT person_id , fname , lname , birth_date
FROM person
WHERE lname = 'Turner';

SELECT * FROM person WHERE lname ILIKE 'turner';


SELECT  * FROM person WHERE LOWER(lname)  = 'lower';


SELECT person_id , fname, lname, birth_date 
FROM person  
WHERE    birth_date < '1980-01-01'
ORDER BY birth_date ASC;


SELECT  json_agg(
   json_build_object(
      'person_id', person_id,
       'food' , food
  
   )
  
)  AS favorite_food_json
FROM favorite_food;


SELECT query_to_xml(
'SELECT person_id , food FROM favorite_food ORDER BY food',
  false ,
  false,
  ''
  
) AS xml_output;