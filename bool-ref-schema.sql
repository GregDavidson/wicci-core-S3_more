-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-bool-schema.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	bool_refs: typed booleans

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- *  To do ???

-- Create ref_enums as a generalization of bool_refs
-- where each enum type would get a set of ID values
-- preallocated, with an integer value and name symbol,
-- either packaged in the associated environment or
-- in a custom-designed associated table.

-- * type bool_refs

SELECT create_ref_type('bool_refs');

-- * Relation bool_rows

SELECT declare_name('bool-ref-false', 'bool-ref-true');

CREATE OR REPLACE
FUNCTION bool_ref_key(boolean) RETURNS name_refs AS $$
	SELECT CASE $1
		WHEN false THEN 'bool-ref-false'::name_refs
		WHEN true THEN 'bool-ref-true'::name_refs
	END
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION ok_bool_env(env_refs) RETURNS boolean AS $$
	SELECT $1 = env_nil() OR (
			env_name_value($1, bool_ref_key(false)) IS NOT NULL AND
			env_name_value($1, bool_ref_key(true)) IS NOT NULL
	)
$$ LANGUAGE SQL STABLE;

CREATE TABLE IF NOT EXISTS bool_literals (
	name name_refs PRIMARY KEY REFERENCES name_rows,
	env env_refs NOT NULL REFERENCES env_rows
		CHECK( ok_bool_env(env) )
);
CREATE INDEX bool_literals_env ON bool_literals (env);
COMMENT ON COLUMN bool_literals.env IS
'Either an environment in which the literals for bool_refs
can be found, or env_nil() which is always empty,
allowing the literals to be overridden - tricky!';

CREATE OR REPLACE
FUNCTION bool_ref_env() RETURNS env_refs AS $$
	SELECT system_base_env()
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION bool_ref_env() IS
'The environment containing the global bool_refs defaults;
not the same as the default environment for bool_refs objects,
lest we pin those - tricky!';

CREATE OR REPLACE
FUNCTION bool_ref_name(boolean, env_refs) RETURNS name_refs AS $$
	SELECT try_name( env_name_value( $2, bool_ref_key($1) ) )
$$ LANGUAGE SQL STABLE;

CREATE TABLE IF NOT EXISTS bool_rows (
	ref bool_refs PRIMARY KEY,
	env env_refs NOT NULL DEFAULT env_nil()
		CHECK(ok_bool_env(env)),
	value_ boolean NOT NULL,
	UNIQUE(env, value_)
);
COMMENT ON TABLE bool_rows IS 'represents a typed boolean value';
COMMENT ON COLUMN bool_rows.env IS
'The environment containing the literals for this object.
When it defaults to env_nil(), then the actual environment
comes from a parameter or default to bool_ref_env() - tricky!
Possible future optimization:
Booleans can be direct references for env_rows but with their
special type.  The sign of the row reference can be the truth
value: postive=true, negative=false, 0=nil.';

SELECT create_handles_for('bool_rows');

-- * ref_type_class registration

SELECT declare_ref_class_with_funcs('bool_rows');
SELECT create_simple_serial('bool_rows');

-- CREATE OR REPLACE
-- FUNCTION isa_bool_ref(refs) RETURNS boolean AS $$
--   SELECT ref_has_type_class($1, 'bool_refs', 'bool_rows')
-- $$ LANGUAGE SQL IMMUTABLE;

-- CREATE OR REPLACE
-- FUNCTION bool_ref_from_ref(refs) RETURNS bool_refs AS $$
--   SELECT refs::unchecked_refs::bool_refs
--   WHERE isa_bool_ref($1)
-- $$ LANGUAGE SQL IMMUTABLE;



-- following the convention that references with negative indices
-- are specially assigned:

-- (I tried to use INSERT RETURNING here, but PostgreSQL wouldn't take it!)

-- ** Special Initial Values and relationship to boolean

SELECT create_const_ref_func('bool_refs', '_false', -1);
SELECT create_const_ref_func('bool_refs', '_true', -2);

INSERT INTO bool_rows(ref, value_) VALUES
	( bool_false(), false ), ( bool_true(), true );

CREATE OR REPLACE
FUNCTION try_bool_ref_to_bool(bool_refs) RETURNS boolean AS $$
	SELECT value_ FROM bool_rows WHERE ref = $1
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE
FUNCTION bool_ref_to_bool(bool_refs) RETURNS boolean AS $$
	SELECT non_null(
		try_bool_ref_to_bool($1), 'bool_ref_to_bool(bool_refs)'
	)
$$ LANGUAGE SQL IMMUTABLE;

CREATE CAST (bool_refs AS boolean)
WITH FUNCTION bool_ref_to_bool(bool_refs);
