/*
 * Author: Jim Nasby <Jim.Nasby@BlueTreble.com>
 * Created at: 2015-06-05 14:55:38 -0500
 *
 */

--
-- This is a example code genereted automaticaly
-- by pgxn-utils.

SET client_min_messages = warning;

-- If your extension will create a type you can
-- do somenthing like this
CREATE TYPE trunklet-format AS ( a text, b text );

-- Maybe you want to create some function, so you can use
-- this as an example
CREATE OR REPLACE FUNCTION trunklet-format (text, text)
RETURNS trunklet-format LANGUAGE SQL AS 'SELECT ROW($1, $2)::trunklet-format';

-- Sometimes it is common to use special operators to
-- work with your new created type, you can create
-- one like the command bellow if it is applicable
-- to your case

CREATE OPERATOR #? (
	LEFTARG   = text,
	RIGHTARG  = text,
	PROCEDURE = trunklet-format
);
