-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-array-code.sql', '$Id');

--	Wicci Project
--	ref type array_refs (array of refs) code

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * Constructors and relationship with regular ref arrays

CREATE OR REPLACE
FUNCTION old_array_ref(refs[], env_refs) RETURNS array_refs AS $$
	SELECT ref FROM array_rows WHERE objects = $1 AND env = $2
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION new_array_ref(refs[], env_refs) RETURNS array_refs AS $$
	INSERT INTO array_rows(objects, env) VALUES($1, $2) RETURNING ref
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION get_array_ref(refs[], env_refs=env_nil())
RETURNS array_refs AS $$
	SELECT COALESCE(
		old_array_ref($1, $2), new_array_ref($1, $2)
	);
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION env_array_ref(env_refs, VARIADIC refs[])
RETURNS array_refs AS $$
	SELECT get_array_ref($2, $1)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION array_ref(VARIADIC refs[]) RETURNS array_refs AS $$
	SELECT get_array_ref($1)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION get_array_ref_(refs[]) RETURNS array_refs AS $$
	SELECT get_array_ref($1)
$$ LANGUAGE sql;

DROP CAST IF EXISTS (refs[] AS array_refs) CASCADE;

CREATE CAST (refs[] AS array_refs)
WITH FUNCTION get_array_ref_(refs[]);

CREATE OR REPLACE
FUNCTION array_ref_to_array(array_refs) RETURNS refs[] AS $$
	SELECT objects
	FROM array_rows WHERE ref = $1
$$ LANGUAGE SQL;

DROP CAST IF EXISTS (array_refs AS refs[]) CASCADE;

CREATE CAST (array_refs AS refs[])
WITH FUNCTION array_ref_to_array(array_refs);

-- more basic array_refs functions

CREATE OR REPLACE
FUNCTION array_ref_length(array_refs) RETURNS integer AS $$
	SELECT array_length(objects)
	FROM array_rows WHERE ref = $1
$$ LANGUAGE sql;

-- * TYPE array_refs

-- Do we actually want a array_ref_text method?

SELECT declare_name('array-ref-prefix','array-ref-infix','array-ref-suffix');

-- ** array_ref_text
-- pull formatting (delimiters, etc.) from env_ref ???
CREATE OR REPLACE FUNCTION array_ref_text(
	array_refs, env_refs = env_nil(), crefs = crefs_nil()
) RETURNS text AS $$
	SELECT ''
		|| env_best_text($2, $1, 'array-ref-prefix', env, '')
		|| COALESCE(
				 array_to_string(
					 ARRAY(
						 SELECT ref_env_crefs_text_op(x, $2, $3)
						 FROM unnest(objects) x
					 ),
					 env_best_text($2, $1, 'array-ref-infix', env, '')
				 )
			 )
		|| env_best_text($2, $1, 'array-ref-suffix', env, '')
	FROM array_rows WHERE ref = $1
$$ LANGUAGE sql;

-- SELECT type_class_out(
-- 	'array_refs', 'array_rows',
-- 	'array_ref_text(array_refs, env_refs, crefs)'
-- );

SELECT type_class_op_method(
	'array_refs', 'array_rows',
	'ref_env_crefs_text_op(refs, env_refs, crefs)',
	'array_ref_text(array_refs, env_refs, crefs)'
);
