drop table if exists product_inventory;
drop table if exists incoming_shipments;

create table  product_inventory(
sku text primary key,
product_name text not null,
stock_quantity integer not null
);

insert into product_inventory values
('SKU-001', 'Wireless Mouse', 100),
('SKU-002', 'USB-C Cable', 200);

create table incoming_shipments(
sku text primary key,
product_name text not null,
quantity_received integer not null
);
insert into incoming_shipments values
('SKU-001', 'Wireless Mouse', 30),
('SKU-003', 'Keyboard', 75);

select * from incoming_shipments;
select * from product_inventory;


merge into product_inventory as target
using incoming_shipments as source
on target.sku = source.sku
when matched then
update set stock_quantity = target.stock_quantity + source.quantity_received
when not matched then
insert (sku,product_name,stock_quantity)
values(source.sku,source.product_name,source.quantity_received);


select * from product_inventory order by sku;



