\set ECHO 0
BEGIN;
\i sql/trunklet-format.sql
\set ECHO all

-- You should write your tests

SELECT trunklet-format('foo', 'bar');

SELECT 'foo' #? 'bar' AS arrowop;

CREATE TABLE ab (
    a_field trunklet-format
);

INSERT INTO ab VALUES('foo' #? 'bar');
SELECT (a_field).a, (a_field).b FROM ab;

SELECT (trunklet-format('foo', 'bar')).a;
SELECT (trunklet-format('foo', 'bar')).b;

SELECT ('foo' #? 'bar').a;
SELECT ('foo' #? 'bar').b;

ROLLBACK;
