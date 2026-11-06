CREATE SCHEMA IF NOT EXISTS shop;
SET search_path TO shop, public;

-- =========================
-- Drop old objects
-- =========================

DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS products_audit CASCADE;
DROP TABLE IF EXISTS statement_log CASCADE;

-- =========================
-- Tables
-- =========================

CREATE TABLE products (
    product_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    stock_qty INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE products_audit (
    audit_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id INT,
    action TEXT,
    old_data JSONB,
    new_data JSONB,
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE statement_log (
    log_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name TEXT,
    operation TEXT,
    logged_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- =========================
-- Validation Trigger Function
-- =========================

CREATE OR REPLACE FUNCTION trg_validate_products()
RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.price <= 0 THEN
        RAISE EXCEPTION 'Price must be positive. Got %', NEW.price;
    END IF;

    IF NEW.stock_qty < 0 THEN
        RAISE EXCEPTION 'Stock quantity cannot be negative.';
    END IF;

    NEW.updated_at := NOW();

    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER a_validate_product
BEFORE INSERT OR UPDATE
ON products
FOR EACH ROW
EXECUTE FUNCTION trg_validate_products();

-- =========================
-- Audit Trigger Function
-- =========================

CREATE OR REPLACE FUNCTION trg_audit_products()
RETURNS TRIGGER AS
$$
BEGIN
    IF TG_OP = 'INSERT' THEN

        INSERT INTO products_audit(product_id, action, new_data)
        VALUES (NEW.product_id, TG_OP, to_jsonb(NEW));

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        INSERT INTO products_audit(product_id, action, old_data, new_data)
        VALUES (NEW.product_id, TG_OP, to_jsonb(OLD), to_jsonb(NEW));

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO products_audit(product_id, action, old_data)
        VALUES (OLD.product_id, TG_OP, to_jsonb(OLD));

        RETURN OLD;

    END IF;

    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER b_audit_product
AFTER INSERT OR UPDATE OR DELETE
ON products
FOR EACH ROW
EXECUTE FUNCTION trg_audit_products();

-- =========================
-- Statement Trigger Function
-- =========================

CREATE OR REPLACE FUNCTION trg_log_statement()
RETURNS TRIGGER AS
$$
BEGIN
    INSERT INTO statement_log(table_name, operation)
    VALUES (TG_TABLE_NAME, TG_OP);

    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER c_log_statement
AFTER INSERT OR UPDATE OR DELETE
ON products
FOR EACH STATEMENT
EXECUTE FUNCTION trg_log_statement();

-- =========================
-- Event Trigger
-- (Requires Superuser)
-- =========================

CREATE OR REPLACE FUNCTION shop.f_protect_audit()
RETURNS EVENT_TRIGGER AS
$$
DECLARE
    obj RECORD;
BEGIN
    FOR obj IN
        SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        IF obj.schema_name = 'shop'
           AND obj.object_name = 'products_audit' THEN

            RAISE EXCEPTION
            'products_audit is protected and cannot be dropped';

        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql;

CREATE EVENT TRIGGER tr_protect_audit
ON sql_drop
EXECUTE FUNCTION shop.f_protect_audit();

-- =========================
-- Test Data
-- =========================

INSERT INTO products(name, price, stock_qty)
VALUES ('Keyboard', 25.00, 100);

UPDATE products
SET stock_qty = 90
WHERE name = 'Keyboard';

INSERT INTO products(name, price, stock_qty)
VALUES
('Mouse',15.00,200),
('Monitor',120.00,30),
('Webcam',45.00,50);

DELETE FROM products
WHERE name='Webcam';

-- This will fail
-- INSERT INTO products(name, price, stock_qty)
-- VALUES ('Broken', -5, 10);

-- =========================
-- Results
-- =========================

SELECT * FROM products;

SELECT * FROM products_audit
ORDER BY audit_id;

SELECT * FROM statement_log
ORDER BY log_id;