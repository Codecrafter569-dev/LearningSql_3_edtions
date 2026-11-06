create schema if not exists forum;
set search_path to forum , public;

drop table if exists tags cascade;
create table if not exists tags(
pk int primary key,
tag text not null,
parent int
);

drop table if exists new_tags cascade;
create table new_tags as 
select * from tags limit 0;
alter table new_tags add primary key (pk);

drop table if exists new_a_tags cascade;
create table if not exists new_a_tags(
pk int primary key,
tag text not null,
parent int
);
drop table if exists new_b_tags cascade;

create table if not exists new_b_tags(
pk int primary key,
tag text not null,
parent int
);

truncate new_a_tags , new_b_tags;

create or replace rule r_tags1 as on insert to tags where new.tag like 'a%'
do also
insert into new_a_tags(pk,tag,parent)
values (new.pk,new.tag,new.parent);

create or replace rule r_tags2 as 
on insert to tags where new.tag ilike 'b%'
do instead
insert into new_b_tags(pk,tag,parent)
values (new.pk,new.tag,new.parent);


create or replace function f_tags()
returns trigger as 
$$
begin
if lower(substring(new.tag from 1 for 1)) = 'a' then
 insert into new_a_tags (pk,tag,parent)
 values (new.pk,new.tag,new.parent);
 end if;
 return new;
 end;
 $$ language plpgsql;
 
drop trigger if exists t_tags on new_tags;
create trigger t_tags
before insert on new_tags
for each row
execute function f_tags();

insert into new_tags(pk,tag,parent) values
(1,'bsd unix',null);
insert into new_tags(pk,tag,parent) values (2,'alpine linux',1);

select * from new_tags;
select * from new_a_tags;
select * from new_b_tags;

create or replace function f2_tags()
returns trigger as 
$$
begin
if lower(substring(new.tag from 1 for 1)) = 'b' then
insert into new_b_tags(pk,tag,parent)
values (new.pk,new.tag,new.parent);
return null;
end if;
return new;
end;
$$
language plpgsql;

drop trigger if exists t2_tags on new_tags;
create trigger t2_tags
before insert on new_tags
for each row
execute function f2_tags();

truncate new_tags , new_b_tags , new_a_tags;

insert into new_tags (pk , tag,parent) values (1,'bsd unix',null);

select * from new_tags;
select * from new_b_tags;
select * from new_a_tags;

drop trigger if exists t_tags on new_tags;
drop trigger if exists t2_tags on new_tags;

create or replace function f3_tags()
returns trigger as 
$$
begin
if lower(substring(new.tag from 1 for 1)) = 'a' then 
insert into new_a_tags(pk,tag,parent)
values (new.pk,new.tag,new.parent);
return new;
elsif lower(substring(new.tag from 1 for 1)) = 'b' then
insert into new_b_tags (pk,tag,parent)
values (new.pk,new.tag,new.parent);
return null;
else
return new;
end if;
end;
$$ language plpgsql;

drop trigger if exists t3_tags on new_tags;
create trigger t3_tags
before insert on new_tags
for each row 
execute function f3_tags();

truncate new_tags , new_b_tags , new_a_tags;
INSERT INTO new_tags (pk, tag, parent) VALUES (1, 'operating systems', NULL);
INSERT INTO new_tags (pk, tag, parent) VALUES (2, 'alpine linux', 1);
INSERT INTO new_tags (pk, tag, parent) VALUES (3, 'bsd unix', 1);

SELECT * FROM new_tags;
SELECT * FROM new_a_tags;
SELECT * FROM new_b_tags;

drop trigger if exists t3_tags on new_tags;
truncate new_tags , new_a_tags , new_b_tags;

create or replace function fcopy_tags()
returns trigger as 
$$
begin
     if TG_OP = 'INSERT' then
            if lower(substring(new.tag from 1 for 1)) = 'a' then 
            insert into new_a_tags(pk,tag,parent)
            values (new.pk , new.tag,new.parent);
elsif lower(substring(new.tag from 1 for 1)) = 'b' then 
            insert into new_b_tags(pk,tag,parent)
            values (new.pk,new.tag,new.parent);
    end if;
    return new;
    
elsif TG_OP = 'DELETE' then
if lower(substring(old.tag from 1 for 1)) = 'a' then
delete from new_a_tags where pk = old.pk;
elsif lower(substring(old.tag from 1 for 1)) = 'b'
then 
          delete from new_b_tags where pk = old.pk;
    end if;
    return old;
elsif TG_OP = 'UPDATE' then
    if lower(substring(old.tag from 1 for 1)) in ('a','b') then 
      delete from new_a_tags where pk = old.pk;
      delete from new_b_tags where pk = old.pk;
      delete from new_tags where pk = old.pk;
      insert into new_tags (pk , tag,parent) 
      values (new.pk,new.tag,new.parent);
  end if;
  return new;
end if;
return null;
end;
$$
language plpgsql;
drop trigger if exists tcopy_tags_ins on new_tags;
create trigger tcopy_tags_ins
before insert on new_tags
for each row
execute function fcopy_tags();

drop trigger if exists tcopy_tags_del on new_tags;
create trigger tcopy_tags_del
after delete on new_tags
for each row
execute function fcopy_tags();

drop trigger if exists tcopy_tags_upd on new_tags;
create trigger tcopy_tags_upd
after UPDATE on new_tags
for each row
execute function fcopy_tags();


insert into new_tags(pk,tag,parent) values
(1,'operating systems',null),
(2,'alpine linux',1),
(3,'bsd unix',1);

SELECT * from new_tags;
SELECT * from new_a_tags;
SELECT * from new_b_tags;

delete from new_tags where pk = 2;
delete from new_tags where pk = 3;

SELECT * from new_a_tags;
SELECT * from new_b_tags;
SELECT * from new_tags;


truncate new_tags , new_a_tags , new_b_tags;
insert into new_tags(pk,tag,parent) values
(1,'operating systems',null),
(2,'alpine linux',1),
(3,'bsd unix',1);

UPDATE new_tags set tag = 'alpine dos' where pk = 3;


SELECT * from new_a_tags;
SELECT * from new_tags;


create or replace function forum.f_avoid_alter_table()
returns event_trigger as
$$
declare
event_tuple record;
begin
for event_tuple in 
          SELECT * from pg_event_trigger_ddl_commands()
loop 
     if event_tuple.command_tag = 'Alter table'
        and event_tuple.object_type = 'table'then 
        raise exception 'Cannot execute an Alter table!'
    end if;
  end loop;
end
$$
language  plpgsql;

drop event trigger if exists tr_avoid_alter_table;
create event trigger tr_avoid_alter_table
on ddl_command_end

execute function forum.f_avoid_alter_table();


alter table tags add column thumbs_up int default 0;

