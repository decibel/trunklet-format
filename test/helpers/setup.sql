\i test/helpers/psql.sql
BEGIN;
\i test/helpers/deps.sql

\i test/helpers/tap_setup.sql

-- No IF NOT EXISTS because we'll be confused if we're not loading the new stuff
CREATE EXTENSION "trunklet-format";
