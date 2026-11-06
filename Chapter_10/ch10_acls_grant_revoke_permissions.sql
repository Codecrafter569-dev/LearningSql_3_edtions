-- ============================================================================
-- LEARN POSTGRESQL, 2ND EDITION -- CHAPTER 10: USERS, ROLES & DATABASE SECURITY
-- TOPIC       : Access Control Lists (ACLs), GRANT, REVOKE, and Permissions
-- ENVIRONMENT : PostgreSQL 18.2, Termux (aarch64), trust auth, locale C
-- HOW TO RUN  : psql -U <superuser> -d postgres -f ch10_acls_grant_revoke_permissions.sql
--               (or paste section by section into an interactive psql session)
--
-- TABLE OF CONTENTS
--   1.  Environment setup (roles, database, schema, tables, seed data)
--   2.  ACL notation -- how to read an ACL string
--   3.  Reading real ACLs with \dp -- the categories table walkthrough
--   4.  Default ACLs -- what happens with NO explicit GRANT/REVOKE
--   5.  GRANT/REVOKE are additive -- REVOKE only removes what was granted
--   6.  The acldefault() function
--   7.  GRANT / REVOKE general syntax, WITH GRANT OPTION, the PUBLIC pseudo-role
--   8.  Table-level permissions
--   9.  Column-level permissions (and the conflicts they can create)
--   10. Sequence permissions (USAGE / SELECT / UPDATE)
--   11. Schema permissions (CREATE vs USAGE)
--   12. Bulk permissions with ALL ... IN SCHEMA
--   13. Language permissions (plperl / USAGE)
--   14. Routine (function/procedure) permissions (EXECUTE)
--   15. Optional cleanup
--
-- NOTE ON PREREQUISITES: Section 1 must run while connected as a PostgreSQL
-- superuser (in a fresh Termux cluster with trust auth this is typically the
-- OS user that ran `initdb` -- check with `whoami`). Every later section
-- reconnects with \c as whichever role the example needs, exactly like the
-- book's "as user 'X'" annotations, so the file is fully self-contained and
-- runnable top to bottom.
-- ============================================================================


-- ============================================================================
-- SECTION 1: ENVIRONMENT SETUP
-- ============================================================================
-- We need the cast of roles and objects the rest of the chapter refers to:
--   forum        -> owns the database/schema/tables (the "admin" role)
--   luca         -> a regular application role
--   enrico       -> a second regular application role
--   forum_stats  -> a reporting role with narrow, specific permissions
--   forum_emails -> a role that is only ever allowed to read the email column
-- CREATE ROLE ... LOGIN lets the role open its own psql session; under trust
-- authentication no password is required locally.

CREATE ROLE forum        LOGIN CREATEDB;
CREATE ROLE luca         LOGIN;
CREATE ROLE enrico       LOGIN;
CREATE ROLE forum_stats  LOGIN;
CREATE ROLE forum_emails LOGIN;

-- Create the database, owned by forum (so forum's ACL entries look like
-- "forum=.../forum" everywhere an owner default applies).
CREATE DATABASE forumdb OWNER forum;

-- Reconnect to the new database AS the forum role, since forum must be the
-- one creating the schema/tables for the owner-based examples to make sense.
\c forumdb forum

-- A dedicated schema (rather than "public") mirrors the book's forumdb.
CREATE SCHEMA IF NOT EXISTS forum AUTHORIZATION forum;

-- Make unqualified table/sequence/function names resolve into the forum
-- schema for the rest of THIS session. We repeat this SET after every
-- reconnect below so the unqualified names used later in the chapter
-- ("FROM users", "nextval('categories_pk_seq')", etc.) work as printed.
SET search_path TO forum, public;

-- categories: the table used throughout the ACL-decoding examples.
-- Naming the primary key column "pk" makes PostgreSQL auto-name its
-- sequence "categories_pk_seq" -- exactly the sequence name used later
-- in the sequence-permissions section.
CREATE TABLE forum.categories (
    pk          SERIAL PRIMARY KEY,
    title       text NOT NULL,
    description text
);

-- users: the table used in the column-level permission examples.
CREATE TABLE forum.users (
    pk       SERIAL PRIMARY KEY,
    username text UNIQUE NOT NULL,
    gecos    text,
    email    text
);

-- Seed data. gecos is uppercase here on purpose: the chapter later runs
-- `UPDATE forum.users SET gecos = lower(gecos)` and we want that step to
-- visibly change something, matching the book's before/after output.
INSERT INTO forum.users (username, gecos, email) VALUES
    ('fluca1978', 'LUCA FERRARI',   'fluca1978@gmail.com'),
    ('sscotty71', 'ENRICO PIROZZI', 'sscotty71@gmail.com');

-- IMPORTANT PREREQUISITE the book takes for granted from earlier chapters:
-- a role needs the USAGE privilege on a schema before ANY grant on an
-- object inside that schema means anything (Section 11 explains exactly
-- why). Without this, every GRANT below would be silently useless because
-- every SELECT/INSERT/etc. would fail with "permission denied for schema
-- forum" before PostgreSQL even looks at the table-level ACL.
GRANT USAGE ON SCHEMA forum TO luca, enrico, forum_stats, forum_emails;

-- forum_emails is a narrow reporting role that (per an earlier chapter's
-- setup, replicated here so this file is self-contained) is only ever
-- allowed to read the email column. We grant that now so the \dp output
-- in Section 9 matches the book exactly.
GRANT SELECT (email) ON forum.users TO forum_emails;


-- ============================================================================
-- SECTION 2: ACL NOTATION -- HOW TO READ AN ACL STRING
-- ============================================================================
-- PostgreSQL prints permissions as compact strings of the form:
--
--     grantee=flags/grantor
--
--   grantee -> the role the permissions apply to (empty = PUBLIC, i.e. every role)
--   flags   -> one letter per granted permission (see table below)
--   grantor -> the role that performed the GRANT
--
-- Reference table of ACL flag letters (this is the book's "Table 10.1",
-- reconstructed here since the source text only decodes it piecemeal):
--
--   Flag | Permission     | Applies to
--   -----+----------------+------------------------------------------
--    r   | SELECT (read)  | tables, views, sequences, columns
--    a   | INSERT(append) | tables, columns
--    w   | UPDATE (write) | tables, sequences, columns
--    d   | DELETE         | tables
--    D   | TRUNCATE       | tables
--    x   | REFERENCES     | tables, columns (needed to create FKs)
--    t   | TRIGGER        | tables
--    X   | EXECUTE        | functions, procedures (routines)
--    U   | USAGE          | sequences, schemas, types, domains,
--        |                | languages, foreign servers/wrappers
--    C   | CREATE         | schemas, databases, tablespaces
--    c   | CONNECT        | databases
--    T   | TEMPORARY      | databases (create temp objects)
--
-- Worked example:
--     luca=arw/enrico
--   - luca   -> the role BEFORE the "=" -> the ACL describes luca's permissions
--   - enrico -> the role AFTER the "/"  -> the role that GRANTed them
--   - arw    -> append, read, write     -> INSERT, SELECT, UPDATE
--   Reads as: "enrico granted luca the permission to INSERT, UPDATE and
--   SELECT on the table."
--
-- No query needed for this section -- it is pure notation. Section 3 shows
-- the notation produced by real GRANT statements against forum.categories.


-- ============================================================================
-- SECTION 3: READING REAL ACLs WITH \dp -- THE categories WALKTHROUGH
-- ============================================================================
-- \dp (or its synonym \z) is the psql meta-command that lists a relation's
-- ACLs. Right now categories has NO explicit ACL at all (see Section 4 for
-- why), so \dp shows blank Access privileges:
\dp forum.categories

-- Now reproduce the GRANT statements that produced the book's example ACL.
-- Statement 1 generates the ACL entry: luca=arw/forum
GRANT SELECT, UPDATE, INSERT
    ON forum.categories
    TO luca;

-- Statement 2 grants DELETE to the special PUBLIC pseudo-role, which means
-- "every role, present and future." This generates the ACL entry: =d/forum
-- (note there is NO name before the "=" -- that absence IS the PUBLIC marker).
GRANT DELETE ON forum.categories TO PUBLIC;

-- Inspect the result. Expected output (three ACL lines):
--   forum=arwdDxt/forum   -> the owner: grantee and grantor are both "forum",
--                            which is how you recognize an owner entry; the
--                            owner always implicitly has every permission
--                            (append, read, write, delete, truncate,
--                            trigger, cross-reference).
--   luca=arw/forum        -> "forum granted luca INSERT, UPDATE, SELECT."
--   =d/forum               -> "forum granted DELETE to every role (PUBLIC)."
\dp forum.categories

-- Reasoning exercise from the book: if luca issues DELETE FROM categories,
-- is it allowed? luca's own ACL (arw) does NOT include d, but the catch-all
-- PUBLIC ACL (=d/forum) grants DELETE to every role -- so yes, it succeeds.
-- Let's actually prove it by switching sessions.
\c forumdb luca
SET search_path TO forum, public;

-- Works: luca has no personal DELETE grant, but inherits it via PUBLIC.
DELETE FROM forum.categories WHERE pk = -1;   -- deletes 0 rows, but is PERMITTED

-- Fails: forum_stats has never been granted anything on categories yet.
\c forumdb forum_stats
SET search_path TO forum, public;
-- Expected: ERROR: permission denied for table categories
INSERT INTO forum.categories (title) VALUES ('should fail');

-- Back to the owner for the remaining sections.
\c forumdb forum
SET search_path TO forum, public;


-- ============================================================================
-- SECTION 4: DEFAULT ACLs -- WHAT HAPPENS WITH NO EXPLICIT GRANT/REVOKE
-- ============================================================================
-- Create a brand-new, untouched table and look at its ACL.
CREATE TABLE forum.perm_test (t text);

-- Expected: the Access privileges column is completely EMPTY. PostgreSQL
-- does not store an ACL row at all until the first GRANT or REVOKE touches
-- the object -- it just falls back to a set of implicit default rules:
--   * the OWNER of the object gets every applicable permission
--   * every other role gets whatever the special PUBLIC pseudo-role has
--     by default, which for most object types is deliberately minimal:
--       - EXECUTE (X) on routines
--       - CONNECT and TEMPORARY (cT) on databases
--       - USAGE (U) on languages, types, and domains
--     Notice TABLES and SEQUENCES are NOT in that list -- by default a
--     non-owner role can do nothing at all on a fresh table or sequence.
\dp forum.perm_test


-- ============================================================================
-- SECTION 5: GRANT/REVOKE ARE ADDITIVE -- REVOKE ONLY REMOVES WHAT WAS GRANTED
-- ============================================================================
-- The first GRANT (or REVOKE) against an object is also what causes
-- PostgreSQL to materialize the implicit owner ACL entry alongside it.
GRANT SELECT, INSERT, UPDATE, DELETE
    ON forum.perm_test
    TO enrico;

-- Expected: TWO ACL entries now appear --
--   forum=arwdDxt/forum   (the owner, materialized for the first time)
--   enrico=arwd/forum     (exactly what we just granted: r+a+w+d)
\dp forum.perm_test

-- Key lesson: ACLs record what IS granted, not what is withheld. Revoking
-- a permission a role never had changes nothing.
REVOKE TRUNCATE ON forum.perm_test FROM enrico;
-- Expected: enrico's ACL entry is UNCHANGED (still enrico=arwd/forum) --
-- enrico never had TRUNCATE (D), so there was nothing to remove.
\dp forum.perm_test

-- Revoking a permission from PUBLIC does not touch permissions a specific
-- role already holds in its own right -- ACLs are stored per-role.
REVOKE INSERT ON forum.perm_test FROM PUBLIC;
-- Expected: still no change to enrico's line -- enrico's INSERT (a) came
-- from an explicit personal GRANT, not from PUBLIC, so it is unaffected.
\dp forum.perm_test


-- ============================================================================
-- SECTION 6: THE acldefault() FUNCTION
-- ============================================================================
-- acldefault(object_type, owner_oid) returns the ACL PostgreSQL WOULD apply
-- to a brand-new object of that type, owned by that role, before any GRANT
-- or REVOKE is issued. Useful for inspecting defaults without creating an
-- object first. object_type is a single letter: 'r' = relation (table),
-- 'S' = sequence, 'f' = routine, 'n' = schema, 'l' = language, and more.

-- Default ACL for a new TABLE owned by the currently connected role (forum):
-- Expected: {forum=arwdDxt/forum} -- only the owner, with everything.
SELECT acldefault('r', r.oid)
FROM pg_roles r
WHERE r.rolname = CURRENT_ROLE;

-- Default ACL for a new ROUTINE (function/procedure) owned by forum:
-- Expected: {=X/forum,forum=X/forum} -- TWO entries this time: PUBLIC gets
-- EXECUTE by default (that "=X/forum" entry with no grantee name), and the
-- owner also explicitly has EXECUTE.
SELECT acldefault('f', r.oid)
FROM pg_roles r
WHERE r.rolname = CURRENT_ROLE;


-- ============================================================================
-- SECTION 7: GRANT / REVOKE SYNTAX, WITH GRANT OPTION, AND THE PUBLIC ROLE
-- ============================================================================
-- General shape of the two statements you have been using since Section 3:
--
--   GRANT  <permission, permission, ...> ON <object> TO   <role>;
--   REVOKE <permission, permission, ...> ON <object> FROM <role>;
--
-- Add WITH GRANT OPTION to let the grantee re-grant the same permissions to
-- someone else on your behalf:
GRANT SELECT ON forum.perm_test TO enrico WITH GRANT OPTION;
-- enrico can now do this successfully, because of the option above:
\c forumdb enrico
SET search_path TO forum, public;
GRANT SELECT ON forum.perm_test TO luca;
\c forumdb forum
SET search_path TO forum, public;

-- PUBLIC is not a real, storable role -- it is a keyword meaning "every
-- role that exists now AND every role created in the future." That is why
-- security-conscious setups typically start by stripping PUBLIC's default
-- privileges from an object, then adding back only what specific roles
-- need:
REVOKE ALL ON forum.perm_test FROM PUBLIC;

-- ALL is itself a shorthand meaning "every permission that applies to this
-- kind of object" -- you already used it above and will use it repeatedly
-- from here on as a clean way to reset a role's permissions before
-- re-granting exactly what you want.


-- ============================================================================
-- SECTION 8: TABLE-LEVEL PERMISSIONS
-- ============================================================================
-- The full set of table permissions maps to the SQL statements they gate:
-- SELECT, INSERT, UPDATE, DELETE, TRUNCATE, plus TRIGGER (create triggers)
-- and REFERENCES (create foreign keys pointing at this table). ALL covers
-- every one of them.
--
-- Good practice: REVOKE ALL first so you know EXACTLY what a role ends up
-- with, unaffected by any grant made earlier in the role's history.
REVOKE ALL ON forum.categories FROM forum_stats;

GRANT SELECT, INSERT, UPDATE
    ON forum.categories
    TO forum_stats;

-- Expected: forum_stats=arw/forum -- read, append, write, and nothing else
-- (no delete, no truncate, no trigger, no references).
\dp forum.categories


-- ============================================================================
-- SECTION 9: COLUMN-LEVEL PERMISSIONS
-- ============================================================================
-- Because SELECT, INSERT, UPDATE, and REFERENCES can all target individual
-- columns, GRANT/REVOKE accept an optional column list. (INSERT and
-- REFERENCES can technically take a column list too, though this example
-- follows the book and only exercises SELECT/UPDATE.)
--
-- Scenario: forum_stats should be able to read BOTH username and gecos,
-- but only UPDATE gecos.
REVOKE ALL ON forum.users FROM forum_stats;

GRANT SELECT (username, gecos),
      UPDATE (gecos)
    ON forum.users
    TO forum_stats;

-- Switch to forum_stats to prove the column restriction is enforced.
-- (The book's transcript shows `current_role` as luca at this point, which
-- does not match the role the GRANT above targets -- almost certainly a
-- transcription slip in the source text. To keep this script genuinely
-- correct and runnable, we test as the role that actually received the
-- grant: forum_stats.)
\c forumdb forum_stats
SET search_path TO forum, public;

-- Confirm which role this session is running as.
-- Expected: forum_stats
SELECT current_role;

-- Denied: SELECT * pulls every column, but forum_stats only has SELECT on
-- (username, gecos) -- pk and email are out of reach.
-- Expected: ERROR: permission denied for table users
SELECT * FROM forum.users;

-- Allowed: this SELECT only touches the two granted columns.
-- Expected: gecos values still uppercase at this point (LUCA FERRARI /
-- ENRICO PIROZZI), because the lower() UPDATE below hasn't run yet.
SELECT gecos, username FROM forum.users;

-- Denied: forum_stats has UPDATE only on gecos, not on username.
-- Expected: ERROR: permission denied for table users
UPDATE forum.users SET username = upper(username);

-- Allowed: gecos is exactly the column forum_stats was granted UPDATE on.
-- Expected: UPDATE 2
UPDATE forum.users SET gecos = lower(gecos);

\c forumdb forum
SET search_path TO forum, public;

-- Inspect the ACL now. Expected shape: the Access privileges column has NO
-- entry for forum_stats at all (column-scoped grants never appear there);
-- instead, the Column privileges column lists one line per restricted
-- column:
--   username: forum_stats=r/forum
--   gecos:    forum_stats=rw/forum
--   email:    forum_emails=r/forum   (from the Section 1 setup)
-- Rule of thumb: a role's permissions show up under Access privileges only
-- once they apply to ALL columns; anything narrower is filed under Column
-- privileges instead.
\dp forum.users

-- --- Creating (and then fixing) a permission CONFLICT ---
-- Suppose we mistakenly ALSO grant table-wide SELECT to forum_stats:
GRANT SELECT ON forum.users TO forum_stats;

-- Expected: now BOTH show up -- forum_stats=r/forum under Access
-- privileges AND the earlier column-scoped entries under Column
-- privileges.
\dp forum.users

-- Which one wins? PostgreSQL always applies the MOST PERMISSIVE grant it
-- can find. The table-wide grant is broader than the column-scoped one, so
-- it wins: forum_stats can now read every column, including pk and email.
\c forumdb forum_stats
SET search_path TO forum, public;
-- Expected: succeeds now, returning all 4 columns for both rows.
SELECT * FROM forum.users;
\c forumdb forum
SET search_path TO forum, public;

-- Trying to "fix" this by revoking just the extra columns does NOTHING,
-- because REVOKE only removes what was explicitly granted at that exact
-- scope -- there was never a column-scoped grant for pk or email to
-- revoke.
REVOKE SELECT (pk, email) ON forum.users FROM forum_stats;
-- Expected: \dp output is IDENTICAL to the previous \dp above -- no change.
\dp forum.users

-- The correct fix is to revoke at the SAME scope the mistaken grant was
-- made at -- i.e. the unqualified, table-wide REVOKE that matches the
-- table-wide GRANT:
REVOKE SELECT ON forum.users FROM forum_stats;
-- Expected side effect: this removes the table-wide grant back to nothing,
-- but ALSO wipes out the column-scoped SELECT grants on username and
-- gecos, because a bare REVOKE SELECT clears every SELECT-related entry
-- for that role on that table, column-scoped or not. forum_stats now has
-- NO SELECT access at all -- not even username/gecos.
\dp forum.users

-- To restore exactly the narrow access we originally wanted, the
-- column-scoped GRANT has to be reissued from scratch:
GRANT SELECT (username, gecos) ON forum.users TO forum_stats;
-- Expected: back to a clean, narrow column-privilege entry with no
-- table-wide Access privileges line for forum_stats.
\dp forum.users


-- ============================================================================
-- SECTION 10: SEQUENCE PERMISSIONS
-- ============================================================================
-- A sequence has exactly three permissions:
--   USAGE  -> lets you pull a NEW value (nextval()); this is the only one
--             defined by the SQL standard, and granting it AUTOMATICALLY
--             also grants what SELECT and UPDATE give you below (USAGE is
--             the superset).
--   SELECT -> lets you read the CURRENT/last value only (currval()/select),
--             without ever advancing the sequence.
--   UPDATE -> lets you set/reset the sequence's value (setval()).
-- ALL covers all three.
--
-- categories_pk_seq was auto-created by the SERIAL column "pk" back in
-- Section 1.
REVOKE ALL ON SEQUENCE forum.categories_pk_seq FROM luca;

-- Confirm luca currently has no access at all -- remember, PUBLIC gets NO
-- default privileges on sequences (see Section 4's list).
\c forumdb luca
SET search_path TO forum, public;
-- Expected: ERROR: permission denied for sequence categories_pk_seq
SELECT nextval('categories_pk_seq');
\c forumdb forum
SET search_path TO forum, public;

-- Grant USAGE -- notice this alone is enough for BOTH nextval() and
-- setval() to work, because USAGE implies SELECT and UPDATE for sequences.
GRANT USAGE ON SEQUENCE forum.categories_pk_seq TO luca;

\c forumdb luca
SET search_path TO forum, public;

-- Allowed now: setval() needs the UPDATE-equivalent that USAGE grants.
-- Expected: setval -> 10
SELECT setval('categories_pk_seq', 10);

-- Allowed: nextval() needs USAGE proper.
-- Expected: nextval -> 11
SELECT nextval('categories_pk_seq');

\c forumdb forum
SET search_path TO forum, public;


-- ============================================================================
-- SECTION 11: SCHEMA PERMISSIONS
-- ============================================================================
-- A schema is a namespace/container. Exactly two permissions apply to it:
--   CREATE -> allowed to create new objects INSIDE the schema
--   USAGE  -> allowed to "reach into" the schema at all, to use objects
--             that live there (assuming you separately have permission on
--             the object itself -- USAGE on the schema is a GATE, not a
--             grant of access to what's behind it)
-- This is exactly why Section 1 had to GRANT USAGE ON SCHEMA forum before
-- any of the earlier table/column/sequence examples could work at all.
CREATE SCHEMA configuration;

-- luca has neither CREATE nor USAGE on this brand-new schema yet.
\c forumdb luca
SET search_path TO forum, public;
-- Expected: ERROR: permission denied for schema configuration
CREATE TABLE configuration.conf (
    param text,
    value text,
    UNIQUE (param)
);
\c forumdb forum
SET search_path TO forum, public;

-- Granting CREATE alone is not enough to actually DO anything with the new
-- table afterward, so grant both together:
GRANT CREATE ON SCHEMA configuration TO luca;
GRANT USAGE  ON SCHEMA configuration TO luca;

\c forumdb luca
SET search_path TO forum, public;

-- Now allowed: luca has both CREATE (to make the table) and USAGE (to
-- reach the schema in the first place). luca is also automatically the
-- OWNER of this new table, so no separate table-level GRANT is needed for
-- luca's own INSERT below.
CREATE TABLE configuration.conf (
    param text,
    value text,
    UNIQUE (param)
);

INSERT INTO configuration.conf VALUES ('posts_per_page', '10');

\c forumdb forum
SET search_path TO forum, public;

-- Removing USAGE locks luca out of EVERYTHING in the schema -- even data
-- luca personally owns. USAGE is a gate on the whole namespace, and object
-- ownership does not bypass it.
REVOKE USAGE ON SCHEMA configuration FROM luca;

\c forumdb luca
SET search_path TO forum, public;
-- Expected: ERROR: permission denied for schema configuration
-- (even though luca OWNS configuration.conf)
SELECT * FROM configuration.conf;
\c forumdb forum
SET search_path TO forum, public;

-- The common real-world pattern: let a role manipulate DATA in a schema
-- without letting it change the schema's STRUCTURE (no new tables/views).
-- Restore USAGE, but make sure CREATE stays revoked.
GRANT  USAGE  ON SCHEMA configuration TO luca;
REVOKE CREATE ON SCHEMA configuration FROM luca;


-- ============================================================================
-- SECTION 12: BULK PERMISSIONS WITH ALL ... IN SCHEMA
-- ============================================================================
-- Managing grants object-by-object doesn't scale for large schemas.
-- ALL <object-kind> IN SCHEMA <schema> applies one GRANT/REVOKE to every
-- existing object of that kind in the schema in one shot. Supported kinds
-- today: TABLES, SEQUENCES, ROUTINES (with the narrower FUNCTIONS and
-- PROCEDURES variants also available).
REVOKE ALL
    ON ALL TABLES IN SCHEMA configuration
    FROM luca;

GRANT SELECT, INSERT, UPDATE
    ON ALL TABLES IN SCHEMA configuration
    TO luca;

-- Expected: every table currently in "configuration" (just conf, so far)
-- now shows luca=arw/forum.
\dp configuration.conf

-- Reminder: this is a ONE-TIME bulk operation, not a standing policy -- a
-- table created in "configuration" AFTER this statement runs will NOT
-- automatically inherit these grants. (That job belongs to a separate
-- feature, ALTER DEFAULT PRIVILEGES, which is outside this chapter.)


-- ============================================================================
-- SECTION 13: LANGUAGE PERMISSIONS
-- ============================================================================
-- Exactly one permission applies to a procedural language: USAGE (allowed
-- to write/run code in that language). ALL is accepted for syntactic
-- consistency with the other GRANT forms but is equivalent to just USAGE.
--
-- PREREQUISITE: this section needs the plperl procedural language, which
-- requires libperl and is NOT always present in a minimal Termux
-- PostgreSQL build. If the CREATE EXTENSION below fails, skip straight to
-- Section 14 -- the concept (USAGE gates who may run code in a language)
-- applies identically to plpgsql, which you already have installed and
-- is unaffected by anything in this section.
CREATE EXTENSION IF NOT EXISTS plperl;

-- Locking down an untrusted-code language is good security hygiene: strip
-- PUBLIC's default USAGE so random roles can't execute arbitrary code.
REVOKE USAGE ON LANGUAGE plperl FROM PUBLIC;

\c forumdb luca
SET search_path TO forum, public;
-- Expected: ERROR: permission denied for language plperl
DO LANGUAGE plperl $$ elog(INFO, "Hello World"); $$;
\c forumdb forum
SET search_path TO forum, public;

-- Grant USAGE back to just the one trusted role that needs it.
GRANT USAGE ON LANGUAGE plperl TO luca;

\c forumdb luca
SET search_path TO forum, public;
-- Expected: succeeds now, printing an INFO line with "Hello World".
DO LANGUAGE plperl $$ elog(INFO, "Hello World"); $$;
\c forumdb forum
SET search_path TO forum, public;


-- ============================================================================
-- SECTION 14: ROUTINE (FUNCTION/PROCEDURE) PERMISSIONS
-- ============================================================================
-- ROUTINES is an umbrella term covering both FUNCTIONS and PROCEDURES.
-- Exactly one permission applies: EXECUTE (allowed to call/run it).
CREATE FUNCTION get_max(a int, b int)
RETURNS int AS $$
BEGIN
    IF a > b THEN
        RETURN a;
    ELSE
        RETURN b;
    END IF;
END $$ LANGUAGE plpgsql;

-- By default, PUBLIC gets EXECUTE on new routines automatically (recall
-- Section 6's acldefault('f', ...) result). Lock that down, then open the
-- door for exactly one role.
REVOKE EXECUTE ON ROUTINE get_max FROM PUBLIC;
GRANT  EXECUTE ON ROUTINE get_max TO luca;

-- enrico was never individually granted EXECUTE, and PUBLIC no longer has
-- it either.
\c forumdb enrico
SET search_path TO forum, public;
-- Expected: ERROR: permission denied for function get_max
SELECT forum.get_max(10, 20);
\c forumdb forum
SET search_path TO forum, public;

-- luca, on the other hand, was explicitly granted EXECUTE.
\c forumdb luca
SET search_path TO forum, public;
-- Expected: 20
SELECT forum.get_max(10, 20);
\c forumdb forum
SET search_path TO forum, public;


-- ============================================================================
-- SECTION 15: OPTIONAL CLEANUP
-- ============================================================================
-- Left commented out so re-running earlier sections for practice doesn't
-- accidentally wipe your work. Uncomment and run as a superuser (connected
-- to a database OTHER than forumdb, since you can't drop the database
-- you're connected to) to fully reset before trying the whole file again.
--
-- \c postgres
-- DROP DATABASE IF EXISTS forumdb;
-- DROP ROLE IF EXISTS forum;
-- DROP ROLE IF EXISTS luca;
-- DROP ROLE IF EXISTS enrico;
-- DROP ROLE IF EXISTS forum_stats;
-- DROP ROLE IF EXISTS forum_emails;
-- ============================================================================
