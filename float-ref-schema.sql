-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-float-schema.sql', '$Id');

--	Wicci Project Virtual Floating-Point Text Schema
--	float_refs: typed double-precision floating point numbers

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** to do ???

-- implement unit aware constructors
-- use numeric environment bindings:
-- 'dimension' -> physical/abstract dimension,
--	e.g. length, volume, sheep
-- 'unit' -> e.g. pixels, voxels, count

-- * type float_refs

SELECT create_ref_type('float_refs');

-- * class float_rows

DROP DOMAIN IF EXISTS float_ref_values CASCADE;

CREATE DOMAIN float_ref_values AS double precision; --  NOT NULL;

CREATE TABLE IF NOT EXISTS float_units (
	name text PRIMARY KEY,
	env env_refs NOT NULL REFERENCES env_rows
);
-- CREATE INDEX float_units_env ON float_units (env);

INSERT INTO float_units(env, name) VALUES( env_nil(), '' );

-- ** TABLE float_rows(ref, env, value_ float )
CREATE TABLE IF NOT EXISTS float_rows (
	ref float_refs PRIMARY KEY,
	env env_refs NOT NULL REFERENCES env_rows,
	value_ float_ref_values NOT NULL,
	UNIQUE(env, value_)
);
COMMENT ON TABLE float_rows IS
'represents a typed double-precision floating-point value';
COMMENT ON COLUMN float_rows.env IS
'Should probably be derived from one of the environments
in float_units, or perhaps env_nil() - perhaps a
float_ref_env() default would be a good idea, like we did
with bool_ref_env()';

SELECT create_handles_for('float_rows');

-- * ref_type_class registration

SELECT declare_ref_class_with_funcs('float_rows');
SELECT create_simple_serial('float_rows');

-- CREATE OR REPLACE
-- FUNCTION isa_float_ref(refs) RETURNS boolean AS $$
--   SELECT ref_has_type_class($1, 'float_refs', 'float_rows')
-- $$ LANGUAGE SQL IMMUTABLE;

-- CREATE OR REPLACE
-- FUNCTION float_ref_from_ref(refs) RETURNS float_refs AS $$
--   SELECT unchecked_float_ref_from_id_(ref_id($1))
-- 	WHERE isa_float_ref($1)
-- $$ LANGUAGE SQL IMMUTABLE;
