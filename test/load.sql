\i test/deps.sql

SELECT pg_temp._create();

-- BUG: someone is screwing up the search path...
SET search_path = public, tap;
