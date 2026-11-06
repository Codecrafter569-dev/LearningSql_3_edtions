drop table if exists supply_shipments;
drop table if exists earchquake_alerts;
drop table if exists tsunami_alerts;
drop table if exists wildfire_alerts;
drop table if exists extinct_species;
drop table if exists critically_endangered;


create table  supply_shipments(
shipment_id serial primary key,
station_name text,
supply_type text,
quantity_kg numeric,
cost_usd  numeric,
arrived_on date
);

insert into supply_shipments values
(1, 'McMurdo Base', 'Food',       2500, 45000, '2025-01-15'),
(2, 'McMurdo Base', 'Fuel',       8000, 32000, '2025-02-01'),
(3, 'McMurdo Base', 'Medical',    200,  15000, '2025-03-10'),
(4, 'Amundsen-Scott','Food',      1800, 38000, '2025-01-20'),
(5, 'Amundsen-Scott','Fuel',      6000, 24000, '2025-02-15'),
(6, 'Amundsen-Scott','Equipment', 500,  67000, '2025-04-01'),
(7, 'Concordia',    'Food',       900,  20000, '2025-01-30'),
(8, 'Concordia',    'Medical',    150,  12000, '2025-05-01');



select station_name , count(*) as total_shipments,
sum(quantity_kg) as total_kg_recived ,
sum(cost_usd) as total_spent_usd, 
round(avg(cost_usd),2) as avga_shipments_cost,
max(cost_usd) as most_expensive_shipments,
min(arrived_on) as first_delivery,
string_agg(supply_type,',') as supply_types_received from supply_shipments group by station_name order by total_spent_usd desc;

create table earchquake_alerts(
alert_id serial primary key,
location text,
magnitude numeric,
alerted_on timestamp
);

create table tsunami_alerts(
alert_id serial primary key,
coastal_zone text,
wave_height_m numeric,
alerted_on timestamp
);

create table wildfire_alerts(
alert_id serial primary key,
region text,
hectares_at_risk int,
alerted_on timestamp
);

insert into earchquake_alerts values
(1, 'Tokyo Bay', 6.2, '2026-06-01 08:15:00'),
(2, 'San Andreas', 5.8, '2026-06-15 14:30:00');


insert into tsunami_alerts values
(1, 'Pacific Northwest', 12.5, '2026-06-01 08:22:00'),
(2, 'Banda Aceh Coast', 8.0, '2026-06-20 03:45:00');


insert into wildfire_alerts values
(1, 'Sierra Nevada', 50000, '2026-06-10 11:00:00'),
(2, 'Amazon Sector 7', 120000, '2026-06-25 09:30:00');


select 'EARCHQUAKE' as alert_type,
location as location,
alerted_on from earchquake_alerts 

union all 

select 
'TSUNAMI',
coastal_zone,
alerted_on
 from tsunami_alerts
 
 union all 
 
 select 'WILDFIRE',
 region,
 alerted_on
 from wildfire_alerts
 order by alerted_on asc;

CREATE TABLE extinct_species (
    species TEXT,
    last_seen_year INT,
    cause TEXT
);

CREATE TABLE critically_endangered (
    species TEXT,
    population_left INT,
    primary_threat TEXT
);

INSERT INTO extinct_species VALUES
('Dodo Bird', 1681, 'Hunting'),
('Tasmanian Tiger', 1936, 'Hunting & habitat loss'),
('Passenger Pigeon', 1914, 'Mass hunting'),
('Pyrenean Ibex', 2000, 'Genetics collapse');

INSERT INTO critically_endangered VALUES
('Amur Leopard', 100, 'Poaching'),
('Vaquita Porpoise', 10, 'Bycatch'),
('Javan Rhino', 72, 'Habitat loss'),
('Tasmanian Tiger', 0, 'Already extinct?'); -- intentional overlap for UNION demo

-- UNION removes the duplicate Tasmanian Tiger row
SELECT species, 'EXTINCT'              AS status FROM extinct_species
UNION
SELECT species, 'CRITICALLY ENDANGERED' FROM critically_endangered
ORDER BY status, species;

-- UNION ALL keeps both Tasmanian Tiger rows
SELECT species, 'EXTINCT'              AS status FROM extinct_species
UNION ALL
SELECT species, 'CRITICALLY ENDANGERED' FROM critically_endangered
ORDER BY status, species;


