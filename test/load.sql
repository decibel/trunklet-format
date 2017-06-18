\i test/deps.sql

-- No IF NOT EXISTS because we'll be confused if we're not loading the new stuff
SET client_min_messages = WARNING; -- Necessary due to CASCADE
DO $$ BEGIN
  IF current_setting('server_version_num')::int < 100000 THEN
    CREATE EXTENSION "trunklet-format" ;
  ELSE
    EXECUTE $exec$CREATE EXTENSION "trunklet-format" CASCADE$exec$;
  END IF;
END$$;
SET client_min_messages = NOTICE;

-- BUG: someone is screwing up the search path...
SET search_path = public, tap;
