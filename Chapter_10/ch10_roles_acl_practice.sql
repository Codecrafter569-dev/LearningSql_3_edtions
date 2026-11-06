-- ============================================================================
--  PostgreSQL Chapter 10 -- Users, Roles & Security -- PRACTICE SCRIPT
--
--  HOW TO RUN (Termux):
--    1) Make sure your cluster is running, e.g.:
--         pg_ctl -D ~/postgres-data -l ~/postgres-data/logfile start
--    2) Find your superuser role name if you're not sure:
--         whoami
--    3) Run this whole script:
--         psql -U <your_superuser> -d postgres -f ch10_roles_acl_practice.sql
--
--  This script NEVER hardcodes a superuser name anywhere. It uses
--  SET ROLE / RESET ROLE to "become" other roles for testing, and
--  RESET ROLE always safely returns you to whichever user you used
--  with -U above. Nothing here requires you to know your superuser's
--  exact name beyond that one -U flag.
--
--  Passwords below ('practice123') are throwaway, for local learning
--  only -- never reuse them anywhere real.
-- ============================================================================

\echo '=== STEP 0: fresh practice database ==='
-- WARNING: this drops any existing database named forumdb_ch10.
DROP DATABASE IF EXISTS forumdb_ch10;
CREATE DATABASE forumdb_ch10;
\c forumdb_ch10

\echo '=== STEP 1: sample schema + table (mirrors the book) ==='
CREATE SCHEMA forum;

CREATE TABLE forum.users (
    pk       SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    gecos    TEXT,
    email    TEXT
);

INSERT INTO forum.users (username, gecos, email) VALUES
  ('fluca1978', 'Luca Ferrari',   'fluca1978@example.com'),
  ('sscotty71', 'Enrico Pirozzi', 'sscotty71@example.com');

SELECT * FROM forum.users;

\echo '=== STEP 2: create plain login roles ==='
DROP ROLE IF EXISTS luca;
DROP ROLE IF EXISTS enrico;
DROP ROLE IF EXISTS test;
CREATE ROLE luca   LOGIN PASSWORD 'practice123';
CREATE ROLE enrico LOGIN PASSWORD 'practice123';
CREATE ROLE test   LOGIN PASSWORD 'practice123';
\du luca enrico test

\echo '=== STEP 3: role properties via ALTER ROLE ==='
ALTER ROLE luca WITH CREATEDB;
ALTER ROLE luca WITH CREATEROLE;
SELECT rolname, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname = 'luca';

-- combined syntax = same effect as the two lines above
ALTER ROLE luca CREATEROLE CREATEDB;

-- now take both back
ALTER ROLE luca NOCREATEROLE NOCREATEDB;
SELECT rolname, rolcreatedb, rolcreaterole FROM pg_roles WHERE rolname = 'luca';

\echo '=== STEP 3b: connection limit property ==='
ALTER ROLE luca CONNECTION LIMIT 1;
SELECT rolname, rolconnlimit FROM pg_roles WHERE rolname = 'luca';

\echo '=== STEP 4: renaming a role ==='
ALTER ROLE luca RENAME TO fluca1978;
\du fluca1978
ALTER ROLE fluca1978 RENAME TO luca;
\du luca

\echo '=== STEP 5: per-role auto-config on connect ==='
-- IMPORTANT: this setting only fires on a genuine NEW connection made as
-- luca. SET ROLE (used elsewhere in this script) does NOT start a new
-- session, so it will NOT trigger this -- that is why we verify it by
-- hand below instead of with SET ROLE.
ALTER ROLE luca IN DATABASE forumdb_ch10 SET client_min_messages TO 'DEBUG';
SELECT rolname, rolconfig FROM pg_roles WHERE rolname = 'luca';   -- rolconfig now shows the setting
-- To see it actually fire, open a second Termux session and run:
--   psql -U luca -d forumdb_ch10          (password: practice123)
--   SHOW client_min_messages;             -- shows: debug
ALTER ROLE luca IN DATABASE forumdb_ch10 RESET ALL;
SELECT rolname, rolconfig FROM pg_roles WHERE rolname = 'luca';   -- rolconfig back to empty

\echo '=== STEP 6: group roles + privilege setup ==='
DROP ROLE IF EXISTS forum_admins;
DROP ROLE IF EXISTS forum_stats;
CREATE ROLE forum_admins WITH NOLOGIN;
CREATE ROLE forum_stats  WITH NOLOGIN;

-- good habit: revoke everything first so grants below are exactly what we intend
REVOKE ALL ON forum.users FROM forum_stats;
REVOKE ALL ON forum.users FROM forum_admins;

GRANT ALL ON SCHEMA forum TO forum_admins;
GRANT USAGE ON SCHEMA forum TO forum_stats;

GRANT ALL ON forum.users TO forum_admins;
GRANT SELECT (username, gecos) ON forum.users TO forum_stats;

GRANT forum_admins TO enrico;
GRANT forum_stats  TO luca;
GRANT forum_stats  TO test;

\echo '=== STEP 7: enrico -> full access via forum_admins (inherited automatically) ==='
SET ROLE enrico;
SELECT * FROM forum.users;
UPDATE forum.users SET gecos = upper(gecos);
SELECT * FROM forum.users;
RESET ROLE;

\echo '=== STEP 8: luca -> restricted columns via forum_stats ==='
SET ROLE luca;
SELECT * FROM forum.users;                    -- expect: permission denied
SELECT username, gecos FROM forum.users;      -- expect: works
UPDATE forum.users SET gecos = lower(gecos);  -- expect: permission denied
RESET ROLE;

\echo '=== STEP 9: an explicit grant overrides the group restriction ==='
GRANT SELECT ON forum.users TO luca;
SET ROLE luca;
SELECT * FROM forum.users;   -- now works: luca's own grant wins
RESET ROLE;

\echo '=== STEP 10: a NOINHERIT group needs SET ROLE to actually use ==='
REVOKE SELECT ON forum.users FROM luca;
DROP ROLE IF EXISTS forum_emails;
CREATE ROLE forum_emails WITH NOLOGIN NOINHERIT;
GRANT USAGE ON SCHEMA forum TO forum_emails;
GRANT SELECT (email) ON forum.users TO forum_emails;

-- WITH INHERIT omitted here -> defaults to forum_emails's OWN property (NOINHERIT)
GRANT forum_emails TO forum_stats;

SET ROLE luca;
SELECT current_role;
SELECT username, gecos, email FROM forum.users;  -- expect: permission denied (email not inherited)
SET ROLE forum_emails;
SELECT current_role;
SELECT email FROM forum.users;   -- expect: works
SELECT gecos FROM forum.users;   -- expect: permission denied (forum_emails has no gecos grant)
RESET ROLE;

\echo '=== STEP 11: WITH INHERIT true makes it automatic ==='
GRANT forum_emails TO forum_stats WITH INHERIT true;
SET ROLE luca;
SELECT gecos, username, email FROM forum.users;  -- all three now work, no SET ROLE needed
RESET ROLE;

\echo '=== STEP 12: SESSION_USER vs CURRENT_USER ==='
SELECT session_user, current_user;
SET ROLE forum_stats;
SELECT session_user, current_user;   -- session_user unchanged, current_user changed
RESET ROLE;
-- To see SESSION_USER itself change, open a second Termux session and run:
--   psql -U luca -d forumdb_ch10          (password: practice123)
--   SELECT session_user, current_user;
--   SET ROLE forum_stats;
--   SELECT session_user, current_user;

\echo '=== STEP 13: inspecting roles ==='
\du
\x
SELECT * FROM pg_roles WHERE rolname = 'luca';
\x
SELECT r.rolname AS member, g.rolname AS group_role, m.admin_option
FROM pg_auth_members m
JOIN pg_roles r ON r.oid = m.member
JOIN pg_roles g ON g.oid = m.roleid
ORDER BY r.rolname;

-- pg_authid is superuser-only -- this works here because we are NOT SET ROLE'd right now
SELECT rolname, rolpassword FROM pg_authid WHERE rolname = 'luca';

\echo '=== STEP 14: reading raw ACLs ==='
\dp forum.users
SELECT relacl FROM pg_class WHERE relname = 'users';

\echo '=== DONE ==='
\echo 'Clean up any time with: DROP DATABASE forumdb_ch10;'
