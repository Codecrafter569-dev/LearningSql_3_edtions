DROP TABLE users;
CREATE TABLE users(
id SERIAL PRIMARY KEY,
username  VARCHAR(50) NOT NULL,
password TEXT NOT NULL
);

INSERT INTO users (username,password)
VALUES ('Vikash','9393683129Vikasj2');

SELECT *
FROM users;

DROP TABLE customers;
CREATE TABLE customers(
id SERIAL PRIMARY KEY,
email  VARCHAR(200) UNIQUE NOT NULL,
is_active  BOOLEAN DEFAULT TRUE,
created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO customers(email,is_active)
VALUES
      ('vikash@gmail.com',false),
      ('asiskumar239@gmail.com',true);
      
SELECT * FROM customers;

DROP TABLE products;
CREATE TABLE products(
id SERIAL PRIMARY KEY,
name VARCHAR(50) NOT NULL,
price  NUMERIC(10,3)  CHECK(price > 0),
stock INT DEFAULT 0 CHECK(stock >= 0),
category  VARCHAR(50)
);


   