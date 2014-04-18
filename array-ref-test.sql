-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-array-test.sql', '$Id');

--	Wicci Project Ref Array Tests

-- ** Copyright

--	Copyright (c) 2005, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

\set ECHO all

-- select spx_debug_on();

-- select refs_debug_on();

-- to do ???
-- test env_best array-ref-{pre,in,suf}fix features some more
-- once text_refs is available

SELECT refs_debug_on();

SELECT declare_name('world', '_', ' ');

SELECT get_array_ref( ARRAY[ 'hello'::name_refs, 'world'::name_refs ]::refs[] );

SELECT system_set('array-ref-infix'::name_refs, '_'::name_refs::refs);

SELECT ref_env_crefs_text_op(get_array_ref( ARRAY[ 'hello'::name_refs, 'world'::name_refs ]::refs[] ), system_base_env(), crefs_nil() );

SELECT x FROM unnest(
	array_ref_to_array(
		get_array_ref(
			 ARRAY[
				 false::bool_refs::refs,
				 get_int_ref(2)::refs,
				 get_float_ref(3.14159)::refs
			 ]
		)
	)
) x;
