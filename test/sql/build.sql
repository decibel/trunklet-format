\set ECHO none
\i test/pgxntool/psql.sql

BEGIN;
\i test/deps.sql

-- This is just an easy way to get the dependencies pulled in on 10.0+
SELECT pg_temp._create();
DROP EXTENSION "trunklet-format";

\i sql/trunklet-format.sql

\echo # TRANSACTION INTENTIONALLY LEFT OPEN!

-- vi: expandtab sw=2 ts=2
