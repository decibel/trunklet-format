\i test/deps.sql

-- No IF NOT EXISTS because we'll be confused if we're not loading the new stuff
SET client_min_messages = WARNING; -- Necessary due to CASCADE
CREATE EXTENSION "trunklet-format" CASCADE;
SET client_min_messages = NOTICE;

-- BUG: someone is screwing up the search path...
SET search_path = public, tap;
