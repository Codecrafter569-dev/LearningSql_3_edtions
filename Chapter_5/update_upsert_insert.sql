drop table if exists product_inventory;
create table product_inventory(
sku text primary key,
product_name text not null,
stock_quantity integer not null
);

\d product_inventory

insert into product_inventory(sku,product_name,stock_quantity)
values
('SKU-001', 'Wireless Mouse', 50);

insert into product_inventory(sku,product_name,stock_quantity) values
('SKU-001', 'Wireless Mouse', 50)
on conflict(sku) do update set stock_quantity = product_inventory.stock_quantity + excluded.stock_quantity;

select * from product_inventory;
