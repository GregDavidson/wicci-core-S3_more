-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('text_refs-test.sql', '$Id');

\set ECHO all

-- * Media Types

-- ** is_enum_type_label(regtype, name)

SELECT test_func(
	'is_enum_type_label(regtype, name)',
	is_enum_type_label('media_type_major', 'text')
);

SELECT test_func(
	'is_enum_type_label(regtype, name)',
	NOT is_enum_type_label('media_type_major', '_')
);

SELECT test_func(
	'is_enum_type_label(regtype, name)',
	NOT is_enum_type_label('media_type_major', 'cromulent')
);

SELECT test_func(
	'is_enum_type_label(regtype, name)',
	NOT is_enum_type_label('media_type_major', NULL)
);

-- ** hstore_trim(hstore)

SELECT test_func(
	'hstore_trim(hstore)',
	hstore_trim(hstore(array['a', 'b', 'c'], array['1', NULL, '3'])),
	hstore(array['a', 'c'], array['1', '3'])
);

-- ** try_parse_media_type(text)

SELECT test_func(
	'media_type_pattern()',
	try_str_match('text/html; charset=utf-8', media_type_pattern()),
	ARRAY[ 'text', NULL, 'html', NULL, 'charset', 'utf-8' ]
);	

SELECT test_func(
	'try_parse_media_type(text)',
	try_parse_media_type('text/html; charset=utf-8'),
	ROW( media_type_nil(), 'text', 'standard', 'html', '_', 'utf-8', '_', '' )::media_type_rows
);	

SELECT test_func(
	'media_type_pattern()',
	try_str_match('text/html+xml; charset=utf-8', media_type_pattern()),
	ARRAY[ 'text', NULL, 'html', 'xml', 'charset', 'utf-8' ]
);	

SELECT test_func(
	'try_parse_media_type(text)',
	try_parse_media_type('text/html+xml; charset=utf-8'),
	ROW( media_type_nil(), 'text', 'standard', 'html', 'xml', 'utf-8', '_', '' )::media_type_rows
);	

-- *** media_encoding(media_type_rows)

SELECT test_func(
	'media_encoding(media_type_rows)',
	media_encoding(mt),
	'UTF8'
) FROM try_parse_media_type('text/html; charset=utf-8') mt;

SELECT test_func(
	'media_encoding(media_type_rows)',
	media_encoding(mt),
	'LATIN1'
) FROM try_parse_media_type('text/html') mt;

-- * Get Text

SELECT test_func(
			 'get_text(text)',
			 ref_text_op( get_text('Hello World') ),
			 'Hello World'
);

-- Right now, 28 May 2019, this crashes the server!!!
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
