\set ECHO none
\i test/pgxntool/setup.sql
\i test/deps.sql

SELECT plan(
    0

    +2 -- verify search_path
);

SAVEPOINT a;
CREATE TEMP TABLE before AS
  SELECT current_setting('search_path')
;

SELECT pg_temp._create();

CREATE TEMP TABLE after AS
  SELECT current_setting('search_path')
;

-- Forcibly reset it so we know tap will work
SET search_path=public,tap;

SELECT is(
  (SELECT current_setting FROM after)
  , (SELECT current_setting FROM before)
  , 'verify search_path has not changed without cascade'
);

ROLLBACK TO a;
SET LOCAL client_min_messages = WARNING;
CREATE TEMP TABLE before AS
  SELECT current_setting('search_path')
;

SELECT pg_temp._create();

CREATE TEMP TABLE after AS
  SELECT current_setting('search_path')
;

-- Forcibly reset it so we know tap will work
SET search_path=public,tap;

SELECT is(
  (SELECT current_setting FROM after)
  , (SELECT current_setting FROM before)
  , 'verify search_path has not changed with cascade'
);


\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2
