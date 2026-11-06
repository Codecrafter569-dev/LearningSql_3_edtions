DROP TABLE IF EXISTS j_posts_tags, post_options, tags, posts, categories, users CASCADE;

CREATE EXTENSION IF NOT EXISTS hstore;

CREATE TABLE users (
    pk SERIAL PRIMARY KEY,
    username TEXT NOT NULL
);

CREATE TABLE categories (
    pk SERIAL PRIMARY KEY,
    title TEXT NOT NULL
);

CREATE TABLE posts (
    pk SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    author INTEGER REFERENCES users(pk),
    category INTEGER REFERENCES categories(pk)
);

CREATE TABLE tags (
    pk SERIAL PRIMARY KEY,
    tag TEXT NOT NULL
);

CREATE TABLE j_posts_tags (
    post_pk INTEGER REFERENCES posts(pk),
    tag_pk INTEGER REFERENCES tags(pk),
    PRIMARY KEY (post_pk, tag_pk)
);

-- Users
INSERT INTO users(username)
VALUES
('luca_ferrari'),
('enrico_pirozzi');

-- Categories
INSERT INTO categories(title)
VALUES
('Database'),
('Programming Languages');

-- Posts
INSERT INTO posts(title, author, category)
VALUES
('Indexing PostgreSQL',1,1),
('Indexing Mysql',1,1),
('A view of Data types in C++',2,2);

-- Tags (Missing in your program)
INSERT INTO tags(tag)
VALUES
('SQL'),
('Index'),
('C++');

-- Post-Tag Mapping
INSERT INTO j_posts_tags(post_pk, tag_pk)
VALUES
(1,1),
(1,2),
(2,1),
(2,2),
(3,3);

-- HSTORE Example
SELECT
    p.pk,
    p.title,
    hstore(ARRAY[
        'username', u.username,
        'category', c.title
    ]) AS options
FROM posts p
JOIN users u
    ON p.author = u.pk
LEFT JOIN categories c
    ON p.category = c.pk
ORDER BY p.pk;

-- Materialized Table
CREATE TABLE post_options AS
SELECT
    p.pk,
    p.title,
    hstore(ARRAY[
        'username', u.username,
        'category', c.title
    ]) AS options
FROM posts p
JOIN users u
    ON p.author = u.pk
LEFT JOIN categories c
    ON p.category = c.pk
ORDER BY p.pk;

-- Search by hstore key
SELECT *
FROM post_options
WHERE options->'category' = 'Database';

-- Insert hstore row
INSERT INTO post_options(pk, title, options)
VALUES
(
    7,
    'my last post',
    hstore('enabled','false')
);

-- Show all rows
SELECT *
FROM post_options
ORDER BY pk;

select p.pk ,
p.title,
string_agg(t.tag,',') as tag 
from posts p left join j_posts_tags jpt on p.pk = jpt.post_pk left join tags t on jpt.tag_pk = t.pk 
group by p.pk , p.title order by p.pk;


select row_to_json(q) as json_data from (
select p.pk ,
p.title,
string_agg(t.tag,',') as tag 
from posts p left join j_posts_tags jpt on p.pk = jpt.post_pk left join tags t on jpt.tag_pk = t.pk 
group by p.pk , p.title order by p.pk
) q;


drop table if exists post_json;
create table post_json (jsondata jsonb);

insert into post_json(jsondata)
select row_to_json(q) as json_data from (
select p.pk ,
p.title,
string_agg(t.tag,',') as tag 
from posts p left join j_posts_tags jpt on p.pk = jpt.post_pk left join tags t on jpt.tag_pk = t.pk 
group by p.pk , p.title order by p.pk
)q;

select jsonb_pretty(jsondata) from post_json;

select jsonb_pretty(jsondata) from post_json where jsondata @> '{"tag":"Database"}';


create or replace function my_sum(x integer, y integer)
returns integer as 
$$
select x + y;
$$ language sql;

select my_sum(1,83);


create or replace function my_sum1(integer,integer) returns integer as 
$$
select $1 + $2;

$$ language sql;

create or replace function dalete_posts(p_title text)
returns setof integer as 
$$
delete from posts where title = p_title returning pk;
$$ language sql;

delete from j_posts_tags where post_pk = (select pk from posts where title = 'A view of Data types in C++');

select dalete_posts('A view of Data types in C++');
select pk , title from posts order by pk;

create or replace function delete_posts_table (p_title text) returns table(ret_key integer , ret_title text) as 
$$
delete from posts where title = p_title returning pk , title;
$$ language sql;
insert into posts (title,author,category) values ('My new post',1,1);
select * from delete_posts_table('My new post');
select pk , title from posts order by pk;

create or replace function nvl(anyelement,anyelement) returns anyelement as 

$$
select coalesce($1,$2);
$$ language sql;

select nvl(null::int,1);
select nvl(''::text,'n'::text);
select nvl('a'::text,'n'::text);




create or replace function my_sum_plpgsql(x integer, y integer)
returns integer as 
$Hello$
declare
ret integer;
begin
ret := x+y;
return ret;
end;
$Hello$ language plpgsql;


select my_sum_plpgsql(34,493);

drop function if exists my_sum_plpgsql(integer,integer);

create or replace function my_sum_named(x integer,y integer) returns integer as 
$Hello$
declare
ret integer;
begin
ret := x + y;
return ret;
end;
$Hello$ language plpgsql;


create or replace function my_sum_position(integer,integer) returns integer as 
$Hello$
declare
ret integer;
begin
ret := $1 + $2;
return ret;
end;
$Hello$ language plpgsql;

select my_sum_named(34,89);
select my_sum_position(1,10);

-- ============================================================
-- PRACTICE PROGRAM: Post Metadata System
-- Combines: hstore, JSONB, SQL functions, SETOF, TABLE return,
--           polymorphic functions, PL/pgSQL
-- ============================================================

CREATE EXTENSION IF NOT EXISTS hstore;

-- 1. Build flexible per-post attributes with hstore
DROP TABLE IF EXISTS post_attributes;
CREATE TABLE post_attributes AS
SELECT p.pk,
       p.title,
       hstore(ARRAY[
           'author',   u.username,
           'category', COALESCE(c.title, 'Uncategorized')
       ]) AS attrs
FROM posts p
INNER JOIN users u ON p.author = u.pk
LEFT JOIN categories c ON p.category = c.pk;

-- 2. Snapshot everything (attrs + tags) as JSONB for archival/API use
DROP TABLE IF EXISTS post_archive;
CREATE TABLE post_archive (archived jsonb);

INSERT INTO post_archive (archived)
SELECT row_to_json(q)
FROM (
    SELECT pa.pk,
           pa.title,
           pa.attrs -> 'author'   AS author,
           pa.attrs -> 'category' AS category,
           string_agg(t.tag, ',') AS tags
    FROM post_attributes pa
    LEFT JOIN j_posts_tags jpt ON pa.pk = jpt.post_pk
    LEFT JOIN tags t ON jpt.tag_pk = t.pk
    GROUP BY pa.pk, pa.title, pa.attrs
) q;

SELECT jsonb_pretty(archived) FROM post_archive;

-- 3. SQL function: find posts by category (SETOF)
CREATE OR REPLACE FUNCTION posts_in_category(p_category text)
RETURNS SETOF integer AS
$$
    SELECT pk FROM post_attributes WHERE attrs -> 'category' = p_category;
$$ LANGUAGE SQL;

SELECT posts_in_category('Database');

-- 4. SQL function returning TABLE: full post summary by author
CREATE OR REPLACE FUNCTION posts_by_author(p_author text)
RETURNS TABLE (post_id integer, post_title text) AS
$$
    SELECT pk, title
    FROM post_attributes
    WHERE attrs -> 'author' = p_author;
$$ LANGUAGE SQL;

SELECT * FROM posts_by_author('luca_ferrari');

-- 5. Polymorphic helper: default value if attribute missing
CREATE OR REPLACE FUNCTION nvl(anyelement, anyelement)
RETURNS anyelement AS
$$
    SELECT coalesce($1, $2);
$$ LANGUAGE SQL;

SELECT nvl((attrs -> 'category'), 'Unknown') FROM post_attributes;

-- 6. PL/pgSQL function: count how many tags a post has (real logic)
CREATE OR REPLACE FUNCTION tag_count(p_post_id integer)
RETURNS integer AS
$BODY$
DECLARE
    cnt integer;
BEGIN
    SELECT count(*) INTO cnt
    FROM j_posts_tags
    WHERE post_pk = p_post_id;

    RETURN cnt;
END;
$BODY$ LANGUAGE plpgsql;

SELECT pk, title, tag_count(pk) AS num_tags FROM posts ORDER BY pk;

-- 7. Cleanup example (function-based delete with RETURNING)
CREATE OR REPLACE FUNCTION delete_post_by_title(p_title text)
RETURNS TABLE (deleted_id integer, deleted_title text) AS
$$
    DELETE FROM posts WHERE title = p_title RETURNING pk, title;
$$ LANGUAGE SQL;

-- (Would need child-row cleanup first in a real run, same as Topic 4 above)
