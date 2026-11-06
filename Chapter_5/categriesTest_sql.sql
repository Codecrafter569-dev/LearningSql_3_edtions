drop table if exists posts;
drop table if exists users1;
drop table if exists categories1;
drop table if exists posts_archive;
create table categories1(
  pk SERIAL PRIMARY KEY,
  title VARCHAR(100),
  descriptions text
);
\d categories1
create table users1(
pk serial primary key,
username VARCHAR(50),
email VARCHAR(100),
age int,
score int,
joined_date date
);


\d users1

create table posts(
pk serial primary key,
title varchar(200),
content text,
author int references users1(pk),
category int references categories1(pk),
creted_at timestamp,
views int
);

insert into categories1(title,descriptions)
values ('Database','Database related discussions'),
      ('Unix','Unix and linx discussions'),
      ('Programming Language','All about programming language'),
      ('new Category',null),
      ('Database','Duplicate lowercase title');


insert into users1(username,email,age,score,joined_date)
values('alice','alice@gmail.com',28,940,'2022-01-17'),
      ('bob','bob@gmail.com',22,800,'2021-06-20'),
      ('carol','carol@gmail.com',40,100,'2026-03-12'),
      ('dave',null,30,100,'2025-04-11'),
      ('eve','eve@gmail.com',22,440,'2023-04-23');

insert into posts(title,content,author,category,creted_at,views)
values('Intro to SQL',      'Learn SQL basics',      1, 1, '2024-01-10 09:00', 500),
  ('Linux Tips',        'Useful Linux commands', 2, 2, '2024-02-14 12:00', 320),
  ('Python Guide',      'Python for beginners',  3, 3, '2024-03-05 08:30', 810),
  ('Advanced Postgres', 'Deep dive into PG',     1, 1, '2024-04-22 15:00', 120),
  ('Bash Scripting',    'Automate with bash',    2, 2, '2024-05-01 10:00', 640);


select username , age from users1 where age > 28;

select title , views from posts where views < 500;
select username , joined_date from users1 where joined_date >= '2022-01-01';

select username , score from users1 where score <> 950;

select username , age , score from users1 where age > 25 and score >= 700;

select username , score from users1 where score > 500;
select title , views from posts where  views <= 320;

select username , joined_date from users1 where joined_date < '2022-01-01';

select * from categories1 where pk > 3;
select title,creted_at,views from posts where creted_at > '2024-03-01' and views > 300;

select title from categories1 where title like 'Pro%';
select title from categories1 where title like '%Language';
select title,descriptions from categories1 where descriptions like '%discuss%';

select username from users1 where username like '___';
select username , email from users1 where email like '%@mail.com%';

select title,descriptions from categories1 where title ilike 'database';
select title,descriptions from categories1 where descriptions ilike '%discuss%';

select title from posts where title ilike '%sql%';

select title from categories1 where title like 'database';

select title from categories1 where title ilike 'database';

select username from users1 where username ilike '%a%';


select upper('hello');
select lower('WorlD');
select length('PostgresSql');
select trim('  too many spaces  ');
select reverse('abcdef');
select left('PostgresSql',4);

select 10 * 5;
select sqrt(144);
select round(3.1459,2);
select abs(-99);

select now();
select current_date;
select extract(year from now());

select '67':: int +90;
select now()::date;

select 
upper('PostgresSql') as db_name,
length('Postgres') as name_length,
round(3.14159,2) as rounded_pi,
current_date  as today;


select pk , title , coalesce(descriptions,'No descriptions available') as descriptions from categories1;

select username, coalesce(email,'no-email@unknown.com') as email from users1;

select username , coalesce(email,username || '@generated.com','unknown') as content from users1;

select username, coalesce(score,0) as safe_score from users1;

select title,descriptions from categories1 order by coalesce(descriptions,'zzz');



select title from categories1 order by title;

select distinct title from categories1 order by title;

select distinct age , score from users1 order by age;

select distinct category from posts;

select distinct left(username,1) as first_letter
  from users1 order by first_letter;

select title , views from posts order by views desc limit 2;

select username , score from users1 order by score desc limit 3;

select title from posts order by pk limit 2 offset 0;

select title from posts order by pk limit 2 offset 2;

select title from posts order by pk limit 2 offset 4;


create table posts_archive as select * from posts limit 0;



select * from categories1 where pk in(1,3);

select * from categories1 where pk not in(1,3);

select title, views from posts where category in(
select pk from categories1 where title in('Database','Unix') 
);
select username from users1 where pk in (
select distinct author from posts
);


select username from users1 where pk not in(
select distinct author from posts
  
);

SELECT title, views
FROM posts
WHERE views > (
    SELECT AVG(views) FROM posts
);
