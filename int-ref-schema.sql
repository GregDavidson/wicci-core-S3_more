-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-int-schema.sql', '$Id');

--	Wicci Project Virtual Integer Text Schema
--	int_refs: typed integers

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

-- * type int_refs

SELECT create_ref_type('int_refs');

-- * schema

-- ** DOMAIN int_ref_values, TABLE int_rows

DROP DOMAIN IF EXISTS int_ref_values CASCADE;

CREATE DOMAIN int_ref_values AS :WordIntsPG NOT NULL;

CREATE TABLE IF NOT EXISTS int_units (
	name text PRIMARY KEY,
	env env_refs NOT NULL REFERENCES env_rows
);
-- CREATE INDEX int_units_env ON ref_init_units (env);

INSERT INTO int_units(env, name) VALUES( env_nil(), '' );

-- ** TABLE int_rows(ref, env, value_ int )
CREATE TABLE IF NOT EXISTS int_rows (
	ref int_refs PRIMARY KEY,
	env env_refs NOT NULL REFERENCES env_rows,
	value_ int_ref_values NOT NULL,
	UNIQUE(env, value_)
);
COMMENT ON TABLE int_rows IS '
represents a typed integer value;
consider using ref_id(ref) as the value_!
';
COMMENT ON COLUMN int_rows.env IS
'Should probably be derived from one of the environments
in int_units, or perhaps env_nil() - perhaps a
int_ref_env() default would be a good idea, like we did
with bool_ref_env()';

SELECT create_handles_for('int_rows');

-- * ref_type_class registration

SELECT declare_ref_class_with_funcs('int_rows');
SELECT create_simple_serial('int_rows');

-- CREATE OR REPLACE
-- FUNCTION isa_int_ref(refs) RETURNS boolean AS $$
--   SELECT ref_has_type_class($1, 'int_refs', 'int_rows')
-- $$ LANGUAGE SQL IMMUTABLE;

-- CREATE OR REPLACE
-- FUNCTION int_ref_from_ref(refs) RETURNS int_refs AS $$
-- 	SELECT unchecked_int_ref_from_id_(ref_id($1))
-- 	WHERE isa_int_ref($1)
-- $$ LANGUAGE SQL IMMUTABLE;
