-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-int-code.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	int_refs: typed integers

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- important numeric environment bindings:
-- 'dimension' -> physical/abstract dimension,
--	e.g. length, volume, sheep
-- 'unit' -> e.g. pixels, voxels, count

-- ** to do ???

-- test env_best int-ref-format

-- ** type int_refs recognizers and converters

-- * Constructors and relationship with type integer

CREATE OR REPLACE
FUNCTION try_int_ref_match(text, OUT text, OUT env_refs) AS $$
	SELECT x[1], env
	FROM try_str_match($1, E'^\\s*([+-]?\\d+)\\s*(\\S*)\\s*$') x, int_units
	WHERE name = x[2]
$$ LANGUAGE SQL IMMUTABLE;

-- generalize to allow for a unit naming an env_ref
CREATE OR REPLACE
FUNCTION is_int_ref_text( text ) RETURNS boolean AS $$
	SELECT try_int_ref_match($1) IS NOT NULL
$$ LANGUAGE SQL IMMUTABLE;

-- +++ get_int_ref(val int_ref_values, env env_refs) -> int_refs
CREATE OR REPLACE
FUNCTION get_int_ref(int_ref_values, env_refs = env_nil())
RETURNS int_refs AS $$
	DECLARE
		the_ref int_refs := NULL; -- unchecked_ref_null();
		kilroy_was_here boolean := false;
		this regprocedure := 'get_int_ref(int_ref_values, env_refs)';
	BEGIN
		LOOP
			SELECT ref INTO the_ref FROM int_rows
			WHERE value_ = $1 AND env IS NOT DISTINCT FROM $2;
			IF FOUND THEN RETURN the_ref; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with % %', this, $1, $2;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO int_rows(value_, env) VALUES($1, $2);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION get_int_ref(int_ref_values, env_refs) IS
'return unique ref associated with given value and environment, creating it if necessary';

CREATE OR REPLACE
FUNCTION get_int_ref(integer) RETURNS int_refs AS $$
	SELECT get_int_ref($1::int_ref_values)
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION get_int_ref(bigint) RETURNS int_refs AS $$
	SELECT get_int_ref($1::int_ref_values)
$$ LANGUAGE SQL IMMUTABLE;

/*
DROP CAST IF EXISTS (integer AS int_refs) CASCADE;

CREATE CAST (integer AS int_refs)
WITH FUNCTION get_int_ref(integer);

DROP CAST IF EXISTS (bigint AS int_refs) CASCADE;

CREATE CAST (bigint AS int_refs)
WITH FUNCTION get_int_ref(bigint);
*/

CREATE OR REPLACE
FUNCTION try_get_int_ref(text) RETURNS int_refs AS $$
	SELECT get_int_ref(_value::int_ref_values, _unit)
	FROM try_int_ref_match($1) foo(_value, _unit)
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_int_ref(text) RETURNS int_refs AS $$
	SELECT ref
	FROM int_rows, try_int_ref_match($1) foo(_value, _unit)
	WHERE env = _unit AND value_ = _value::int_ref_values
$$ LANGUAGE SQL STRICT;


-- ** type int_refs class int_rows to_text method

SELECT declare_name('int-ref-format');

-- +++ int_ref_text(int_refs, env_refs) -> TEXT
-- shall we use the env_ref coming in? ???
CREATE OR REPLACE
FUNCTION int_ref_text( int_refs, env_refs=env_nil() )
RETURNS TEXT AS $$
	-- is the contextualization here quite right???
	SELECT COALESCE(
		to_char(
			value_, try_env_best_text($2, $1, 'int-ref-format', env)
		), value_::text
	) FROM int_rows WHERE ref = $1;
$$ LANGUAGE SQL;

-- * register the methods

-- alas, this gives "Can't cast cstring to bigint" in pg-8.4.2
-- SELECT type_class_io(
--   'int_refs', 'int_rows',
--   'get_int_ref(bigint)', 'int_ref_text(int_refs, env_refs)'
-- );

-- SELECT type_class_io(
-- 	'int_refs', 'int_rows',
-- 	'get_int_ref_(text)', 'int_ref_text(int_refs, env_refs)'
-- );

SELECT type_class_op_method(
	'int_refs', 'int_rows',
	'ref_env_text_op(refs, env_refs)', 'int_ref_text(int_refs, env_refs)'
);
