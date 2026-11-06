drop table if exists new_posts , posts , new_tags , users,
categories cascade;

create table categories(
pk int primary key,
title varchar(50) not null,
descriptions text
);
insert into categories(pk,title,descriptions) values
(4,'A.I','Machine learning disscussions');

create table users(
pk int primary key,
username varchar(50) not null,
gecos varchar(50),
email varchar(100) not null
);

insert into users(pk,username,gecos, email) values
(1,'luca_ferrari','','luca@pgtrainging.com'),
(2,'enrico_porozzi','','enrico@pgtrainging.com'),
(3,'newuers','','newuers@pgtrainging.com');


create table posts(
pk int primary key,
title text not null,
created_on timestamp with time zone default current_timestamp
);

insert into posts(pk,title,created_on) values
(5, 'Indexing PostgreSQL',           '2023-01-23 15:21:55.747463+00'),
    (6, 'Indexing Mysql',                '2023-01-23 15:22:02.38953+00'),
    (7, 'A view of Data types in C++',   '2023-01-23 15:26:21.367814+00');



select * from categories where upper(title) like 'A%';
alter table users add column user_on_line boolean;
update users set user_on_line = true where pk = 1;

\x


select * from users where user_on_line  = true;
select * from users where user_on_line is null;
\x


select 1.123456789::integer as my_field;
select 1.123456789::int4 as my_field;
select 1.123456789::bigint as my_field;
select  1.123456789::int8 as my_field;
select 1.123456789::real as my_field;
select 1.123456789::double precision as my_field;
select sum(0.1::real) from generate_series(1,10);
select 1.123456789::numeric(10,1) as my_field;
select 1.123456789::numeric(10,5) as my_field;
select 1.123456789::numeric(10,9) as my_field;
select 0.123456789::numeric(10,10) as my_field;
select sum(0.1::numeric(2,2)) from generate_series(1,10);


create table new_tags(
pk integer not null primary key,
tag char(10)
);
insert into new_tags values(1,'first tag');
insert into new_tags values(2,'tag');
\x
select pk,tag , length(tag) , octet_length(tag), char_length(tag) from new_tags;
\x
drop table new_tags;

create table new_tags(
pk integer not null primary key,
tag varchar(10)
);
insert into new_tags values(1,'first tag');
insert into new_tags values(2,'tag');

select pk , tag , length(tag) , octet_length(tag) from new_tags;

drop table new_tags;

create table new_tags(
pk integer not null primary key,
tag text
);
insert into new_tags values
(1,'first tag'),
(2,'tag'),
(3, 'this sentence has more than 10 characters');


select pk , substring(tag from 0 for 20) , length(tag),octet_length(tag) from new_tags;

\x
SELECT * FROM pg_settings WHERE name = 'DateStyle';
\x
select '12-31-2020'::date;
select to_date('31/12/2020','dd/mm/yyyy');

\x
select pk , title , created_on from posts;
\x
select pk , title , to_char(created_on , 'dd-mm-yyyy') as created_on from posts;

create table new_posts as 
select pk , title , created_on::timestamp with time zone as created_on_t, created_on::timestamp without time zone as created_on_nt from posts;

\d new_posts

select * from new_posts;

show timezone;
set timezone = 'CET'
show timezone;

select * from new_posts;









