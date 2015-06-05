/*
 * Author: Jim Nasby <Jim.Nasby@BlueTreble.com>
 * Created at: 2015-06-05 14:55:38 -0500
 *
 */

--
-- This is a example code genereted automaticaly
-- by pgxn-utils.

SET client_min_messages = warning;

BEGIN;

-- You can use this statements as
-- template for your extension.

DROP OPERATOR #? (text, text);
DROP FUNCTION trunklet-format(text, text);
DROP TYPE trunklet-format CASCADE;
COMMIT;
