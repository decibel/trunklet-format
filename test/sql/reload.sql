\set ECHO none
\i test/pgxntool/setup.sql
\i test/deps.sql

SELECT plan(
    0
    + 2 -- Initial create & test
    + 2 -- Reload
    + 2 -- Drop fails after registering template
    + 2 -- Drop succeeds after unregistering template
);

--SET client_min_messages = WARNING; -- Necessary due to CASCADE
-- Drop-reload
SELECT lives_ok(
    'CREATE EXTENSION "trunklet-format" ;'
    , 'Create extension'
);
-- We assume this works, so test it...
SELECT throws_ok(
  $throws$
SELECT extension_drop__add(
  'trunklet-format'
  -- WARNING! Our language name is format, not trunklet-format!
  , $sql$SELECT trunklet.template_language__remove('format', ignore_missing_functions => true)$sql$
)
  $throws$
  , '23505' --duplicate key
  , NULL
  , 'A second extension_drop__add() call fails'
);

SELECT lives_ok(
    'DROP EXTENSION "trunklet-format";'
    , 'Drop extension'
);
SELECT lives_ok(
    'CREATE EXTENSION "trunklet-format" ;'
    , 'Create extension'
);
SET client_min_messages = NOTICE; -- Can switch back now that we're done creating extensions

-- Drop with registered template
SELECT lives_ok(
    $$SELECT trunklet.template__add('format', 'TEMP test template', '')$$
    , 'Add test template'
);
SELECT throws_ok(
    'DROP EXTENSION "trunklet-format";'
    , '23503' -- foreign_key_violation
    , 'cannot drop language "format" because stored templates depend on it'
    , 'Drop extension'
);

-- Drop after dropping template
SELECT lives_ok(
    $$SELECT trunklet.template__remove('TEMP test template')$$
    , 'Remove test template'
);
SELECT lives_ok(
    'DROP EXTENSION "trunklet-format";'
    , 'Drop extension'
);

\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2
