\set ECHO none
\i test/helpers/setup.sql

/*
CREATE TABLE process(
  template text
  , parameter jsonb
  , result text
);
*/

SELECT no_plan();
SELECT is(
  trunklet.process(
    'format'
    , text $$No parameters.$$
    , NULL::jsonb
  )
  , $$No parameters.$$
);
SELECT is(
  trunklet.process(
    'format'
    , text $$No parameters.$$
    , jsonb $${"Moo": "cow"}$$
  )
  , $$No parameters.$$
);

SELECT is(
  trunklet.process(
    'format'
    , text $$A %test%s test.$$
    , jsonb $${
        "test": "simple"
      }$$
  )
  , $$A simple test.$$
);

SELECT is(
  trunklet.process(
    'format'
    , $$%start%s%middle%s%end%s$$::text
    , jsonb $${
        "start": "This is the start.\n",
        "middle": "This is the middle.\n",
        "end": "This is the end.\n"
      }$$
  )
  , $$This is the start.
This is the middle.
This is the end.
$$
);

ROLLBACK;

-- vi: expandtab ts=2 sw=2
