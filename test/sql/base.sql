\set ECHO none
\i test/helpers/setup.sql

/*
CREATE TABLE process(
  template text
  , parameter jsonb
  , result text
);
*/

-- Protect against infinite loops
SET statement_timeout = '2 s';

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
    , text $$%% 1 %% 2 %%$$
    , jsonb $${"Moo": "cow"}$$
  )
  , $$% 1 % 2 %$$
);
SELECT is(
  trunklet.process(
    'format'
    , text $$%%%Moo%s%%%Moo%L%%%Moo%I%%$$
    , jsonb $${"Moo": "says cow"}$$
  )
  , $$%says cow%'says cow'%"says cow"%$$
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

SELECT throws_like(
    format(
      $$SELECT trunklet.process( 'format', %L::text, %L::jsonb )$$
      , input
      , param
    )
    , 'Unexpected character "%" trailing parameter "Moo"'
  )
  FROM (VALUES
        ('%Moo%')
      , ('%Moo%a')
      , ('%Moo%S')
      , ('%Moo%i')
      , ('%Moo%l')
    ) input( input )
  , (VALUES ('{"Moo":1}')
    ) param( param )
;

SELECT throws_like(
    format(
      $$SELECT trunklet.process( 'format', %L::text, %L::jsonb )$$
      , input
      , param
    )
    , 'parameter "mia" not found'
  )
  FROM (VALUES
        ('%mia%s ')
      , (' %mia%s')
      , (' %mia%s ')
      , ('%mia%s')
    ) input( input )
  , (VALUES ('{"Moo":1}'), (NULL)
    ) param( param )
;
ROLLBACK;

-- vi: expandtab ts=2 sw=2
