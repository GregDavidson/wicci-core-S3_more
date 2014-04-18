-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-test-scalars.sql', '$Id');

\set ECHO all

SELECT refs_debug_set(2);

SELECT spx_debug_on();
SELECT refs_debug_on();

-- * type bool_refs

SELECT test_func(
	'bool_ref(boolean)', false::bool_refs::boolean, false
);

SELECT test_func(
	'bool_ref(boolean)', true::bool_refs::boolean, true
);

SELECT test_func(
	'bool_ref_text(bool_refs, env_refs)',
	 bool_ref_text(false::bool_refs),
	 'false'::text
);

SELECT test_func(
	'bool_ref_text(bool_refs, env_refs)',
	 bool_ref_text(true::bool_refs),
	 'true'::text
);

SELECT declare_name('off', 'on');
SELECT declare_bool_env_literals(user_base_env(),  'off', 'on');

SELECT declare_bool_refs(user_base_env());

SELECT test_func(
	'bool_ref_text(bool_refs, env_refs)',
	 bool_ref_text( bool_ref(false, user_base_env()) ),
	'off'::text
);

SELECT test_func(
	'bool_ref_text(bool_refs, env_refs)',
	 bool_ref_text(bool_ref(true, user_base_env())),
	'on'::text
);

SELECT declare_bool_ref_literals(user_base_env(), 'off', 'on');

SELECT test_func(
	'bool_ref_(text)', bool_ref_('off'), bool_ref(false, user_base_env())
);

SELECT test_func(
	'bool_ref_(text)', bool_ref_('on'), bool_ref(true, user_base_env())
);
	
SELECT declare_name('Up', 'Down');

SELECT env_add_association(
	user_base_env(), bool_ref(false)::refs,
	bool_ref_key(false), 'Down'::name_refs::refs
);

SELECT env_add_association(
	user_base_env(), bool_ref(true)::refs,
	bool_ref_key(true), 'Up'::name_refs::refs
);

SELECT test_func(
	'env_best_text(env_refs, refs, name_refs, env_refs, env_refs)',
 	ref_env_text_op( bool_ref(false), user_base_env() ),
	'Down'
);

SELECT test_func(
	'env_best_text(env_refs, refs, name_refs, env_refs, env_refs)',
 	ref_env_text_op( bool_ref(true), user_base_env() ),
	'Up'
);

TABLE bool_rows;

-- type int_refs

SELECT get_int_ref(123456);

SELECT declare_name('$S9,999,999.99');

SELECT system_set('int-ref-format'::name_refs, find_name('$S9,999,999.99'));

SELECT get_int_ref('123456', system_base_env());

SELECT false::bool_refs;

SELECT true::bool_refs;

SELECT get_int_ref(123456);

SELECT ref_env_text_op(
	get_int_ref(123456), system_base_env()
);

SELECT get_int_ref(123456, system_base_env());

-- * type float_refs

SELECT get_float_ref(1234.56);

SELECT get_float_ref('1234.56', system_base_env());

SELECT ref_env_text_op(
	get_float_ref(1234.56), system_base_env()
);
