-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-float-code.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	float_refs: typed double-precision floating point numbers

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * to do ???

-- test env_best float-ref-format

-- Add the ability to recognize a number with a unit and
-- to construct a float_refs from that.!!!

-- * Constructors and relationship with regular floating-point

CREATE OR REPLACE
FUNCTION try_float_ref_match(text, OUT text, OUT env_refs) AS $$
	SELECT x[1], env FROM try_str_match(
		$1, E'^\\s*([+-]?\\d*(?:\\.\\d*)(?:[eE][+-]?\\d+)?)\\s*(\\S*)\\s*$'
	) x, float_units WHERE length(x[1]) > 0 AND name = x[2]
$$ LANGUAGE SQL IMMUTABLE;

-- generalize to allow for a unit naming an env_refs
CREATE OR REPLACE
FUNCTION is_float_ref_text( text ) RETURNS boolean AS $$
	SELECT try_float_ref_match($1) IS NOT NULL
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION get_float_ref(float_ref_values, env_refs)
RETURNS float_refs AS $$
	DECLARE
		the_ref float_refs := NULL; -- unchecked_ref_null();
		this regprocedure := 'get_float_ref(float_ref_values, env_refs)';
		kilroy_was_here boolean := false;
	BEGIN
		LOOP
			SELECT ref INTO the_ref FROM float_rows
			WHERE value_ = $1 AND env IS NOT DISTINCT FROM $2;
			IF FOUND THEN RETURN the_ref; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with % %', this, $1, $2;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO float_rows(value_, env) VALUES($1, $2);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION get_float_ref(float_ref_values, env_refs) IS
'return unique ref associated with given value and environment,
creating it if necessary';

CREATE OR REPLACE
FUNCTION get_float_ref(double precision) RETURNS float_refs AS $$
	SELECT get_float_ref($1, env_nil())
$$ LANGUAGE SQL;
COMMENT ON FUNCTION get_float_ref(double precision) IS
'Needed for CAST; otherwise could overload get_float_ref';

/*
CREATE OR REPLACE
FUNCTION get_float_ref(numeric, env_refs) RETURNS float_refs AS $$
--	SELECT get_float_ref( CAST( $1 AS double precision ), $2 )
	SELECT get_float_ref( $1::float_ref_values, $2 )
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION get_float_ref(numeric) RETURNS float_refs AS $$
--	SELECT get_float_ref( CAST( $1 AS double precision ) )
	SELECT get_float_ref( $1::float_ref_values )
$$ LANGUAGE SQL;
*/

-- ++ float_ref_to_float(float_refs) -> double precision
CREATE OR REPLACE
FUNCTION float_ref_to_floats(float_refs)
 RETURNS double precision AS $$
	SELECT value_ FROM float_rows WHERE ref = $1::refs
$$ LANGUAGE SQL IMMUTABLE;

DROP CAST IF EXISTS (float_refs AS double precision) CASCADE;

CREATE CAST (float_refs AS double precision)
WITH FUNCTION float_ref_to_floats(float_refs);

-- ** type float_refs recognizers and converters

/*
DROP CAST IF EXISTS (double precision AS float_refs) CASCADE;

CREATE CAST (double precision AS float_refs)
WITH FUNCTION get_float_ref(double precision);

DROP CAST IF EXISTS (numeric AS float_refs) CASCADE;

CREATE CAST (numeric AS float_refs)
WITH FUNCTION get_float_ref(numeric);
*/

CREATE OR REPLACE
FUNCTION try_get_float_ref(text) RETURNS float_refs AS $$
	SELECT get_float_ref(_value::float_ref_values, _unit)
	FROM try_float_ref_match($1) foo(_value, _unit)
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_float_ref(text) RETURNS float_refs AS $$
	SELECT ref
	FROM float_rows, try_float_ref_match($1) foo(_value, _unit)
	WHERE env = _unit AND value_ = _value::float_ref_values
$$ LANGUAGE SQL STRICT;

-- ** type float_refs class float_rows to_text method

SELECT declare_name('float-ref-format');

-- +++ float_ref_text(float_refs, env_refs) -> TEXT
-- shall we use the env_ref coming in? ???
CREATE OR REPLACE
FUNCTION float_ref_text( float_refs, env_refs=env_nil() )
RETURNS TEXT AS $$
	-- is the contextualization here quite right???
	SELECT COALESCE(
		to_char(
			value_,
			try_env_best_text($2,$1,'float-ref-format',env)
		),
		value_::text
	) FROM float_rows WHERE ref = $1;
$$ LANGUAGE SQL;

-- * register the methods

-- SELECT type_class_io(
-- 	'float_refs', 'float_rows',
-- 	'get_float_ref(double precision)',
-- 	'float_ref_text(float_refs, env_refs)'
-- );

SELECT type_class_op_method(
	'float_refs', 'float_rows',
	'ref_env_text_op(refs, env_refs)', 'float_ref_text(float_refs, env_refs)'
);
