DROP TABLE IF EXISTS marks;
DROP TABLE IF EXISTS students;
CREATE TABLE students(
  student_id   SERIAL PRIMARY KEY,
  first_name  VARCHAR(20) NOT NULL,
  last_name VARCHAR(30) NOT NULL,
  eye_color CHAR(2) CHECK ( eye_color IN ('BR','BL','GR')),
  age  int NOT NULL,
  class  CHAR(20) NOT NULL,
  roll_no  int NOT NULL
);


CREATE TABLE marks(
student_id  INT NOT NULL,
subject VARCHAR(20) NOT NULL,
score INT NOT NULL,
PRIMARY KEY(student_id,subject),
FOREIGN KEY(student_id) REFERENCES students(student_id)
);


INSERT INTO students(first_name,last_name,eye_color,age,class,roll_no)
VALUES ('Vikash','Kumar','BR','16','XI','66'),
       ('Alok','Kumar','BR','16','XI(ARTS)','1'),
       ('Anmol','Kumar','GR','15','XI(SCIE)','23');


SELECT * FROM students;

UPDATE students
SET eye_color = 'BL'
WHERE first_name = 'Vikash';

UPDATE students
SET roll_no  = 12
WHERE first_name = 'Alok';

SELECT roll_no FROM students
WHERE first_name = 'Alok';

UPDATE students
SET age = '17'
WHERE first_name = 'Vikash';

DELETE FROM students
WHERE first_name = 'Anmol';

SELECT * FROM students;

INSERT INTO students(first_name,last_name,eye_color,age,class,roll_no)
  VALUES('Nandni','Kumari','GR','16','XL','65');


SELECT * FROM students;
INSERT INTO marks(student_id,subject,score)
VALUES (4,'Math','76'),
        (4,'Physics','66');

SELECT * FROM marks;

DELETE FROM students
WHERE first_name = 'Nandni';

DELETE FROM marks
WHERE student_id = 4;
DELETE FROM students
WHERE first_name = 'Nandni';

INSERT INTO students(student_id,first_name,last_name,eye_color,age,class,roll_no)
VALUES(1,'Rohit','Kumar','GR','16','XII','78');

