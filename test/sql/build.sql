\set ECHO none
\i test/pgxntool/psql.sql

BEGIN;
\i test/deps.sql
SET client_min_messages = WARNING;
CREATE EXTENSION IF NOT EXISTS extension_drop CASCADE;
CREATE EXTENSION IF NOT EXISTS trunklet CASCADE;
\i sql/trunklet-format.sql

\echo # TRANSACTION INTENTIONALLY LEFT OPEN!

-- vi: expandtab sw=2 ts=2
