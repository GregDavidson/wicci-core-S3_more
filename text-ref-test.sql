-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('text_refs-test.sql', '$Id');

\set ECHO all

SELECT test_func(
			 'get_text(text)',
			 ref_text_op( get_text('Hello World') ),
			 'Hello World'
);

SELECT test_func(
	'text_nil_text(text_refs)',
	ref_text_op( text_nil() ),
	NULL::text
);

SELECT  test_func(
	'get_text_join_tree(text,  refs[])',
	ref_text_op(
		get_text_join_tree(' ', get_text('Hello'), get_text('world'))
	),
	'Hello world'::text
);

SELECT test_func(
	'get_text_join_tree(text,  refs[])',
	ref_text_op( ( text_keys_row('fambly', get_text_join_tree(
		' and ', get_text('Greg'), get_text('Sher'), get_text('Bill')
	) ) ).key ),
	'Greg and Sher and Bill'
);

SELECT test_func(
	'get_text_join_tree(text,  refs[])',
	ref_text_op( ( text_keys_row('friends', get_text_join_tree(
		' and ', get_text('Cristal'), get_text('Blank-Page')
	) ) ).key ),
	'Cristal and Blank-Page'
);

SELECT text_tree_formats_row('3-lines', get_text_format(
	'line 1:', E'\nline 2:', E'\nline 3:'
) );

SELECT text_tree_formats_row('3-lines-nl', get_text_format(
	'line 1:', E'\nline 2:', E'\nline 3:', E'\n'
) );

SELECT test_func(
	'get_text_format_tree(integer, refs[])',
	ref_text_op( ( text_keys_row('fambly-lines', get_text_format_tree(
		text_tree_formats_id('3-lines'),
		get_text('Greg'), get_text('Sher'), get_text('Bill')
	) ) ).key ),
	E'line 1:Greg\nline 2:Sher\nline 3:Bill'
);

SELECT test_func(
	'get_text_format_tree(integer, refs[])',
	ref_text_op( ( text_keys_row('young-lines', get_text_format_tree(
		text_tree_formats_id('3-lines'),
		get_text('Greg'), get_text('Barbara')
	) ) ).key ),
	E'line 1:Greg\nline 2:Barbara\nline 3:'
);

SELECT test_func(
	'get_text_format_tree(integer, refs[])',
	ref_text_op( ( text_keys_row('fambly-lines-nl', get_text_format_tree(
		text_tree_formats_id('3-lines-nl'),
		get_text('Greg'), get_text('Sher'), get_text('Bill')
	) ) ).key ),
	E'line 1:Greg\nline 2:Sher\nline 3:Bill\n'
);
