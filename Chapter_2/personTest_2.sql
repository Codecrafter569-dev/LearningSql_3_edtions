DROP TABLE IF EXISTS favorite_food;
DROP TABLE IF EXISTS person;
CREATE TABLE person (
    person_id SERIAL PRIMARY KEY,
    fname VARCHAR(20),
    lname VARCHAR(20),
    eye_color CHAR(2) CHECK (eye_color IN ('BR','BL','GR')),
    birth_date DATE,
    street VARCHAR(30),
    city VARCHAR(20),
    state VARCHAR(20),
    country VARCHAR(20),
    postal_code VARCHAR(10)
);

CREATE TABLE favorite_food (
    person_id INTEGER NOT NULL,
    food VARCHAR(20) NOT NULL,
    PRIMARY KEY (person_id, food),
    CONSTRAINT fk_fav_food_person_id
        FOREIGN KEY (person_id)
        REFERENCES person(person_id)
);

INSERT INTO person(fname,lname,eye_color,birth_date)
VALUES ('William','Turner','BR','1972-05-27');

INSERT INTO person(person_id,fname,lname,eye_color,birth_date)
VALUES (2,'Vikash','Kumar','BL','2011-05-29');

INSERT INTO favorite_food(person_id,food) VALUES(1,'pizza');
INSERT INTO favorite_food(person_id,food)
VALUES(2,'cookies');
INSERT INTO favorite_food(person_id,food)
VALUES(2,'pasta');

SELECT * FROM person;
SELECT * FROM favorite_food;


UPDATE person
SET street  = '1225 Tremont St.',
city  = 'Boston',
state  = 'MA',
country  ='USA',
postal_code  = '02138'
WHERE person_id  = 1;

INSERT INTO person(person_id,fname,lname,eye_color,birth_date)
VALUES (3,'ALICE','Cooper','GR','1990-03-14');

UPDATE person
SET country = 'India'
WHERE person_id < 10;

SELECT * FROM person;
DELETE FROM favorite_food
  WHERE person_id = 2;


DELETE FROM person
WHERE person_id = 2;
SELECT * FROM person;

INSERT INTO person(person_id,fname,lname,eye_color,birth_date)
VALUES (1,'Charli','Fulton','GR','1968-01-20');

INSERT INTO 
favorite_food(person_id,food) VALUES (3,'tacos');
INSERT INTO 
favorite_food(person_id,food) VALUES(3,'tacos');

INSERT INTO favorite_food(person_id,food)
VALUES (3,'tacos')
ON CONFLICT DO NOTHING;

SELECT * FROM person;

INSERT INTO person(fname,lname,eye_color,birth_date)
VALUES ('Alok','Kumar','BR','2010-12-20');

INSERT INTO favorite_food(person_id,food)
VALUES(2,'Pizza..');

UPDATE person
SET eye_color = 'ZZ' 
WHERE person_id = 1;

INSERT INTO person(fname,lname,eye_color,birth_date)
VALUES ('Anmol','Kumar','XX','2012-04-12');

INSERT INTO person(fname,lname,eye_color,birth_date)
VALUES ('Anmol','Kumar','BR','2012-04-12');


UPDATE person
SET birth_date = '21/12/1980'
WHERE person_id = 1;


UPDATE person
SET birth_date = to_date('12/12/1980','DD/MM/YYYY')
WHERE person_id = 2;


SELECT person_id , birth_date FROM person;


UPDATE person
SET birth_date = to_date('DEC-MON-1930','MON-DY-YYYY')
WHERE  person_id = 1;

SELECT column_name,data_type, character_maximum_length,is_nullable
FROM information_schema.columns
WHERE table_name = 'person';

DROP TABLE favorite_food;
DROP TABLE person;