-- ============================================================================
--  forumdb demo — fixed & complete runnable script
--  Reconstructed from a corrupted/truncated psql transcript.
--  Requires PostgreSQL 15+ (uses MERGE). Tested logic against every
--  intermediate result still legible in the original transcript.
--
--  Run with:   psql -d forumdb -f forumdb_demo_fixed.sql
--  or paste the whole file into an interactive psql session.
--
--  NOTE: Section 7 contains ONE statement that is SUPPOSED to raise an
--  error (it demonstrates a unique-constraint violation on purpose).
--  psql does not abort a script on error unless you SET ON_ERROR_STOP,
--  so the rest of the script still runs after it.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. CLEAN SLATE — safe to re-run
-- ----------------------------------------------------------------------------
--DROP SCHEMA IF EXISTS forum CASCADE;
--CREATE SCHEMA forum;
--SET search_path TO forum, public;

drop table if exists users;
drop table if exists categories;
drop table if exists tags;
drop table if exists posts;
drop table if exists j_posts_tags;

-- ----------------------------------------------------------------------------
-- 1. SCHEMA
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    pk       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username varchar(96)  NOT NULL UNIQUE,
    gecos    varchar(128),
    email    varchar(128) NOT NULL
);

CREATE TABLE categories (
    pk          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title       varchar(255) NOT NULL,
    description varchar(255)
);

CREATE TABLE tags (
    pk     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tag    varchar(255) NOT NULL,
    parent integer REFERENCES tags(pk)
);

CREATE TABLE posts (
    pk       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title    varchar(255) NOT NULL,
    body     text,
    author   integer NOT NULL REFERENCES users(pk),
    category integer REFERENCES categories(pk)
);

-- Created WITHOUT a primary key on purpose — matches the "before" \d
-- output in the original transcript (tag_pk not null, post_pk nullable,
-- no PK yet). The PK is added explicitly in section 6.
CREATE TABLE j_posts_tags (
    tag_pk  integer NOT NULL REFERENCES tags(pk),
    post_pk integer REFERENCES posts(pk)
);


-- ----------------------------------------------------------------------------
-- 2. SEED DATA
-- ----------------------------------------------------------------------------
INSERT INTO users (username, gecos, email) VALUES
    ('enrico_pirozzi', 'Enrico Pirozzi', 'enrico@example.com'),
    ('luca_ferrari',   'Luca Ferrari',   'luca@example.com');

INSERT INTO categories (title, description) VALUES
    ('Database',              'Database related discussions'),
    ('Unix',                  'Unix and Linux discussions'),
    ('Programming Languages', 'All about programming languages'),
    ('New Category',          NULL),
    ('Database',               'PostgreSQL');

INSERT INTO tags (tag) VALUES
    ('Database'),
    ('Operating Systems');

INSERT INTO posts (title, body, author, category) VALUES
    ('Indexing PostgreSQL',  'A short discussion about indexes',   2, 1),
    ('Indexing Mysql',       'A short discussion about indexes',   2, 1),
    ('A view on Data types', 'A discussion on data types in C++',  1, 3);


-- ----------------------------------------------------------------------------
-- 3. SIMPLE SELECT
-- ----------------------------------------------------------------------------
SELECT tag FROM tags;
-- Database
-- Operating Systems


-- ----------------------------------------------------------------------------
-- 4. SET OPERATIONS — EXCEPT / INTERSECT
-- ----------------------------------------------------------------------------
SELECT title AS datalist FROM categories
EXCEPT
SELECT tag AS datalist FROM tags
ORDER BY 1;
-- New Category
-- Programming Languages
-- Unix

SELECT title AS datalist FROM categories
INTERSECT
SELECT tag AS datalist FROM tags
ORDER BY 1;
-- Database


-- ----------------------------------------------------------------------------
-- 5. INSERT ... ON CONFLICT — general syntax (reference only)
-- ----------------------------------------------------------------------------
-- INSERT INTO table_name (column_list) VALUES (value_list)
-- ON CONFLICT target action;


-- ----------------------------------------------------------------------------
-- 6. JUNCTION TABLE — add the composite primary key
-- ----------------------------------------------------------------------------
\d j_posts_tags

ALTER TABLE j_posts_tags
    ADD CONSTRAINT j_posts_tags_pkey PRIMARY KEY (tag_pk, post_pk);

\d j_posts_tags


-- ----------------------------------------------------------------------------
-- 7. INSERT + CONFLICT HANDLING
-- ----------------------------------------------------------------------------
INSERT INTO j_posts_tags (post_pk, tag_pk) VALUES (3,2), (1,1), (2,1);
-- INSERT 0 3

SELECT * FROM j_posts_tags ORDER BY tag_pk, post_pk;
--  tag_pk | post_pk
-- --------+---------
--       1 |       1
--       1 |       2
--       2 |       3

-- Intentional failure: (tag_pk, post_pk) = (1, 2) already exists.
INSERT INTO j_posts_tags (post_pk, tag_pk) VALUES (2,1);
-- ERROR:  duplicate key value violates unique constraint "j_posts_tags_pkey"
-- DETAIL: Key (tag_pk, post_pk)=(1, 2) already exists.

INSERT INTO j_posts_tags (post_pk, tag_pk) VALUES (2,1) ON CONFLICT DO NOTHING;
-- INSERT 0 0   (silently skipped, no error)

INSERT INTO j_posts_tags (post_pk, tag_pk) VALUES (2,1)
    ON CONFLICT (tag_pk, post_pk) DO UPDATE SET tag_pk = tag_pk + 1;
-- INSERT 0 1   (the existing (tag_pk=1, post_pk=2) row becomes (2, 2))

SELECT * FROM j_posts_tags ORDER BY tag_pk, post_pk;
--  tag_pk | post_pk
-- --------+---------
--       1 |       1
--       2 |       2
--       2 |       3


-- ----------------------------------------------------------------------------
-- 8. RETURNING
-- ----------------------------------------------------------------------------
INSERT INTO j_posts_tags (tag_pk, post_pk) VALUES (1,3) RETURNING *;
--  tag_pk | post_pk
-- --------+---------
--       1 |       3

INSERT INTO j_posts_tags (tag_pk, post_pk) VALUES (1,2) RETURNING tag_pk;
--  tag_pk
-- --------
--       1
-- (1 row)

UPDATE posts SET title = 'A view of Data types in C++' WHERE pk = 3;


-- ----------------------------------------------------------------------------
-- 9. TEMP TABLE + UPDATE ... FROM
-- ----------------------------------------------------------------------------
SELECT * FROM categories ORDER BY pk;

CREATE TEMP TABLE t_categories AS SELECT * FROM categories LIMIT 0;

INSERT INTO t_categories (pk, title, description) VALUES
    (4, 'Machine Learning',     'Machine Learning discussions'),
    (5, 'Software engineering', 'Software engineering discussions');
-- INSERT 0 2

SELECT * FROM t_categories;

UPDATE categories c
    SET title = t.title, description = t.description
    FROM t_categories t
    WHERE c.pk = t.pk;
-- UPDATE 2

SELECT * FROM categories ORDER BY pk;
--  1 | Database              | Database related discussions
--  2 | Unix                  | Unix and Linux discussions
--  3 | Programming Languages | All about programming languages
--  4 | Machine Learning      | Machine Learning discussions
--  5 | Software engineering  | Software engineering discussions


-- ----------------------------------------------------------------------------
-- 10. MERGE
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE new_data AS SELECT * FROM categories LIMIT 0;

INSERT INTO new_data (pk, title, description) VALUES
    (1, 'Database Discussions',  'Database discussions'),
    (2, 'Unix/Linux discussion', 'Unix and Linux discussions');
-- INSERT 0 2

SELECT * FROM new_data;

MERGE INTO categories c
USING new_data n ON c.pk = n.pk
WHEN MATCHED THEN
    UPDATE SET title = n.title, description = n.description
WHEN NOT MATCHED THEN
    INSERT (pk, title, description)
    OVERRIDING SYSTEM VALUE VALUES (n.pk, n.title, n.description);
-- MERGE 2

SELECT * FROM categories ORDER BY pk;
--  1 | Database Discussions  | Database discussions
--  2 | Unix/Linux discussion | Unix and Linux discussions
--  3 | Programming Languages | All about programming languages
--  4 | Machine Learning      | Machine Learning discussions
--  5 | Software engineering  | Software engineering discussions


-- ----------------------------------------------------------------------------
-- 11. UPDATE / DELETE ... RETURNING
-- ----------------------------------------------------------------------------
UPDATE categories SET title = 'A.I' WHERE pk = 4
    RETURNING pk, title, description;
--  4 | A.I | Machine Learning discussions

DELETE FROM t_categories WHERE pk = 4
    RETURNING pk, title, description;
--  4 | Machine Learning | Machine Learning discussions


-- ----------------------------------------------------------------------------
-- 12. CTEs — WITH, equivalent subquery, MATERIALIZED / NOT MATERIALIZED
-- ----------------------------------------------------------------------------
WITH posts_author_1 AS (
    SELECT p.* FROM posts p
    INNER JOIN users u ON p.author = u.pk
    WHERE username = 'enrico_pirozzi'
)
SELECT pk, title FROM posts_author_1;
--  3 | A view of Data types in C++

-- Same result, written as a plain derived subquery instead of a CTE
SELECT pk, title FROM
    (SELECT p.* FROM posts p
     INNER JOIN users u ON p.author = u.pk
     WHERE u.username = 'enrico_pirozzi') posts_author_1;
--  3 | A view of Data types in C++

-- Forces the CTE to be optimized as an inline barrier (materialized first)
WITH posts_author_1 AS MATERIALIZED (
    SELECT p.* FROM posts p
    INNER JOIN users u ON p.author = u.pk
    WHERE username = 'enrico_pirozzi'
)
SELECT pk, title FROM posts_author_1;

-- Lets the planner inline/fold the CTE into the outer query (PG12+ default
-- behavior for single-use, side-effect-free CTEs; this makes it explicit)
WITH posts_author_1 AS NOT MATERIALIZED (
    SELECT p.* FROM posts p
    INNER JOIN users u ON p.author = u.pk
    WHERE username = 'enrico_pirozzi'
)
SELECT pk, title FROM posts_author_1;


-- ----------------------------------------------------------------------------
-- 13. DATA-MODIFYING CTE #1 — DELETE ... RETURNING chained into INSERT
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE t_posts AS SELECT * FROM posts;
CREATE TABLE delete_posts AS SELECT * FROM posts LIMIT 0;

SELECT pk, title, category FROM t_posts;
--  1 | Indexing PostgreSQL         | 1
--  2 | Indexing Mysql              | 1
--  3 | A view of Data types in C++ | 3

SELECT pk, title, category FROM delete_posts;
-- (0 rows)

WITH del_posts AS (
    DELETE FROM t_posts
    WHERE category IN (SELECT pk FROM categories WHERE title = 'Database Discussions')
    RETURNING *
)
INSERT INTO delete_posts SELECT * FROM del_posts;

SELECT pk, title, category FROM t_posts;
--  3 | A view of Data types in C++ | 3
-- (1 row)

SELECT pk, title, category FROM delete_posts;
--  1 | Indexing PostgreSQL | 1
--  2 | Indexing Mysql      | 1


-- ----------------------------------------------------------------------------
-- 14. DATA-MODIFYING CTE #2 — INSERT ... RETURNING chained into DELETE
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS t_posts;
CREATE TEMP TABLE t_posts AS SELECT * FROM posts;   -- fresh copy, all 3 rows again

CREATE TABLE inserted_posts AS SELECT * FROM posts LIMIT 0;

WITH ins_posts AS (
    INSERT INTO inserted_posts
    SELECT * FROM t_posts
    RETURNING pk
)
DELETE FROM t_posts WHERE pk IN (SELECT pk FROM ins_posts);
-- DELETE 3

SELECT pk, title, category FROM t_posts;
-- (0 rows)

SELECT pk, title, category FROM inserted_posts;
--  1 | Indexing PostgreSQL         | 1
--  2 | Indexing Mysql              | 1
--  3 | A view of Data types in C++ | 3


-- ----------------------------------------------------------------------------
-- 15. RECURSIVE CTE — tag hierarchy
-- ----------------------------------------------------------------------------
INSERT INTO tags (tag, parent) VALUES ('PostgreSQL', 1);

SELECT * FROM tags ORDER BY pk;
--  1 | Database          |
--  2 | Operating Systems |
--  3 | PostgreSQL        | 1

WITH RECURSIVE tags_tree AS (
    -- non-recursive term (anchor): top-level tags
    SELECT tag, pk, 1 AS level
    FROM tags WHERE parent IS NULL
    UNION
    -- recursive term: walk down to children
    SELECT tt.tag || ' -> ' || ct.tag, ct.pk, tt.level + 1
    FROM tags ct
    JOIN tags_tree tt ON tt.pk = ct.parent
)
SELECT level, tag FROM tags_tree
ORDER BY level;
--  1 | Database
--  1 | Operating Systems
--  2 | Database -> PostgreSQL

