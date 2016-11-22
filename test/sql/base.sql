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

SELECT is(
      trunklet.process_language(
        'format'
        , replace(
          $$%opt%OR%value%R%opt%OR%value%R$$
          , 'R'
          , replace
        )
        , j
      )
      , repeat( format(
        replace( '%R%R', 'R', replace )
        , NULL
        , j->>'value'
      ), 2 )
      , format( 'test optional handling with %s and %s', replace, j->>'value' )
    )
  FROM unnest('{s,L}'::text[]) r(replace)
    , (SELECT row_to_json(v) AS j FROM (VALUES
      (to_json(1.1))
      , (to_json(NULL::int))
      , (to_json('text'::text))
      , (to_json(true))
    ) v(value) ) j
;

SELECT throws_ok(
  $$SELECT trunklet.process_language( 'format', 'some stuff%test parameter%OIsome more stuff', NULL::json )$$
  , '22004' -- null_value_not_allowed
  , 'SQL identifier format option ("I") not allowed with optional parameters'
);
-- This is meant to ensure the DETAIL is correct, but it doesn't work on travis :(
/*
SAVEPOINT a;
\unset ON_ERROR_STOP
\set VERBOSITY default
\echo THIS ERROR IS OK!
SELECT 'DETAIL:  parameter "test parameter" at template position ' || strpos( 'some stuff%test parameter%OIsome more stuff', '%' );
SELECT trunklet.process_language( 'format', 'some stuff%test parameter%OIsome more stuff', NULL::json );
ROLLBACK TO a;
\set ON_ERROR_STOP 1
\set VERBOSITY VERBOSE
*/

SELECT throws_ok(
    format(
      $$SELECT trunklet.process_language( 'format', %L::text, %L::jsonb )$$
      , '%Moo%' || optional || specifier
      , '{"Moo":1}'
    )
    , format(
      'Unexpected character "%s" in format specifier "%s"'
      , specifier
      , optional || specifier
    )
  )
  FROM unnest('{"",a,S,i,l}'::text[]) s(specifier)
    , unnest('{"",O}'::text[]) o(optional)
;
-- This is meant to ensure the DETAIL is correct, but it doesn't work on travis :(
/*
SAVEPOINT a;
\unset ON_ERROR_STOP
\set VERBOSITY default
\echo THIS ERROR IS OK!
SELECT 'DETAIL:  parameter "Moo" at template position ' || strpos( 'more%Moo%OSmore', '%' );
SELECT trunklet.process_language('format', 'more%Moo%OSmore', NULL::json);
ROLLBACK TO a;
\echo THIS ERROR IS OK!
SELECT 'DETAIL:  parameter "Moo" at template position ' || strpos( 'more%Moo%OSmore', '%' );
SELECT trunklet.process_language('format', 'more%Moo%lmore', NULL::json);
ROLLBACK TO a;
\set ON_ERROR_STOP 1
\set VERBOSITY VERBOSE
*/

SELECT throws_like(
    format(
      $$SELECT trunklet.process_language( 'format', %L::text, %L::jsonb )$$
      , replace(input, 's', replacement)
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
  , unnest('{s,I,L}'::text[]) u(replacement)
;

CREATE TEMP VIEW extract_test AS
  SELECT *
    FROM ( VALUES
          ( '{s1}'::text[], '{ "s1": "string 1" }'::jsonb         , 'single string'::text )
        , ( '{num}'       , '{ "num": 1.1 }'                      , 'number' )
        , ( '{t,f,"null"}', '{ "t":true,"f":false,"null":null }'  , 'multiple' )
        , ( '{num,bogus}' , '{ "num": 1.1 }'                      , 'num & bogus' )
        , ( '{bogus}'     , NULL                                  , 'bogus' )
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

/*
 * Common syntax checking code
 */
SELECT throws_ok(
    format(
      $$SELECT trunklet.$$ || format
      , j
    )
    , format( 'parameters must be a JSON object, not %s', jsonb_typeof(j->'value') )
    , format(
      $$SELECT trunklet.$$ || format
      , j
    )
  )
  FROM
    unnest(array[
        $$process_language('format', 'template', (%L::jsonb)->'value')$$
      , $$extract_parameters('format', (%L::jsonb)->'value', '{a}'::text[])$$
    ]) f(format)
    , (SELECT row_to_json(v)::jsonb AS j FROM (VALUES
      (to_json(1.1))
      , (to_json('text'::text))
      , (to_json(true))
      , (to_json(array[1,2,3]))
    ) v(value) ) j
;
SELECT throws_ok(
    format(
      $$SELECT trunklet.$$ || format
      , format( '{"%s":1}', key )
    )
    , NULL
    , 'parameter names may not contain "%"'
    , format || ': parameter names may not contain "%"'
  )
  FROM
    unnest(array[
        $$process_language('format', 'template', %L::jsonb)$$
      , $$extract_parameters('format', %L::jsonb, '{a}'::text[])$$
    ]) f(format)
    , unnest('{% key,key %,k%k}'::text[]) k(key)
;
SELECT throws_ok(
    format(
      $$SELECT trunklet.$$ || format
      , j
    )
    , format( '%s is not supported as a parameter type', jsonb_typeof(j->'value') )
  )
  FROM
    unnest(array[
        $$process_language('format', 'template', %L::jsonb)$$
      , $$extract_parameters('format', %L::jsonb, '{a}'::text[])$$
    ]) f(format)
    , (SELECT row_to_json(v)::jsonb AS j FROM (VALUES
      ('{"key":"value"}'::json)
      , (to_json(array[1,2,3]))
    ) v(value) ) j
;

\i test/pgxntool/finish.sql

-- vi: expandtab ts=2 sw=2
