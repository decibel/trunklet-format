\set ECHO none
\i test/pgxntool/setup.sql
\i test/load.sql

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
  trunklet.process_language(
    'format'
    , text $$No parameters.$$
    , NULL::jsonb
  )
  , $$No parameters.$$
);
SELECT is(
  trunklet.process_language(
    'format'
    , text $$No parameters.$$
    , jsonb $${"Moo": "cow"}$$
  )
  , $$No parameters.$$
);

SELECT is(
  trunklet.process_language(
    'format'
    , text $$A %test%s test.$$
    , jsonb $${
        "test": "simple"
      }$$
  )
  , $$A simple test.$$
);

SELECT is(
  trunklet.process_language(
    'format'
    , text $$%% 1 %% 2 %%$$
    , jsonb $${"Moo": "cow"}$$
  )
  , $$% 1 % 2 %$$
);
SELECT is(
  trunklet.process_language(
    'format'
    , text $$%%%Moo%s%%%Moo%L%%%Moo%I%%$$
    , jsonb $${"Moo": "says cow"}$$
  )
  , $$%says cow%'says cow'%"says cow"%$$
);

SELECT is(
  trunklet.process_language(
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
      $$SELECT trunklet.process_language( 'format', %L::text, %L::jsonb )$$
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
      $$SELECT trunklet.process_language( 'format', %L::text, %L::jsonb )$$
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

CREATE TEMP VIEW extract_test AS
  SELECT *
    FROM ( VALUES
          ( '{s1}'::text[], '{ "s1": "string 1" }'::jsonb         , 'single string'::text )
        , ( '{num}'       , '{ "num": 1.1 }'                      , 'number' )
        , ( '{t,f,"null"}', '{ "t":true,"f":false,"null":null }'  , 'multiple' )
        , ( '{num,bogus}' , '{ "num": 1.1 }'                      , 'num & bogus' )
      ) AS v( extract_list, expected, description )
;

SELECT is(
    trunklet.extract_parameters(
      'format'
      , '{
        "s1": "string 1",
        "s2": "string 2",
        "num": 1.1,
        "t": true,
        "f": false,
        "null": null
      }'::jsonb
      , extract_list
    )::jsonb
    , expected
    , 'Test extract_paramaters() for ' || description
  )
  FROM extract_test
;

\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2
