drop table if exists diary;
drop type if exists mood;
drop table if exists tasks;
drop table if exists stats;
drop table if exists products;
drop table if exists scienticfic_data;
drop table if exists codes;



create type mood as enum('sad','ok','happy');
create table diary(
entry_id serial primary key,
note text,
my_mood mood
);

insert into diary (note,my_mood) values ('Finished PostgresSQL notes','happy');

select * from diary;

create table tasks(
task_id serial primary key,
title text,
is_done boolean
);

insert into tasks (title, is_done) values
('Learn window function',true),
('Learn data types','yes'),
('Sleep early','t');

insert into tasks (title,is_done) values
('Learning network for androids',false),
('Learning cpp data types','no'),
('Sleep is not requare','f');

select * from tasks;

select * from tasks;

create table stats(
small_count smallint,
normal_count integer,
huge_count bigint
);

insert into stats values
(5, 2000000, 9000000000000);

create table products(
product_id serial primary key,
price numeric(10,2)
);

insert into products(price) values (1238585.843);
insert into products(price) values (90383.493);


select * from products;

select * from stats;


create table scienticfic_data(
measurements numeric
);

insert into scienticfic_data values
(3.14159265358979323846264338327950288);
select measurements from scienticfic_data;

create table codes(
country_code char(5)
);

insert into codes values('IN');
select * from codes;
