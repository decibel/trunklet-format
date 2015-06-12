\i test/helpers/psql.sql

CREATE SCHEMA tap;
SET search_path = tap;
CREATE EXTENSION IF NOT EXISTS pgtap SCHEMA tap;
--\i test/helpers/pgtap-core.sql
--\i test/helpers/pgtap-schema.sql

\pset format unaligned
\pset tuples_only true
\pset pager
