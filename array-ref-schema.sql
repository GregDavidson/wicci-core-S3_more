-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-array-schema.sql', '$Id');

--	Wicci Project
--	ref type array_refs (array of refs) schema

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * type array_refs introduction

-- Primarily, this type exists in order to enable collections of
-- Refs to be stored as Refs so that, for example, they can be
-- the value of a binding.

-- An optional accompanying env_ref allows them to be distinguished
-- by intensional type, and also allows specification of a
-- default join string.

-- Possible future extensions:
-- + specification of non-overridable formatting
-- + use of associations to override bindings
--   i.e. COALESCE(env,me,array-join, env,array-join)
-- + optional fancier formatting
--   printf-style and text-formatted style
-- + full complement of collection classes
--   e.g. Sets, Bags, Tuples, Vectors, etc.

-- * type array_refs

SELECT create_ref_type('array_refs');

-- * schema

-- ** TABLE array_rows(ref, env, refs[])

CREATE TABLE IF NOT EXISTS array_rows (
	ref array_refs PRIMARY KEY,
	env env_refs,
	objects  refs[]
);

COMMENT ON TABLE array_rows IS
'represents a typed collection of refs';

SELECT create_handles_for('array_rows');

-- * ref_type_class registration

SELECT declare_ref_class_with_funcs('array_rows');
SELECT create_simple_serial('array_rows');

-- CREATE OR REPLACE
-- FUNCTION isa_array_ref(refs) RETURNS boolean AS $$
--   SELECT ref_has_type_class($1, 'array_refs', 'array_rows')
-- $$ LANGUAGE SQL IMMUTABLE;

-- CREATE OR REPLACE
-- FUNCTION try_array_ref(refs) RETURNS array_refs AS $$
--   SELECT refs::unchecked_refs::array_refs
--   WHERE isa_array_ref($1)
-- $$ LANGUAGE SQL IMMUTABLE;
