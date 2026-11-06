-- =====================================================================
--  POSTGRESQL LEARNING SCRIPT
--  Topic   : Privileges (GRANT/REVOKE), Ownership, ACL Inspection,
--            Row-Level Security (RLS), Password Encryption, SSL
--  Level   : Basic -> Advanced
--  Target  : PostgreSQL 15/16/17/18, tested for Termux (psql client)
--
--  HOW TO RUN
--  ----------
--  This script is meant to be run with psql as a SUPERUSER, because:
--    1) It creates roles and a database.
--    2) Several demos use `SET ROLE` to "become" different users in
--       the same session, which only a superuser (or a role that is
--       a member of the target role) is allowed to do.
--
--    $ psql -U postgres -f postgresql_permissions_rls_ssl.sql
--
--  Everything in this file is designed to run top-to-bottom without
--  errors on a fresh Termux PostgreSQL cluster. Passages that come
--  straight from the source material and are NOT valid, runnable SQL
--  (shell sessions, postgresql.conf lines, pg_hba.conf lines, plain
--  error output) are kept as comments, clearly marked, immediately
--  followed by a working equivalent where one is possible.
-- =====================================================================


-- =====================================================================
-- SECTION 1 — ENVIRONMENT SETUP
-- =====================================================================
-- Everything below this line builds the small "forum" application
-- database used throughout the rest of the script: a schema, three
-- tables, one function, and four roles. None of this exists in the
-- original notes verbatim — it is added so every later GRANT/REVOKE/
-- RLS example has something real to operate on and can actually be
-- executed, not just read.

-- ---------------------------------------------------------------
-- 1.1 Roles
-- ---------------------------------------------------------------
-- A ROLE in PostgreSQL is a single, unified concept that covers what
-- other databases split into "users" and "groups". A role can:
--   - LOGIN (behave like a user that can open a connection), or
--   - NOLOGIN (behave like a pure permission group), or both.
-- Passwords are stored, not in plain text, but hashed according to
-- the `password_encryption` setting (see Section 7).
--
-- We wrap each CREATE ROLE in a DO block that checks pg_roles first,
-- so the script is idempotent (safe to re-run without erroring out
-- on "role already exists").

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'luca') THEN
        CREATE ROLE luca LOGIN PASSWORD 'ChangeMe_luca_123';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'forum') THEN
        CREATE ROLE forum LOGIN PASSWORD 'ChangeMe_forum_123';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'forum_stats') THEN
        CREATE ROLE forum_stats LOGIN PASSWORD 'ChangeMe_stats_123';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'giulia') THEN
        CREATE ROLE giulia LOGIN PASSWORD 'ChangeMe_giulia_123';
    END IF;
END
$$;

-- Roles created:
--   luca         -> the database "owner"/admin used in most examples
--   forum        -> the application's own role; owns the forum schema
--   forum_stats  -> a reporting role that only needs read access to
--                   a few columns (used in the column-privilege demo)
--   giulia       -> a second forum end-user, used to prove that RLS
--                   really stops one user from seeing another's rows


-- ---------------------------------------------------------------
-- 1.2 Database
-- ---------------------------------------------------------------
-- CREATE DATABASE cannot run inside a transaction block/DO block,
-- so it stays a plain top-level statement. Uncomment the DROP line
-- below if you are re-running this script from scratch.

-- DROP DATABASE IF EXISTS forumdb;
-- (Run manually if you need a clean slate — commented out so this
--  script never silently destroys existing work.)

SELECT 'CREATE DATABASE forumdb OWNER luca'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'forumdb')
\gexec
-- \gexec is a psql meta-command: it takes the text returned by the
-- previous query and executes it as a new SQL command. Combined with
-- the WHERE NOT EXISTS guard, this creates forumdb only if it is
-- missing — a portable "CREATE DATABASE IF NOT EXISTS".

-- Connect to it for everything that follows (psql meta-command).
\c forumdb

-- ---------------------------------------------------------------
-- 1.3 Schema
-- ---------------------------------------------------------------
-- AUTHORIZATION sets the schema's owner at creation time, exactly
-- like `ALTER SCHEMA ... OWNER TO ...` afterwards would.
CREATE SCHEMA IF NOT EXISTS forum AUTHORIZATION forum;

-- Make unqualified names (users, posts, categories...) resolve
-- inside forum automatically, matching how the original transcript
-- refers to "posts" and "users" without a schema prefix.
SET search_path TO forum, public;

-- ---------------------------------------------------------------
-- 1.4 Tables
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS forum.categories (
    pk          serial PRIMARY KEY,
    title       text NOT NULL,
    description text
);

CREATE TABLE IF NOT EXISTS forum.users (
    pk       serial PRIMARY KEY,
    username text UNIQUE NOT NULL,   -- creates index "users_username_key"
    gecos    text,                   -- display name, as in /etc/passwd's GECOS field
    email    text
);

CREATE TABLE IF NOT EXISTS forum.posts (
    pk              serial PRIMARY KEY,
    author          integer NOT NULL REFERENCES forum.users(pk),
    title           text NOT NULL,
    body            text,
    last_edited_on  timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------
-- 1.5 A routine (function), used later for ALTER ROUTINE / EXECUTE
-- ---------------------------------------------------------------
-- get_max() is a small utility function: given a table name inside
-- the forum schema, it returns the current maximum primary key.
-- It exists here purely so Section 2 and Section 4 have a real
-- routine to GRANT EXECUTE on and to re-assign ownership of.
CREATE OR REPLACE FUNCTION forum.get_max(tablename text)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_max integer;
BEGIN
    EXECUTE format('SELECT COALESCE(MAX(pk), 0) FROM forum.%I', tablename)
    INTO v_max;
    RETURN v_max;
END;
$$;

-- ---------------------------------------------------------------
-- 1.6 Sample data + baseline privileges
-- ---------------------------------------------------------------
INSERT INTO forum.users (username, gecos, email) VALUES
    ('luca',   'Luca Ferrari', 'luca@example.com'),
    ('giulia', 'Giulia Rossi', 'giulia@example.com')
ON CONFLICT (username) DO NOTHING;

INSERT INTO forum.categories (title, description) VALUES
    ('General', 'General discussion')
ON CONFLICT DO NOTHING;

INSERT INTO forum.posts (author, title, body)
SELECT pk, 'Hello from ' || username, 'My first post.'
FROM forum.users
ON CONFLICT DO NOTHING;

-- luca and giulia need ordinary table-level privileges to touch
-- anything at all — RLS in Section 6 filters ROWS, it never replaces
-- the base GRANT/REVOKE privilege system covered in Sections 2-4.
GRANT USAGE ON SCHEMA forum TO luca, giulia, forum_stats;
GRANT SELECT, INSERT, UPDATE, DELETE ON forum.users, forum.posts, forum.categories
    TO luca, giulia;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA forum TO luca, giulia;


-- =====================================================================
-- SECTION 2 — PRIVILEGES ON ROUTINES (FUNCTIONS & PROCEDURES)
-- =====================================================================
-- A "routine" is PostgreSQL's umbrella term (since v11) covering both
-- FUNCTIONs and PROCEDUREs. The only privilege that applies to a
-- routine is EXECUTE — the right to call it.
--
-- By default, EXECUTE on a newly created function is granted to
-- PUBLIC automatically. In security-conscious setups this is usually
-- revoked immediately and re-granted only to the roles that need it.
--
-- `ALL ROUTINES IN SCHEMA <schema>` (v11+) lets you grant/revoke on
-- every function and procedure in a schema in one statement, instead
-- of naming each one (and its argument list) individually.

-- --- As it appears in the source material ---------------------------
-- The original notes show this fragment (introduced by "as user
-- forum"), but the TO-clause was cut off in the source — as written
-- it is not valid, executable SQL:
--
--   forumdb=> GRANT EXECUTE ON ALL ROUTINES IN SCHEMA forum;
--
-- ----------------------------------------------------------------

-- Working, complete version of the same idea: let the reporting role
-- forum_stats call every routine currently defined in forum.*.
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA forum TO forum_stats;

-- You can just as easily target a single routine by signature:
GRANT EXECUTE ON FUNCTION forum.get_max(text) TO giulia;

-- And revoke the automatic PUBLIC grant that new functions receive
-- by default, so only roles you explicitly name can call it:
REVOKE EXECUTE ON FUNCTION forum.get_max(text) FROM PUBLIC;

-- Quick check: giulia can now call it, forum_stats can too (via the
-- schema-wide grant), but nobody else outside those roles can.
SET ROLE giulia;
SELECT forum.get_max('categories');   -- works: returns the current max pk
RESET ROLE;


-- =====================================================================
-- SECTION 3 — PRIVILEGES ON DATABASES
-- =====================================================================
-- Database-level privileges answer one question first: "is this role
-- even allowed to open a connection to this database?" (CONNECT), and
-- second: "can it create new schemas/objects inside it?" (CREATE).
--
-- General syntax:
--   GRANT  <permission> ON DATABASE <database> TO   <role>;
--   REVOKE <permission> ON DATABASE <database> FROM <role>;
--
-- Common <permission> values for a database: CONNECT, CREATE, TEMP
-- (temporary tables), and ALL [PRIVILEGES].

-- By default PostgreSQL grants CONNECT on every new database to the
-- PUBLIC pseudo-role, meaning "everybody can connect unless told
-- otherwise". Revoking it from PUBLIC is the standard way to lock a
-- database down to an explicit allow-list of roles.
REVOKE CONNECT ON DATABASE forumdb FROM PUBLIC;

-- After the REVOKE above, any role that was relying on the PUBLIC
-- grant (and has no explicit CONNECT grant of its own) is locked out.
-- This is exactly what the source material shows happening from a
-- separate terminal, as a shell session (not SQL, so shown as a
-- comment/transcript rather than executable code):
--
--   $ psql -U luca forumdb
--   psql: error: could not connect to server: FATAL: permission denied for database "forumdb"
--   DETAIL: User does not have CONNECT privilege.
--
-- This happens even for a role like luca that owns other objects in
-- the database, because CONNECT is checked before anything else.

-- REVOKE ALL strips every database-level privilege from PUBLIC at
-- once (CONNECT, CREATE, TEMP) — a stricter, one-line version of the
-- REVOKE CONNECT above.
REVOKE ALL ON DATABASE forumdb FROM PUBLIC;

-- Now re-open the door, explicitly, only for luca: the right to
-- connect, and the right to create new objects (schemas, etc.).
GRANT CONNECT, CREATE ON DATABASE forumdb TO luca;

-- For our demo roles to keep working for the rest of this script,
-- give them CONNECT explicitly too (extra example beyond the source
-- material, so Sections 5-6 remain runnable):
GRANT CONNECT ON DATABASE forumdb TO forum, forum_stats, giulia;


-- =====================================================================
-- SECTION 4 — OBJECT OWNERSHIP
-- =====================================================================
-- Every object (table, view, function, sequence, schema, database...)
-- has exactly one owner. The owner implicitly holds every privilege
-- on that object and can grant privileges on it to others, delegate
-- ownership, or drop it outright — regardless of any GRANT statement.
--
-- Syntax:
--   ALTER <object-type> <object-name> OWNER TO <role>;

-- Hand ownership of the categories table over to luca:
ALTER TABLE forum.categories OWNER TO luca;

-- The same pattern applies to routines. Historically you would write:
--   ALTER FUNCTION get_max OWNER TO luca;
-- ...but a single-argument function still needs its argument types if
-- you use ALTER FUNCTION with an ambiguous name. Since PostgreSQL 11,
-- ALTER ROUTINE is the version-agnostic spelling that works whether
-- the object turns out to be a FUNCTION or a PROCEDURE, and — for an
-- unambiguous name like get_max(text) — you can even omit the
-- argument list:
ALTER ROUTINE forum.get_max OWNER TO luca;

-- Note: ALTER ROUTINE only works when the name is unambiguous (one
-- matching routine). If you had overloaded get_max(text) and
-- get_max(text, text), you would need to disambiguate:
--   ALTER ROUTINE forum.get_max(text) OWNER TO luca;


-- =====================================================================
-- SECTION 5 — INSPECTING ACCESS CONTROL LISTS (ACLs)
-- =====================================================================
-- Every grantable object stores its privileges as an ACL (Access
-- Control List): an array of entries like `grantee=privileges/grantor`.
-- There are three common ways to read it.

-- ---------------------------------------------------------------
-- 5.1 The easy way: \dp (a psql meta-command, short for \z)
-- ---------------------------------------------------------------
-- First, set up the exact scenario shown in the source notes: give
-- role "forum" full privileges on the users table, and give
-- forum_stats UPDATE on a single column (gecos) only.
GRANT ALL ON forum.users TO forum;
GRANT UPDATE (gecos) ON forum.users TO forum_stats;

\dp forum.users

-- Illustrative output (yours will differ slightly based on the exact
-- grants run above), matching the shape shown in the source material:
--
--  Access privileges
-- Schema | Name  | Type  | Access privileges     | Column privileges     | Policies
-- -------+-------+-------+------------------------+------------------------+----------
-- forum  | users | table | forum=arwdDxt/forum    | gecos: +              |
--        |       |       |                        |  forum_stats=w/forum  |
-- (1 row)
--
-- Reading an ACL entry like  forum=arwdDxt/forum :
--   - "forum"    (before the =)  is the GRANTEE
--   - "arwdDxt"  (between = and /) is the set of privileges granted
--   - "forum"    (after the /)   is the GRANTOR (who granted it)
--
-- Privilege letters (the ones that apply to TABLES):
--   r = SELECT       a = INSERT        w = UPDATE
--   d = DELETE        D = TRUNCATE      x = REFERENCES
--   t = TRIGGER
-- (Other object types use other letters, e.g. X = EXECUTE for
-- routines, U = USAGE for schemas/sequences/types, C = CREATE, and
-- c = CONNECT / T = TEMPORARY for databases.)
--
-- Column privileges are shown separately: "gecos: forum_stats=w/forum"
-- means role forum_stats was granted UPDATE (w) on just the gecos
-- column, by forum.

-- ---------------------------------------------------------------
-- 5.2 The raw way: query pg_class.relacl directly
-- ---------------------------------------------------------------
-- \dp is really just a friendly wrapper around this system catalog
-- column. relacl stores the same ACL array shown above, unparsed.
SELECT relname, relacl
FROM pg_class
WHERE relname = 'users';

-- Expected shape:
--  relname |          relacl
-- ---------+----------------------------
--  users   | {forum=arwdDxt/forum, forum_stats=w/forum}

-- ---------------------------------------------------------------
-- 5.3 The queryable way: aclexplode()
-- ---------------------------------------------------------------
-- relacl is a single array value, which is inconvenient to filter or
-- join on. aclexplode() unnests it into one row per (grantor,
-- grantee, privilege) triple, so you can query it like any other
-- table — perfect for an auditing report.
WITH acl AS (
    SELECT relname,
           (aclexplode(relacl)).grantor,
           (aclexplode(relacl)).grantee,
           (aclexplode(relacl)).privilege_type
    FROM pg_class
)
SELECT g.rolname  AS grantee,
       acl.privilege_type AS permission,
       gg.rolname AS grantor
FROM acl
JOIN pg_roles g  ON g.oid = acl.grantee
JOIN pg_roles gg ON gg.oid = acl.grantor
WHERE acl.relname = 'users';

-- Expected shape (order may vary):
--  grantee | permission | grantor
-- ---------+------------+---------
--  forum   | INSERT     | forum
--  forum   | SELECT     | forum
--  forum   | UPDATE     | forum
--  forum   | DELETE     | forum
--  forum   | TRUNCATE   | forum
--  forum   | REFERENCES | forum
--  forum   | TRIGGER    | forum

-- Extra example: the same query, but scoped to every table in the
-- forum schema at once — a one-shot "who can do what" audit report.
WITH acl AS (
    SELECT c.relname,
           n.nspname,
           (aclexplode(c.relacl)).grantor,
           (aclexplode(c.relacl)).grantee,
           (aclexplode(c.relacl)).privilege_type
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'forum' AND c.relkind = 'r'   -- 'r' = ordinary table
)
SELECT relname, g.rolname AS grantee, privilege_type
FROM acl
JOIN pg_roles g ON g.oid = acl.grantee
ORDER BY relname, grantee, privilege_type;


-- =====================================================================
-- SECTION 6 — ROW-LEVEL SECURITY (RLS)
-- =====================================================================
-- GRANT/REVOKE control access at the level of a whole table or column.
-- Row-Level Security goes one level deeper: it controls which
-- individual ROWS a role is allowed to see or modify, by attaching a
-- boolean filter (a "policy") to the table.
--
-- General syntax:
--   CREATE POLICY <name>
--       ON <table>
--       FOR <statement>              -- SELECT | INSERT | UPDATE | DELETE | ALL
--       TO <role>                    -- optional; defaults to PUBLIC
--       USING <filtering condition>       -- applied to existing rows (read side)
--       WITH CHECK <writing condition>;   -- applied to new/changed rows (write side)
--
-- RLS only takes effect once you turn it on for the table (it is off
-- by default, even if policies exist).

-- ---------------------------------------------------------------
-- 6.1 A basic SELECT policy
-- ---------------------------------------------------------------
-- Idea: a user should only see posts they themselves authored. We
-- match the connected role's name (CURRENT_ROLE) against
-- forum.users.username, then compare that user's pk to posts.author.
CREATE POLICY show_only_my_posts
    ON forum.posts
    FOR SELECT
    USING ( author = ( SELECT pk FROM forum.users
                        WHERE username = CURRENT_ROLE ) );

-- Policies are inert until RLS is switched on for the table:
ALTER TABLE forum.posts ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------
-- 6.2 A FOR ALL policy with both USING and WITH CHECK
-- ---------------------------------------------------------------
-- FOR ALL applies to SELECT, INSERT, UPDATE, and DELETE together.
-- Here, USING controls which existing rows a user may act on, and
-- WITH CHECK additionally restricts what values a write is allowed
-- to leave behind — in this case, a post may only be edited if it is
-- the caller's own post, AND the edit is happening within 1 day of
-- its last_edited_on timestamp (a simple "no editing stale posts"
-- rule).
CREATE POLICY manage_only_my_posts
    ON forum.posts
    FOR ALL
    USING ( author = ( SELECT pk FROM forum.users
                        WHERE username = CURRENT_ROLE ) )
    WITH CHECK ( author = ( SELECT pk FROM forum.users
                             WHERE username = CURRENT_ROLE )
                 AND
                 last_edited_on + '1 day'::interval >= CURRENT_TIMESTAMP );

-- ---------------------------------------------------------------
-- 6.3 How RLS shows up in query plans
-- ---------------------------------------------------------------
-- The planner folds the policy's USING condition into the query as
-- an ordinary filter, so it can use indexes normally — RLS is not a
-- slow, bolted-on afterthought, it participates in planning.
SET ROLE giulia;
EXPLAIN SELECT * FROM forum.posts;
RESET ROLE;

-- Expected shape (matches the source material): the plan shows a
-- Seq Scan on posts filtered by "author = $0", where $0 is computed
-- once up front by an InitPlan that does an index lookup on
-- users_username_key:
--
--  Seq Scan on posts (cost=8.17..76.17 rows=1000 width=74)
--    Filter: (author = $0)
--    InitPlan 1 (returns $0)
--      -> Index Scan using users_username_key on users
--           Index Cond: (username = (CURRENT_ROLE)::text)

-- ---------------------------------------------------------------
-- 6.4 RLS enforcement on writes
-- ---------------------------------------------------------------
-- Because manage_only_my_posts' WITH CHECK requires the edit to
-- happen within 1 day of last_edited_on, an UPDATE that tries to
-- push the timestamp two weeks into the past fails outright:
SET ROLE giulia;
DO $$
BEGIN
    UPDATE forum.posts
    SET last_edited_on = last_edited_on - '2 weeks'::interval
    WHERE author = (SELECT pk FROM forum.users WHERE username = 'giulia');
EXCEPTION
    WHEN insufficient_privilege OR check_violation THEN
        RAISE NOTICE 'Blocked by RLS, as expected: %', SQLERRM;
END
$$;
RESET ROLE;

-- Run without the DO/EXCEPTION wrapper, this is the raw error the
-- source material shows:
--
--   UPDATE posts
--   SET last_edited_on = last_edited_on - '2 weeks'::interval;
--   ERROR: new row violates row-level security policy for table "posts"

-- ---------------------------------------------------------------
-- 6.5 Viewing policies with \dp
-- ---------------------------------------------------------------
\dp forum.posts

-- Expected shape — \dp now has a Policies column listing each
-- policy's USING (u) and WITH CHECK (c) clauses:
--
--  Access privileges
-- ... | Policies
-- ----+---------------------------------------------------------------
--     | show_only_my_posts (r):
--     |   (u): (author = ( SELECT users.pk FROM users
--     |          WHERE (users.username = (CURRENT_ROLE)::text)))
--     | manage_only_my_posts:
--     |   (u): (author = ( SELECT users.pk FROM users
--     |          WHERE (users.username = (CURRENT_ROLE)::text)))
--     |   (c): ((author = ( SELECT users.pk FROM users
--     |          WHERE (users.username = (CURRENT_ROLE)::text)))
--     |          AND ((last_edited_on + '1 day'::interval) >= CURRENT_TIMESTAMP))

-- ---------------------------------------------------------------
-- 6.6 Toggling RLS on and off
-- ---------------------------------------------------------------
-- Disabling RLS does NOT drop the policies — it just stops enforcing
-- them, which is handy for maintenance/admin work as the table owner.
ALTER TABLE forum.posts DISABLE ROW LEVEL SECURITY;

-- ...and re-enable it:
ALTER TABLE forum.posts ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------
-- 6.7 PERMISSIVE vs RESTRICTIVE policies
-- ---------------------------------------------------------------
-- Every policy is PERMISSIVE by default: for a given command,
-- PostgreSQL evaluates ALL permissive policies and OR's them
-- together — a row is visible if ANY permissive policy allows it.
--
-- A RESTRICTIVE policy works the opposite way: it is AND'ed with the
-- combined permissive result, narrowing access further. Restrictive
-- policies are additive constraints, not standalone permission
-- grants — you still need at least one permissive policy (or the
-- table-owner bypass) for any row to be visible at all.
DROP POLICY show_only_my_posts ON forum.posts;

CREATE POLICY show_only_my_posts
    ON forum.posts
    AS restrictive
    FOR SELECT
    USING ( author = ( SELECT pk FROM forum.users
                        WHERE username = CURRENT_ROLE ) );

-- Extra example beyond the source material: combining a broad
-- permissive policy with a narrow restrictive one. Say every user
-- may see any post in the "General" category (permissive), but a
-- restrictive policy still blocks anyone from seeing DELETED posts
-- (imagine a `deleted boolean` column) even if some other permissive
-- policy would otherwise allow it:
--
--   CREATE POLICY see_general_category
--       ON forum.posts FOR SELECT
--       USING ( EXISTS (SELECT 1 FROM forum.categories
--                        WHERE title = 'General') );   -- permissive
--
--   CREATE POLICY hide_deleted
--       ON forum.posts AS restrictive FOR SELECT
--       USING ( NOT deleted );                          -- restrictive
--
-- Net effect: (show_only_my_posts OR see_general_category) AND hide_deleted

-- Extra example: FORCE ROW LEVEL SECURITY. By default, the table
-- OWNER bypasses RLS entirely (so admins don't lock themselves out).
-- FORCE makes RLS apply even to the owner (superusers still bypass
-- it regardless):
--   ALTER TABLE forum.posts FORCE ROW LEVEL SECURITY;
--   ALTER TABLE forum.posts NO FORCE ROW LEVEL SECURITY;  -- to undo


-- =====================================================================
-- SECTION 7 — ROLE PASSWORD ENCRYPTION
-- =====================================================================
-- PostgreSQL never stores a role's password in plain text. The
-- `password_encryption` setting controls the hashing scheme used
-- whenever a password is set via CREATE ROLE ... PASSWORD or
-- ALTER ROLE ... PASSWORD.
SHOW password_encryption;

-- Expected output (the modern, recommended default since PG14):
--  password_encryption
-- ----------------------
--  scram-sha-256
-- (1 row)

-- scram-sha-256 replaced the older, weaker "md5" scheme. SCRAM:
--   - never transmits the password (or a simple hash of it) over the
--     wire during authentication — it uses a challenge/response
--     protocol instead;
--   - is resistant to replay attacks in a way plain md5 is not.
--
-- Setting a password always re-hashes using whatever
-- password_encryption is set to AT THAT MOMENT:
ALTER ROLE giulia PASSWORD 'ChangeMe_giulia_456';

-- You can inspect (but never reverse) the stored hash:
SELECT rolname, rolpassword
FROM pg_authid
WHERE rolname = 'giulia';
-- rolpassword will look like: SCRAM-SHA-256$4096:<salt>$<StoredKey>:<ServerKey>
-- — a verifier, not the password itself.


-- =====================================================================
-- SECTION 8 — SSL/TLS CONNECTIONS
-- =====================================================================
-- SSL is configured at the CLUSTER level (postgresql.conf) and at the
-- CONNECTION-RULE level (pg_hba.conf), not with SQL statements — so
-- this section is mostly documentation/comments rather than runnable
-- code, exactly as it appears conceptually in the source material.

-- ---------------------------------------------------------------
-- 8.1 Enabling SSL on the cluster (postgresql.conf)
-- ---------------------------------------------------------------
-- Add/edit these lines in postgresql.conf, then restart the cluster.
-- (Not SQL — edited directly in the config file, e.g. with nano.)
--
--   ssl = on
--   ssl_key_file  = '/postgres/16/data/ssl/server.key'
--   ssl_cert_file = '/postgres/16/data/ssl/server.crt'
--
-- In Termux, a self-signed cert/key pair for testing can be generated
-- with openssl, then referenced by these two paths. `ssl = on` alone
-- does nothing without a valid cert/key pair in place.

-- ---------------------------------------------------------------
-- 8.2 Requiring SSL for specific roles/hosts (pg_hba.conf)
-- ---------------------------------------------------------------
-- Each pg_hba.conf line has 5 fields: TYPE  DATABASE  USER  ADDRESS  METHOD
-- The line type "hostssl" matches only connections made over SSL,
-- rejecting plain-text ones outright.
--
--   hostssl all luca  venkman          scram-sha-256
--   hostssl all forum 192.168.222.1/32 scram-sha-256
--
-- Reading the first line column by column:
--   TYPE=hostssl  DATABASE=all  USER=luca  ADDRESS=venkman  METHOD=scram-sha-256
-- Here ADDRESS is the HOSTNAME "venkman" (PostgreSQL can match by
-- resolvable hostname, not only by CIDR block) — this line says
-- "role luca, connecting over SSL specifically from the host named
-- venkman, must authenticate with scram-sha-256".
-- The second line instead uses a CIDR address (192.168.222.1/32) for
-- role forum.

-- ---------------------------------------------------------------
-- 8.3 Connecting over SSL (client side)
-- ---------------------------------------------------------------
-- These are shell/psql client sessions, not SQL — reproduced as
-- comments to preserve the source transcript exactly.
--
--   $ psql "postgresql://forum@localhost:5432/forumdb?sslmode=require"
--   psql (16.0)
--   SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
--   Type "help" for help.
--   forumdb=>
--
--   $ psql -h localhost -U forum forumdb
--   psql (16.0)
--   SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
--   ...
--   forumdb=> \q
--
--   $ psql "postgresql://forum@localhost:5432/forumdb"
--   psql (16.0)
--   SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
--   ...
--
-- Note: even without an explicit sslmode, the connection still
-- negotiates SSL here because pg_hba.conf's "hostssl" line makes it
-- mandatory for this user/host combination — the client doesn't get
-- to opt out.

-- Two common failure modes, also preserved as comments:
--
--   $ psql "postgresql://forum@localhost:5432/forumdb?sslmode=require"
--   psql: error: could not connect to server: FATAL: no pg_hba.conf entry for host "127.0.0.1", user "forum"
--   -- Meaning: no matching line in pg_hba.conf covers this exact
--   -- (database, user, address, SSL-or-not) combination at all.
--
--   $ psql "postgresql://forum@localhost:5432/forumdb?sslmode=disable"
--   psql: error: could not connect to server: server does not support SSL, but SSL was required
--   -- Meaning: the client explicitly asked to disable SSL, but the
--   -- matching pg_hba.conf line is "hostssl", which refuses any
--   -- non-SSL connection outright.

-- ---------------------------------------------------------------
-- 8.4 Verifying SSL from inside SQL (extra, runnable)
-- ---------------------------------------------------------------
-- Once connected, these ARE ordinary runnable SQL/psql commands you
-- can use to confirm whether the current session is using SSL:
SHOW ssl;

SELECT pid, ssl, version AS tls_version, cipher
FROM pg_stat_ssl
WHERE pid = pg_backend_pid();


-- =====================================================================
-- SECTION 9 — SUMMARY / QUICK REFERENCE
-- =====================================================================
-- * Database access: PUBLIC gets CONNECT by default — REVOKE it to
--   turn a database into an explicit allow-list.
-- * Routine access: EXECUTE is the only routine privilege; grant it
--   per-function or, since v11, on ALL ROUTINES IN SCHEMA <schema>.
-- * Ownership: ALTER <object-type> ... OWNER TO <role>; owners always
--   bypass GRANT/REVOKE checks on their own objects (but not RLS
--   unless FORCE ROW LEVEL SECURITY is set).
-- * Inspect ACLs three ways: \dp (friendly), pg_class.relacl (raw
--   array), aclexplode(relacl) (queryable rows) — an ACL entry reads
--   grantee=privileges/grantor.
-- * Row-Level Security filters ROWS, on top of ordinary table grants:
--     - OFF by default even with policies defined -> ENABLE it.
--     - PERMISSIVE policies (default) OR together.
--     - RESTRICTIVE policies (AS RESTRICTIVE) AND against that result.
--     - USING = read-side filter; WITH CHECK = write-side filter.
--     - Table owners bypass RLS unless FORCE ROW LEVEL SECURITY is set.
-- * Passwords are always stored hashed; scram-sha-256 is the modern
--   default, replacing the weaker md5 scheme.
-- * SSL is configured cluster-wide (postgresql.conf: ssl, ssl_cert_file,
--   ssl_key_file) and enforced per-connection-rule (pg_hba.conf:
--   "hostssl" lines, whose ADDRESS field may be a CIDR block or a
--   resolvable hostname).
-- =====================================================================
