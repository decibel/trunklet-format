-- Note: pgTap is loaded by setup.sql

-- Add any test dependency statements here
--CREATE EXTENSION IF NOT EXISTS trunklet;

-- Have to reset our search_path
SET search_path = public,tap;
