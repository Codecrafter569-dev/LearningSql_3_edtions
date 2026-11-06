drop table if exists submarines;
drop table if exists maintenaces_records;
drop table if exists orchid_species;
drop table if exists pollination_events;
drop table if exists vikings;
drop table if exists raids;
drop table if exists researchers;
drop table if exists research_stations;
drop table if exists items_buried;
drop table if exists items_found;

create table vikings(
vikings_id serial primary key,
name text,
rank text
);
create table raids(
raid_id serial primary key,
target_city text,
assigned_viking_id int,
planned_date date
);
create table submarines(
  sub_id serial primary key,
  name text,
  commissioned_year int
);
create table maintenaces_records(
record_id serial primary key,
sub_id int,
service_type text,
serviced_on date
  
);


insert into submarines values
(1, 'USS Phantom Depth', 1998),
(2, 'HMS Silent Shadow', 2003),
(3, 'INS Trident Ghost', 2010),
(4, 'ROKS Dark Waters', 2019); -- brand new, never serviced

insert into maintenaces_records values
(1, 1, 'Torpedo Bay Overhaul', '2025-01-15'),
(2, 2, 'Sonar Calibration', '2025-02-20'),
(3, 1, 'Hull Inspection', '2025-03-10'),
(4, 3, 'Engine Rebuild', '2025-06-01');

select s.name,
s.commissioned_year,
m.service_type,
m.serviced_on from submarines s left join maintenaces_records m on s.sub_id = m.sub_id order by s.name;


select s.name , s.commissioned_year from submarines s left join maintenaces_records m on s.sub_id = m.sub_id where m.record_id is null;


create table orchid_species(
species_id serial primary key,
scientific_name text,
native_region text
);

create table pollination_events(
event_id serial primary key,
species_id int ,
pollinator text,
event_date date
);


insert into orchid_species values
(1, 'Dracula simia', 'Ecuador'),
(2, 'Monkey Face Orchid', 'Colombia'),
(3, 'Ghost Orchid', 'Cuba'),        -- critically endangered, no events
(4, 'Black Bat Flower', 'Thailand');

insert into pollination_events values
(1, 1, 'Hummingbird', '2025-03-01'),
(2, 2, 'Orchid Bee', '2025-04-15'),
(3, 4, 'Hawkmoth', '2025-05-20'),
(4, 1, 'Wind', '2025-06-10');

select 
o.scientific_name , o.native_region, coalesce(p.pollinator,'No event recorded') as pollinator, p.event_date from orchid_species o left join pollination_events p on o.species_id = p.species_id;

insert into vikings values
(1, 'Erik Bloodaxe', 'Jarl'),
(2, 'Bjorn Ironside', 'Warrior'),
(3, 'Sigrid the Bold', 'Shield Maiden');  -- not assigned yet

insert into raids values
(1, 'Lindisfarne', 1, '2026-06-15'),
(2, 'Paris', 2, '2026-08-01'),
(3, 'Constantinople', NULL, '2026-10-20'), -- no viking assigned!
(4, 'Dublin', 1, '2026-11-05');

select 
v.name  as viking, v.rank ,r.target_city as raid_target, r.planned_date from vikings v right join raids r on v.vikings_id = r.assigned_viking_id;


select
v.name as viking,
r.target_city,
r.planned_date from raids r left join vikings v on v.vikings_id = r.assigned_viking_id;

create table researchers(
res_id serial primary key,
name text,
specialty text
);

create table research_stations(
station_id serial primary key,
station_name text,
depth_meters int,
assigned_researcher_id int
);

insert into researchers values
(1, 'Dr. Abyssal', 'Bioluminescence'),
(2, 'Prof. Deeps', 'Hydrothermal Vents'),
(3, 'Dr. Trench', 'Pressure Biology');

insert into research_stations values
(1, 'Mariana Outpost', 11000, 1),
(2, 'Midnight Zone Lab', 4000, 2),
(3, 'Hadal Station Alpha', 9000, NULL), -- unmanned!
(4, 'Abyssal Plain Base', 6000, NULL);  -- unmanned!

select r.name as researcher, r.specialty ,s.station_name,s.depth_meters from researchers r right join research_stations s on r.res_id = s.assigned_researcher_id order by s.depth_meters desc;

CREATE TABLE items_buried (
    item_id SERIAL PRIMARY KEY,
    item_name TEXT,
    buried_by TEXT,
    burial_year INT
);

CREATE TABLE items_found (
    find_id SERIAL PRIMARY KEY,
    item_name TEXT,
    found_by TEXT,
    found_year INT
);

INSERT INTO items_buried VALUES
(1, 'Newspaper clipping', 'Maria', 1985),
(2, 'Vinyl record', 'Tom', 1985),
(3, 'Love letter', 'Anonymous', 1985),
(4, 'Golden coin', 'Elena', 1985);  -- never found

INSERT INTO items_found VALUES
(1, 'Newspaper clipping', 'Jake', 2025),
(2, 'Vinyl record', 'Sarah', 2025),
(3, 'Rusty key',  'Mike', 2025),    -- was never buried (stranger find!)
(4, 'Love letter', 'Anna', 2025);

-- FULL OUTER JOIN: See ALL buried and ALL found
SELECT 
    COALESCE(b.item_name, f.item_name) AS item,
    b.buried_by,
    b.burial_year,
    f.found_by,
    f.found_year,
    CASE
        WHEN b.item_id IS NULL THEN '🔍 Found but never buried!'
        WHEN f.find_id IS NULL THEN '📦 Buried but never found'
        ELSE '✅ Matched!'
    END AS status
FROM items_buried b
FULL OUTER JOIN items_found f ON b.item_name = f.item_name;




create table alien_words(
alien_id serial primary key,
alien_words text,
frequency int
);

create table earch_translations(
trans_id serial primary key,
alien_words text,
english_meaning text,
confidence_pct int
);


insert into alien_words values
(1, 'Zylkra', 95),
(2, 'Vorpax', 42),
(3, 'Thundar', 8),
(4, 'Kreelox', 200); -- most common, untranslated!


insert into earch_translations values
(1, 'Zylkra', 'Greetings', 98),
(2, 'Vorpax', 'Warning', 75),
(3, 'Blornith', 'Unknown entity', 30); -- appears in our records, not transmissions

select coalesce(a.alien_words , t.alien_words) as words,
a.frequency as transmissions_freq ,
t.english_meaning ,
t.confidence_pct,
case 
when t.trans_id is null then 'untranslated'
when a.alien_id is null then ' In our DB , not in transmissions'
else 'Translated !!'
end as transmissions_stuts
from alien_words a full outer join earch_translations t on a.alien_words = t.alien_words order by coalesce(a.frequency,0) desc;

