drop table if exists table_b;
drop table if exists table_a cascade;

create table table_a(
pk integer not null primary key,
tag text,
parent integer
);

create table table_b () inherits (table_a);

alter table table_b add constraint table_b_pk primary key (pk);


insert into table_a(pk,tag,parent)
  values(1,'Operating System',0);
insert into table_b (pk ,tag,parent)
values (2,'Linx',0);

select * from table_b;
select * from table_a;
select * from only table_a;

update table_a set tag = 'BSD Unix' where pk = 2;
select * from table_b;

delete from table_a where pk = 2;
select * from table_a;
select * from table_b;

drop table table_b;
drop table table_a cascade;


drop table if exists part_tags cascade;

create table part_tags(
pk serial not null,
level integer not null default 0,
tag varchar(255) not null,
primary key (pk ,level)
)
partition by list(level);

create table part_tags_level_0 partition of part_tags for 
values in (0);
create table part_tags_level_1 partition of part_tags for values in (1);
create table part_tags_level_2 partition of part_tags for values in (2);
create table part_tags_level_3 partition of part_tags for values in (3);

create index on part_tags(tag);

insert into part_tags(tag,level) values ('Operating System',0);
insert into part_tags(tag,level) values ('Linux',1);
insert into part_tags(tag,level) values ('BSD UNIX',1);
insert into part_tags(tag,level) values ('DOS',1);
insert into part_tags(tag,level) values ('window',2);

select * from part_tags;
select * from part_tags_level_0;
select * from part_tags_level_1;
select * from part_tags_level_2;
select * from part_tags_level_3;

drop table if exists part_tags cascade;

create table part_tags(
pk serial not null,
ins_dete date not null default now()::date,
tag varchar(255) not null default 0,
level integer not null default 0,
primary key (pk , ins_dete)
)
partition by range (ins_dete);

create table part_tags_date_01_2023 partition of part_tags for values from ('2023-01-01') to ('2023-02-01');
create table part_tags_date_02_2023 partition of part_tags for values from ('2023-02-01') to ('2023-03-01');
create table part_tags_date_03_2023 partition of part_tags
  for values from ('2023-03-01') to ('2023-04-01');
create table part_tags_date_04_2023 partition of part_tags
for values from ('2023-04-01') to ('2023-05-01');

CREATE INDEX ON part_tags (tag);

insert into part_tags(tag,ins_dete,level)
values ('Operating System','2023-01-01',0);
insert into part_tags(tag,ins_dete,level)
values ('Linux','2023-02-01',1);
insert into part_tags(tag,ins_dete,level)
values ('BSD UNIX','2023-03-01',1);
insert into part_tags(tag,ins_dete,level)
values ('Rocky linux distro','2023-04-01',2);

select * from part_tags;
select * from part_tags_date_01_2023;
select * from part_tags_date_02_2023;
select * from part_tags_date_03_2023;
select * from part_tags_date_04_2023;


CREATE table part_tags_date_05_2023 partition of part_tags for values from ('2023-05-01') to ('2023-06-01');
\d part_tags
alter table part_tags detach partition part_tags_date_05_2023;
\d part_tags
create table part_tags_already_exists(
pk integer not null,
ins_dete date not null,
tag varchar(255) not null,
level integer not null,
primary key(pk,ins_dete)
);
\d part_tags

alter table part_tags attach partition part_tags_already_exists for values from ('1970-01-01') to ('2023-01-01');

\d+ part_tags





