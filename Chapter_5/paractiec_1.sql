drop table if exists astronauts;
drop table if exists missions;
drop table if exists mushroom_vartieties;
drop table if exists harvest_logs;
drop table if exists buildings;
drop table if exists peranormal_reports;
drop table if exists scrolls;
drop table if exists borrowings;

create table astronauts(
  id serial primary key,
  name text,
  country text
);
create table missions(
  id serial primary key,
  mission_name text,
  astronaut_id int ,
  launch_year int
);

insert into astronauts values
(1, 'Yuki Tanaka', 'Japan'),
(2, 'Carlos Reyes', 'Mexico'),
(3, 'Priya Nair', 'India'),
(4, 'Jonas Berg', 'Sweden'); -- no mission yet

insert into missions values
(1, 'Lunar Gateway Alpha', 1, 2025),
(2, 'Mars Probe X', 2, 2026),
(3, 'Deep Space 9', 3, 2027);

select a.name , a.country , m.mission_name , m.launch_year from astronauts a inner join missions m on a.id = m.astronaut_id;



create table mushroom_vartieties(
  variety_id serial primary key,
  name text,
  flavor_profile text
);

create table harvest_logs(
  log_id serial primary key,
  variety_id int ,
  harvest_date date,
  kg_harvested numeric
);

insert into mushroom_vartieties values
(1, 'Lion''s Mane', 'Seafood-like'),
(2, 'Chaga', 'Earthy bitter'),
(3, 'Ghost Oyster', 'Mild umami'),
(4, 'Enoki', 'Crunchy delicate'); -- never harvested


insert into harvest_logs values
(1, 1, '2026-01-10', 12.5),
(2, 2, '2026-01-15', 8.0),
(3, 1, '2026-02-01', 15.0),
(4, 3, '2026-02-10', 6.5);

select v.name , v.flavor_profile , h.harvest_date , h.kg_harvested from mushroom_vartieties v inner join harvest_logs h on v.variety_id = h.variety_id order by h.harvest_date;


create table buildings(
  building_id serial primary key,
  address text,
  built_year int
);

create table peranormal_reports(
  report_id serial primary key,
  building_id int,
  incident text,
  reported_on date
);

insert into buildings values
(1, '13 Hollow Lane', 1889),
(2, '7 Sunset Blvd', 1923),
(3, '99 Maple Street', 2001), -- no reports
(4, '666 Darkwood Ave', 1756);


insert into peranormal_reports values
(1, 1, 'Floating candles', '2025-10-31'),
(2, 4, 'Whispering walls', '2025-11-01'),
(3, 1, 'Cold spots', '2025-11-15'),
(4, 2, 'Shadow figure', '2025-12-01');



select b.address , p.incident from buildings b inner join peranormal_reports p on b.building_id = p.building_id;


select b.address , b.built_year from buildings b where
exists(
select 1 from peranormal_reports p where p.building_id = b.building_id
);


select address , built_year from buildings where building_id in(
  select building_id from peranormal_reports
);

create table scrolls(
  scroll_id serial primary key,
  title text,
  author text
);

create table borrowings(
id serial primary key,
scroll_id int,
scholar_name text,
  borrowed_on date
  
);




insert into scrolls values
(1, 'The Art of War', 'Sun Tzu'),
(2, 'Meditations', 'Marcus Aurelius'),
(3, 'The Untouched Papyrus', 'Unknown'); -- never borrowed


insert into borrowings values
(1, 1, 'Emperor Qin', '2025-01-01'),
(2, 2, 'Napoleon', '2025-03-15'),
(3, 1, 'Cleopatra', '2025-05-20');

select s.title , s.author from scrolls s where exists (

select 1 from borrowings b where b.scroll_id = s.scroll_id
  
);
select s.title , b.scholar_name , b.borrowed_on from scrolls s inner join borrowings b on s.scroll_id = b.scroll_id;


