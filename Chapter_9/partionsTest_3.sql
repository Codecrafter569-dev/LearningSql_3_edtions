DROP TABLE IF EXISTS part_tags CASCADE;

CREATE TABLE part_tags (
    pk SERIAL NOT NULL,
    ins_date DATE NOT NULL DEFAULT CURRENT_DATE,
    tag VARCHAR(255) NOT NULL,
    level INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (pk, ins_date)
)
PARTITION BY RANGE (ins_date);

CREATE TABLE part_tags_2023_01
PARTITION OF part_tags
FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');

CREATE TABLE part_tags_2023_02
PARTITION OF part_tags
FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');

CREATE TABLE part_tags_2023_03
PARTITION OF part_tags
FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');

CREATE TABLE part_tags_2023_04
PARTITION OF part_tags
FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');

INSERT INTO part_tags (tag, ins_date, level)
VALUES
    ('Operating Systems', '2023-01-01', 0),
    ('Linux',             '2023-02-01', 1),
    ('BSD Unix',          '2023-03-01', 1),
    ('Rocky Linux Distro','2023-04-01', 2);

SELECT * FROM part_tags;
SELECT * FROM part_tags_2023_01;
SELECT * FROM part_tags_2023_02;
SELECT * FROM part_tags_2023_03;
SELECT * FROM part_tags_2023_04;

CREATE TABLE part_tags_default
PARTITION OF part_tags DEFAULT;

INSERT INTO part_tags (tag, ins_date, level)
VALUES
    ('Ubuntu Linux', '2023-05-01', 2),
    ('Windows 11',   '2023-06-01', 3);

SELECT * FROM part_tags;
SELECT * FROM part_tags_default;

-- Create tablespaces (make sure these directories already exist)
CREATE TABLESPACE ts_a
LOCATION '/data/data/com.termux/files/home/tablespaces/ts_a';

CREATE TABLESPACE ts_b
LOCATION '/data/data/com.termux/files/home/tablespaces/ts_b';

-- Change owner (only if the forum role exists)
ALTER TABLESPACE ts_a OWNER TO forum;
ALTER TABLESPACE ts_b OWNER TO forum;
-- psql -U u0_a372 -d forumdb -f chapter9.sql
-- If the forum role does not exist, use these instead:
-- ALTER TABLESPACE ts_a OWNER TO u0_a372;
-- ALTER TABLESPACE ts_b OWNER TO u0_a372;

-- Verify tablespaces
SELECT
    spcname,
    pg_tablespace_location(oid)
FROM pg_tablespace;

create table tablespaces_part_tags(
pk serial not null,
ins_date date not null DEFAULT now()::date,
tag varchar(255) not null,
level integer not null default 0,
primary key (pk,ins_date)
)
PARTITION by range(ins_date);

create table tablespaces_part_tags_date_2022 partition of tablespaces_part_tags for values from ('2022-01-01') to ('2023-01-01') TABLESPACE ts_a;

create table tablespace_part_tags_date_2023 partition of tablespaces_part_tags for values from ('2023-01-01') to ('2024-01-01') TABLESPACE ts_b;

create table tablespaces_part_tags_date_default partition of tablespaces_part_tags default;

insert into tablespaces_part_tags(tag,ins_date,level) values
    ('Operating Systems',  '2022-01-01', 0),
    ('Linux',              '2022-02-01', 1),
    ('BSD Unix',           '2023-03-01', 1),
    ('Rocky Linux Distro', '2018-04-01', 2);
    
select * from tablespaces_part_tags;
select * from tablespaces_part_tags_date_2022;
select * from tablespace_part_tags_date_2023;
select * from tablespaces_part_tags_date_default;

create table basilea(
id integer primary key,
insert_time timestamptz not null,
temperature numeric(8,6) not null
);
create table basilea_partitioned(
id integer not null,
insert_time timestamptz not null,
temperature numeric(8,6) not null,
primary key (id,insert_time)
)
partition by range(insert_time);

CREATE TABLE basilea_partitioned_1950
    PARTITION OF basilea_partitioned
    FOR VALUES FROM ('1949-12-31 23:00:00+00')
             TO   ('1950-12-31 23:00:00+00');

-- ... one partition per year continues the same pattern
-- through 2022 (omitted here for length) ...

CREATE TABLE basilea_partitioned_2023
    PARTITION OF basilea_partitioned
    FOR VALUES FROM ('2022-12-31 23:00:00+00')
             TO   ('2023-12-31 23:00:00+00');

CREATE TABLE basilea_partitioned_default
    PARTITION OF basilea_partitioned DEFAULT;

INSERT INTO basilea_partitioned
    SELECT * FROM basilea;

-- Top 5 years by avg temperature — flat table
EXPLAIN ANALYZE
SELECT
    extract(year FROM insert_time) AS year,
    avg(temperature)               AS avg_temp
FROM basilea
GROUP BY year
ORDER BY avg_temp DESC
LIMIT 5;

-- Same query — partitioned table
EXPLAIN ANALYZE
SELECT
    extract(year FROM insert_time) AS year,
    avg(temperature)               AS avg_temp
FROM basilea_partitioned
GROUP BY year
ORDER BY avg_temp DESC
LIMIT 5;

-- Filtered by date range — flat table
EXPLAIN ANALYZE
SELECT
    extract(year FROM insert_time) AS year,
    avg(temperature)               AS avg_temp
FROM basilea
WHERE insert_time >= '2021-01-01 00:00:00+00'
  AND insert_time <  '2024-01-01 00:00:00+00'
GROUP BY year
ORDER BY avg_temp DESC
LIMIT 5;

-- Same filter — partitioned table (only 2021/22/23 scanned)
EXPLAIN ANALYZE
SELECT
    extract(year FROM insert_time) AS year,
    avg(temperature)               AS avg_temp
FROM basilea_partitioned
WHERE insert_time >= '2021-01-01 00:00:00+00'
  AND insert_time <  '2024-01-01 00:00:00+00'
GROUP BY year
ORDER BY avg_temp DESC
LIMIT 5;

-- Confirm the setting that enables partition pruning
SELECT name, setting, short_desc
FROM pg_settings
WHERE name = 'constraint_exclusion';

-- In psql only (not plain SQL), you'd also run:
--   \d+ basilea_partitioned
-- to see the partition list and bounds interactively.