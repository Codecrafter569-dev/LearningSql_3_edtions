create extension if not exists hstore;

drop table if exists posts cascade;
create table posts(
pk integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
title text not null,
content text 
);
insert into posts(title , content) values 
('Indexing PostgreSQL', 'Btree in PostgreSQL explained'),
    ('Backup Strategies',   'pg_dump vs pg_basebackup');
drop table if exists tags cascade;
create table tags(
pk integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
tag text not null,
parent integer references tags(pk)
);
insert into tags(tag , parent) values
   ('Operating Systems', NULL),
    ('Linux', 1),
    ('Ubuntu', 2);


select * from tags;
select * from posts;

create or replace function my_sum_3_params(
in x integer ,
in y integer,
out z integer
) as 
$$
begin
z := x +y;
end;
$$ language plpgsql;

select my_sum_3_params(30,40);

create or replace function sum_param_mul(
in   x integer ,
in y integer ,
out z integer,
out w integer
) as 
$$
begin
z := x +y;
w := x * y;
end;
$$
language plpgsql;

select sum_param_mul(23,33);
select * from sum_param_mul(20,30);
select * from sum_param_mul(33,22) where z = 55;

create or replace function my_chacks(
x integer default 0,
y integer default 0
) returns text as 
$$
begin
if x > y then
return ' first parameter is greater then the second parameter';
elsif x < y then
return 'second parameter is greater then the first parameter';
else 
return 'the two parameter are equals';
end if;
end;
$$ language plpgsql;

select my_chacks(1,2);
select my_chacks(2,1);
select my_chacks(2,2);

create or replace function my_chack_values(
x integer default 0
) returns text as
$$
begin
case x 
    when 1 then return 'value = 1';
    when 2 then return 'value = 2';
    else return 'value >= 3';
    end case;
end;
$$ language plpgsql;

select my_chack_values(23);
select my_chack_values(2);
select my_chack_values(1);

create or replace function my_check_case(
x integer default 0,
y integer default 0
) returns text as 
$$
begin
     case 
         when x > y then return ' first parameter is greater then second parameter';
         when x < y then return 'second parameter is greater then first parameter';
         else return 'the two parameter are equals';
         end case;
         end;
  $$ language plpgsql;
  
select my_check_case(1,2);
select my_check_case(2,1);
select my_check_case(2,2);
select my_check_case();

drop type if exists my_ret_type cascade;
create type my_ret_type as (
id integer ,
title text,
record_data hstore
);

create or replace function my_first_fun(p_id integer)
returns setof my_ret_type as 
$$
declare
rw posts%ROWTYPE;
ret my_ret_type;
begin
for rw in select * from posts where pk = p_id loop
ret.id := rw.pk;
ret.title := rw.title;
ret.record_data := hstore(array['title',rw.title,'Title and content',format('%s %s',rw.title,rw.content)

]); return next ret;
end loop;
return;
end;
$$ language plpgsql;

select * from my_first_fun(1);

create or replace function my_second_fun(p_id integer)
returns setof my_ret_type as
$$
declare
rw record;
ret my_ret_type;
begin
for rw in select * from posts where pk = p_id loop
ret.id := rw.pk;
ret.title := rw.title;
ret.record_data := hstore(array['title',rw.title,'Title and content',format('%s %s',rw.title,rw.content)

]);
return next ret;
end loop;
return;
end;
$$ language plpgsql;

select * from my_second_fun(1);


create or replace function my_first_except(x real,y real)
returns real as 
$$
declare
ret real;
begin
ret := x / y;
return ret;
end;
$$ language plpgsql;

select my_first_except(8,2);
select my_first_except(4,0);


create or replace function my_second_exept(x real , y real) returns real as 
$$
declare
ret real;
begin
ret := x / y;
return ret;
exception 
  when division_by_zero then
  raise info 'division_by_zero';
  raise info 'error % %',sqlstate,sqlerrm;
  return 0;
end;
$$ language plpgsql;

select my_second_exept(4,0);




create schema if not exists forum;
create or replace function forum.my_stat_activity()
returns table (pid integer , query text) as

$$ 
select pid , query from pg_stat_activity;
$$ language sql
security definer;


drop table if exists o_tags cascade;
create table o_tags(
pk integer not null primary key,
tag text,
parent integer
);

create or replace rule r_tags1 as
on insert to tags
where new.tag ilike 'o%'
do also
    insert into o_tags (pk,tag,parent)
    values (new.pk,new.tag,new.parent);
    
    
insert into tags (tag) values ('OpenBSD');
select * from tags;
select * from o_tags;

drop table if exists f_tags cascade;
create table f_tags(
pk integer not null primary key,
tag text,
parent integer
);

create or replace rule r_tags2 as 
on insert to tags
where new.tag ilike 'f%'
do instead
insert into f_tags (pk,tag,parent)
    values (new.pk,new.tag,new.parent);

insert into tags(tag) values ('Fedora Linux');
select * from tags;
select * from f_tags;

create or replace rule r_tags as
on insert to tags
where new.tag ilike 'r%'
do instead nothing;

insert into tags(tag) values ('Red Hat Linux');

select pk , tag,parent ,'tags' as tablename from tags
union all

select pk , tag,parent , 'f_tags' as tablename from f_tags order by tablename , tag;

drop table if exists new_tags cascade;
create table new_tags as select * from tags limit 0;
alter table new_tags alter column pk set not null;
alter table new_tags add constraint new_tags_pk primary key (pk);


drop table if exists new_a_tags cascade;
create table new_a_tags as select * from tags limit 0;
alter table new_a_tags alter column pk set not null;
alter table new_a_tags add constraint new_a_tags_pk primary key (pk);



drop table if exists new_b_tags cascade;
create table new_b_tags as select * from tags limit 0;
alter table new_b_tags alter column pk set not null;
alter table new_b_tags add constraint new_b_tags_pk primary key (pk);

create or replace rule r_new_tags_insert_a as on insert to new_tags where new.tag like 'a%'
   do also
         insert into new_a_tags (pk,tag,parent) values
         (new.pk,new.tag,new.parent);
         
create or replace rule r_new_tags_insert_b as on insert to new_tags where new.tag like 'b%' 
do also 
      insert into new_b_tags(pk , tag , parent)values
      (new.pk,new.tag,new.parent);
      
insert into new_tags values (1,'linux',null);
insert into new_tags values (2,'alpine linux',1);
insert into new_tags values (3,'bsd unix',null);


select * from new_tags;
select * from new_a_tags;
select * from new_b_tags;



create or replace rule r_new_tags_delete_a as 
on delete to new_tags
where old.tag like 'a%'
do also 
     delete from new_a_tags where new_a_tags.pk = old.pk;
  
create or replace rule r_new_tags_delete_b as on delete to  new_tags where old.tag like 'b%'
     do also 
  delete from new_b_tags where new_b_tags.pk = old.pk;
  
delete from new_tags where tag = 'alpine linux';
delete from new_tags where tag = 'bsd unix';

select * from new_tags;
select * from new_a_tags;
select * from new_b_tags;


create or replace function move_record(
p_pk integer,
p_tag text,
p_parent integer,
p_old_pk integer
)returns void as 
$$
begin
if left(lower(p_tag),1) in ('a','b') then 
      delete from new_tags where pk = p_old_pk;
      insert into new_tags values (p_pk,p_tag,p_parent);
      end if;
end;
$$ language plpgsql;

create or replace rule r_new_tags_update_a as on update to new_tags 
do also 
  select move_record(new.pk,new.tag,new.parent,old.pk);
  
update new_tags set tag = 'alpine linux' where tag = 'linux';
select * from new_tags;
select * from new_a_tags;


update new_tags set tag = 'bsd unix' where tag = 'alpine linux';

select * from new_tags;
select * from new_a_tags;
select * from new_b_tags;




