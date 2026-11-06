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

select c.pk , c.title, p.pk , p.category , p.title from categories1 c , posts p;

select c.pk , c.title , p.pk , p.category , p.title from categories1 c cross join posts p;

select c.pk , c.title , p.pk , p.category , p.title from categories1 c , posts p where c.pk = p.category;


select c.pk , c.title , p.pk , p.category , p.title from categories1 c inner join posts p on c.pk = p.category;

select c.pk , c.title , p.pk , p.category , p.title from categories1 c inner join posts p on c.pk = p.category;


select c.* ,p.category,p.title from categories1 c left join posts p on c.pk = p.category;
  


select * from categories1 c where c.pk not in (select category from posts);


select * from categories1 c where  not exists (select 1 from posts where category=c.pk);


select c.* , p.category from categories1 c left join posts p on p.category = c.pk;

select c.* from categories1 c left join posts p on p.category=c.pk where p.category is null;

select c.* , p.category from categories1 c left join posts p on p.category = c.pk;

select c.* , p.category from posts p right join categories1 c on c.pk = p.category;

create temp table new_posts as select * from posts;

insert into new_posts(pk , title ,content , author ,category) values (6,'A new book','A new book not present in category ......',1,null);

select pk ,title , category from new_posts;

select c.pk , c.title , p.pk , p.title from categories1 c inner join new_posts p on p.category = c.pk;


select c.pk , c.title ,p.pk , p.title from categories1 c full outer join new_posts p on p.category  = c.pk;



select c.pk , c.title , p.pk , p.title from categories1 c cross join new_posts p;

select c.pk , c.title , p.pk , p.title , p.category from categories1 c cross join new_posts p where p.category = c.pk;




alter table posts add likes integer default 0;
update posts set likes = 3 where title like '%Python%';

select title , likes from posts order by likes;

select u.* from users1 u where exists (select 1 from posts p where u.pk = p.author and likes > 2);


--select u.username , q.* from users1 u join lateral (select author , title,likes from posts p where u.pk = p.author and likes > 2);

select category , count(*) from posts group by category;


select category , count(*) from posts group by 1;
select category , count(*) from posts group by category having count(*) > 1;
select category , count(*) from posts group by 1 having count(*) > 1;

select category , count(*) as category_count from posts group by category;

select category , count(*) as category_count from posts group by category  having category_count > 2;


select category , count(*) as category_count from posts group by category having count(*) > 1;

insert into tags (tag) values ('Database'),('Operating Systems');

select tag from tags;