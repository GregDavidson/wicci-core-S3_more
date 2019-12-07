-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('text_refs-code.sql', '$Id');

--	Wicci Project Virtual Text Code

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- * Media Types

-- Syntax of Media Type:
-- top-level type name / [ tree. ] subtype name [ +suffix ] [ ; parameters ]

-- ** From Media Type

CREATE OR REPLACE
FUNCTION media_type_text(media_type_refs) RETURNS text AS $$
  SELECT COALESCE( NULLIF(major_, '_')::text, misc_ -> 'major', 'unknown'  ) -- 'unknown'???
		|| COALESCE(  '/'
			|| COALESCE(' ' || NULLIF( NULLIF(tree_, 'standard'), '_') || ' ', '')
			||  COALESCE( NULLIF(minor_, '')::text, misc_ -> 'minor' ), '' )
		|| COALESCE(  '+' || COALESCE( NULLIF(suffix_, '_')::text, misc_ -> 'suffix' ), '' )
		|| CASE WHEN  _charset IS NULL AND _params IS NULL THEN ''
			ELSE ';'
				|| COALESCE( ' charset=' || _charset::text , '')
				|| COALESCE( ' ' || _params, '' )
			END
  FROM media_type_rows,
		COALESCE( NULLIF(charset_, ''), misc_ -> 'charset' ) _charset,
		COALESCE(misc_ -> 'params') _params
  WHERE ref = $1
$$ LANGUAGE SQL STABLE; 

COMMENT ON FUNCTION media_type_text(media_type_refs) IS
'(1) Although we''re not assuming that minor is text, we
should replace its NULLIF identity value if it isn''t;
(2) what if tree_ is "_" instead of "standard"?';

SELECT type_class_op_method(
	'media_type_refs', 'media_type_rows',
	'ref_text_op(refs)', 'media_type_text(media_type_refs)'
);

CREATE OR REPLACE
FUNCTION try_media_type_encoding(media_type_refs) RETURNS text AS $$
	SELECT encoding_::text FROM media_type_rows
	WHERE ref = $1 AND encoding_ != '_'
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION try_media_type_encoding(media_type_refs)
IS 'returns PostgreSQL encoding for any text encoded as bytea';

-- ** To Media Type

-- *** Enum Management

CREATE OR REPLACE
FUNCTION is_enum_type_label(regtype, name) RETURNS boolean AS $$
	SELECT COALESCE( exists(
		 SELECT oid FROM pg_enum WHERE enumtypid = $1 AND enumlabel = $2 AND $2 NOT LIKE '\_%'
	), false )
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION is_enum_type_label(regtype, name)
IS 'Does enum $1 have a label $2 which does not start with an underscore?';

-- *** Parsing

CREATE OR REPLACE
FUNCTION media_type_pattern() RETURNS text AS $$
	SELECT '^' || space || '([^[:space:]/]+)'					-- 1 major
	|| space || '/'	|| space || '(?:([^[:space:].]+)\.)?'		-- 2 tree?
	|| space || '([^[:space:]+;]+)?'												-- 3 minor?
	|| space || '(?:\+([^[:space:];]+))?'			-- 4 suffix?
	|| space || '(?:;'	|| space
	|| '(?:([cC][hH][aA][rR][sS][eE][tT])' || space || '=)?'			-- 5 charset?
	|| space || '(.*[^[:space:]][[:space:]]*$)?'			-- 6 parameter value?
	|| ')?'
	FROM COALESCE('[[:space:]]*') space
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION media_type_pattern()
IS 'top-level-type-name / [ tree. ] subtype-name [ +suffix ] [ ; [ key = ] parameters ]';

CREATE OR REPLACE
FUNCTION hstore_trim(hstore) RETURNS hstore AS $$
	SELECT COALESCE( hstore(
	  (SELECT array_agg(key)::text[] FROM each($1) WHERE COALESCE(value, '') != ''),
  	(SELECT array_agg(value)::text[] FROM each($1) WHERE COALESCE(value, '') != '')
), hstore('') )
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION hstore_trim(hstore)
IS 'filter out the pairs whose values are NULL';

CREATE OR REPLACE
FUNCTION try_parse_media_type(text) RETURNS media_type_rows AS $$
	SELECT ROW(
		media_type_nil(),
		CASE WHEN enum_major THEN _major ELSE '_' END::media_type_major,
		CASE WHEN enum_tree THEN _tree ELSE 'standard' END::media_type_tree,
		_minor,
		CASE WHEN enum_suffix THEN _suffix ELSE '_' END::media_type_suffix,
		CASE WHEN _charset = 'charset' THEN _param ELSE '' END,
		'_',
		hstore_trim( hstore(
			ARRAY['major', 'tree', 'suffix', 'misc'],
			ARRAY[
				CASE WHEN enum_major THEN NULL ELSE _major END::text,
				CASE WHEN enum_tree THEN NULL ELSE _tree END::text,
				CASE WHEN enum_suffix THEN NULL ELSE _suffix END::text,
				CASE WHEN _charset = 'charset' THEN NULL ELSE _param END::text
			]
		) )
	)::media_type_rows
	FROM
 		try_str_match($1, media_type_pattern()) part,
		lower(part[1]) _major,
		is_enum_type_label('media_type_major', _major) enum_major,
		lower(part[2]) _tree,
		is_enum_type_label('media_type_tree', _tree) enum_tree,
		COALESCE(lower(part[3]), '') _minor,
		lower(part[4]) _suffix,
		is_enum_type_label('media_type_suffix', _suffix) enum_suffix,
		COALESCE(lower(part[5]), '') _charset,
		COALESCE(lower(part[6]), '') _param
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE
FUNCTION media_encoding(mt media_type_rows)
RETURNS pg_text_encodings AS $$
	SELECT CASE lower((mt).charset_)
		WHEN '' THEN 'LATIN1'::pg_text_encodings
		WHEN 'utf-8' THEN 'UTF8'::pg_text_encodings
		WHEN 'iso-8859-1' THEN 'LATIN1'::pg_text_encodings
		WHEN 'iso-8859-2' THEN 'LATIN2'::pg_text_encodings
		WHEN 'iso-8859-3' THEN 'LATIN3'::pg_text_encodings
		WHEN 'iso-8859-4' THEN 'LATIN4'::pg_text_encodings
		WHEN 'iso-8859-5' THEN 'ISO_8859_5'::pg_text_encodings
		WHEN 'iso-8859-6' THEN 'ISO_8859_6'::pg_text_encodings
		WHEN 'iso-8859-7' THEN 'ISO_8859_7'::pg_text_encodings
		WHEN 'iso-8859-8' THEN 'ISO_8859_8'::pg_text_encodings
		WHEN 'iso-8859-9' THEN 'LATIN5'::pg_text_encodings
		WHEN 'iso-8859-10' THEN 'LATIN6'::pg_text_encodings
		WHEN 'iso-8859-13' THEN 'LATIN7'::pg_text_encodings
		WHEN 'iso-8859-14' THEN 'LATIN8'::pg_text_encodings
		WHEN 'iso-8859-15' THEN 'LATIN9'::pg_text_encodings
		WHEN 'iso-8859-16' THEN 'LATIN10'::pg_text_encodings
		ELSE CASE
			 WHEN (mt).major_ = 'text'	THEN	'UTF8'::pg_text_encodings
			ELSE'_'::pg_text_encodings
		END
END
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION media_encoding(media_type_rows)
IS 'Need to finish and improve mapping from valid Media Types to PostgreSQL charset encodings';

-- *** Getting New or Old Media Type

CREATE OR REPLACE
FUNCTION try_get_media_type(mt media_type_rows)
RETURNS media_type_refs AS $$
DECLARE
	maybe media_type_refs;
	kilroy_was_here boolean := false;
	this regprocedure := 'try_get_media_type(media_type_rows%type)';
	_encoding pg_text_encodings := media_encoding($1);
BEGIN
	LOOP
		SELECT INTO maybe ref FROM media_type_rows
		WHERE major_ = (mt).major_ AND tree_ = (mt).tree_
		AND minor_ = (mt).minor_ AND suffix_ = (mt).suffix_
		AND charset_ = (mt).charset_ AND encoding_ = _encoding
		AND misc_ = (mt).misc_;
		IF FOUND THEN RETURN maybe; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, _encoding;
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO media_type_rows(major_, tree_, minor_, suffix_, charset_, encoding_, misc_)
			VALUES ( (mt).major_, (mt).tree_, (mt).minor, (mt).suffix_, (mt).charset_, _encoding, (mt).misc_ );
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!', this, $1, _encoding, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION try_get_media_type(text) 
RETURNS media_type_refs AS $$
	SELECT try_get_media_type(try_parse_media_type($1))
$$ LANGUAGE SQL STABLE STRICT;

CREATE OR REPLACE
FUNCTION get_media_type(text)
RETURNS media_type_refs AS $$
	SELECT non_null(
		try_get_media_type($1), 'get_media_type(text)'
	)
$$ LANGUAGE SQL STABLE;

-- * Virtual Text Leaf Classes

-- ** text_nil_text

CREATE OR REPLACE
FUNCTION text_nil_text(text_refs) RETURNS text AS $$
	SELECT raise_debug_note(
			'text_nil_text(text_refs)', 'returning empty string'::text
	);
	SELECT NULL::text
$$ LANGUAGE SQL STABLE;
COMMENT ON FUNCTION text_nil_text(text_refs) IS
'warn and return the empty string';

-- *** text_string_rows functions

-- +++ small_text_string_to_len(text_refs) -> text
CREATE OR REPLACE
FUNCTION small_text_string_length(text_refs) RETURNS integer AS $$
	SELECT octet_length(string_) FROM small_text_string_rows
	WHERE ref = non_null($1, 'small_text_string_length(text_refs)')
$$ LANGUAGE SQL;
COMMENT ON FUNCTION small_text_string_length(text_refs) IS
'return length of small_text_string associated with ref,
which should exist, in bytes';

-- +++ small_text_string_text(text_refs) -> text
CREATE OR REPLACE
FUNCTION small_text_string_text(text_refs) RETURNS text AS $$
	SELECT string_ FROM small_text_string_rows
	WHERE ref = non_null($1, 'small_text_string_text(text_refs)')
$$ LANGUAGE SQL;
COMMENT ON FUNCTION small_text_string_text(text_refs) IS
'return text associated with ref, which should exist';

-- +++ big_text_string_to_len(text_refs) -> text
CREATE OR REPLACE
FUNCTION big_text_string_length(text_refs) RETURNS integer AS $$
	SELECT octet_length(string_) FROM big_text_string_rows
	WHERE ref = non_null($1, 'big_text_string_length(text_refs)')
$$ LANGUAGE SQL;
COMMENT ON FUNCTION big_text_string_length(text_refs) IS
'return length of big_text_string associated with ref,
which should exist, in bytes';

-- +++ big_text_string_text(text_refs) -> text
CREATE OR REPLACE
FUNCTION big_text_string_text(text_refs) RETURNS text AS $$
	SELECT string_ FROM big_text_string_rows
	WHERE ref = non_null($1, 'big_text_string_text(text_refs)')
$$ LANGUAGE SQL;
COMMENT ON FUNCTION big_text_string_text(text_refs) IS
'return text associated with ref, which should exist';

CREATE OR REPLACE
FUNCTION try_text(text)  RETURNS text_refs AS $$
	SELECT COALESCE(
		( SELECT ref FROM small_text_string_rows WHERE string_ = $1 ),
		( SELECT ref FROM big_text_string_rows WHERE string_ = $1 )
	)
$$ LANGUAGE sql VOLATILE STRICT;

CREATE OR REPLACE
FUNCTION find_text(text) RETURNS text_refs AS $$
	SELECT non_null( try_text($1),	'find_text(text)' )
$$ LANGUAGE sql VOLATILE;
COMMENT ON FUNCTION find_text(text) IS
'Returns unique ref associated with text argument
in either the small_text_string_rows table or the
big_text_string_rows table.  Should we try to look
in any other table??';

CREATE OR REPLACE
FUNCTION try_get_text(text) RETURNS text_refs AS $$
	DECLARE
		maybe text_refs := NULL; -- unchecked_ref_null();
		kilroy_was_here boolean := false;
		small BOOLEAN := octet_length($1) <= max_indexable_field_size();
		this regprocedure := 'try_get_text(text)';
	BEGIN
		LOOP
			maybe := try_text($1);
			IF maybe IS NOT NULL THEN RETURN maybe; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with %', this, $1;
			END IF;
			kilroy_was_here := true;
			BEGIN
				IF small THEN
					INSERT INTO small_text_string_rows(string_) VALUES($1);
				ELSE
					INSERT INTO big_text_string_rows(string_, hash_) VALUES($1, hash($1));
				END IF;
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT VOLATILE;
COMMENT ON FUNCTION try_get_text(text) IS
'return unique ref associated with text argument
in the text_string_rows table, creating it if necessary';

CREATE OR REPLACE
FUNCTION get_text(text) RETURNS text_refs AS $$
	SELECT non_null( try_get_text($1), 'get_text(text)' )
$$ LANGUAGE sql;
COMMENT ON FUNCTION get_text(text) IS
'non_null get_text_string(text)';

SELECT get_text('');						-- maybe make id=1 ??

-- +++ try_get_xml_text(name text) -> text_refs
CREATE OR REPLACE
FUNCTION try_get_xml_text(text) RETURNS text_refs AS $$
  SELECT try_get_text($1)
$$ LANGUAGE sql STRICT;
COMMENT ON FUNCTION try_get_xml_text(text) IS
'return unique ref associated with xml text argument,
creating it if necessary.
We should add code to normalize any
character entities!!';

-- +++ get_xml_text(name text) -> text_refs
CREATE OR REPLACE
FUNCTION get_xml_text(text) RETURNS text_refs AS $$
  SELECT get_text($1)
$$ LANGUAGE sql;
COMMENT ON FUNCTION get_xml_text(text) IS
'return unique ref associated with xml text argument,
creating it if necessary.
We should add code to normalize any
character entities!!';

-- $$ LANGUAGE sql;

-- * text_refs handles sugar

/*
-- -- hold_text(text) -> text_refs
CREATE OR REPLACE
FUNCTION hold_text(handles) RETURNS text_refs AS $$
	SELECT text_keys_key($1)
$$ LANGUAGE sql;
COMMENT ON FUNCTION hold_text(handles) IS
'Return the text_refs value held in this module under the given name.';
*/

/*
-- -- hold_text(handles, text_refs) -> text_refs
CREATE OR REPLACE
FUNCTION hold_text(handles, text) RETURNS text_refs AS $$
	SELECT (text_keys_row($1, get_text($2))).key
$$ LANGUAGE sql;
COMMENT ON FUNCTION hold_text(handles, text) IS
'Convert the given text value to text_refs, hold it under
the given handle, and return it.';
*/

-- * register class abstract_text_rows

-- abstract_text_rows will be used for input!

-- SELECT type_class_io(
-- 	'text_refs', 'abstract_text_rows',
-- 	'get_text_string(text)', 'text_nil_text(text_refs)'
-- );

-- * register class text_string_rows

-- SELECT type_class_out(
-- 	'text_refs', 'text_string_rows',
-- 	'text_string_text(text_refs)'
-- );

SELECT type_class_op_method(
	'text_refs', 'abstract_text_rows',
	'ref_text_op(refs)', 'text_nil_text(text_refs)'
);

SELECT type_class_op_method(
	'text_refs', 'small_text_string_rows',
	'ref_text_op(refs)', 'small_text_string_text(text_refs)'
);

SELECT type_class_op_method(
	'text_refs', 'small_text_string_rows',
	'ref_length_op(refs)', 'small_text_string_length(text_refs)'
);

SELECT type_class_op_method(
	'text_refs', 'big_text_string_rows',
	'ref_text_op(refs)', 'big_text_string_text(text_refs)'
);

SELECT type_class_op_method(
	'text_refs', 'big_text_string_rows',
	'ref_length_op(refs)', 'big_text_string_length(text_refs)'
);

-- *** blob_rows functions

-- +++ blob_to_len(blob_refs) -> text
CREATE OR REPLACE
FUNCTION try_blob_length(blob_refs)  RETURNS bigint AS $$
	SELECT SUM( octet_length(chunk_) )
	FROM blob_chunks c, blob_rows r
	WHERE r.ref = $1 AND c.hash_::uuid = ANY((r.chunks)::uuid[])
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION blob_length(blob_refs) RETURNS bigint AS $$
	SELECT non_null(
		try_blob_length($1),	'blob_length(blob_refs)'
	)
$$ LANGUAGE SQL;

COMMENT ON FUNCTION blob_length(blob_refs) IS
'return length of blob associated with ref,
which should exist, in bytes';

CREATE OR REPLACE
FUNCTION try_blob_hash(blob_refs)  RETURNS hashes AS $$
	SELECT hash_ FROM blob_rows WHERE ref = $1
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION blob_hash(blob_refs) RETURNS hashes AS $$
	SELECT non_null(try_blob_hash($1),	'blob_hash(blob_refs)')
$$ LANGUAGE SQL;

-- +++ blob_text(blob_refs) -> text
CREATE OR REPLACE
FUNCTION blob_text(blob_refs) RETURNS text AS $$
	SELECT 'blob'::text WHERE false
$$ LANGUAGE SQL;
COMMENT ON FUNCTION blob_text(blob_refs) IS
'we need a convenient way to deal with blob values as a sequence';

CREATE OR REPLACE
FUNCTION blob_bytes(hash_arrays) RETURNS bytea AS $$
	SELECT string_agg(chunk_, ''::bytea)
	FROM	unnest($1) u, blob_chunks WHERE hash_ = u::hashes
$$ LANGUAGE SQL;

COMMENT ON FUNCTION blob_bytes(hash_arrays) IS '
Move into blob_bytes as a FROM clause??';

CREATE OR REPLACE
FUNCTION blob_bytes(blob_refs) RETURNS bytea AS $$
	SELECT blob_bytes(chunks) FROM blob_rows WHERE ref = $1
$$ LANGUAGE SQL;

COMMENT ON FUNCTION blob_text(blob_refs) IS
'we need a convenient way to deal with blob values as a sequence';

CREATE OR REPLACE
FUNCTION blob_num_chunks(blob_refs) RETURNS integer AS $$
		SELECT array_length(chunks, 1) FROM blob_rows
		WHERE ref = non_null($1, 'blob_num_chunks(blob_refs)')
$$ LANGUAGE SQL;
COMMENT ON FUNCTION blob_num_chunks(blob_refs) IS
'return number of chunks of blob associated with ref,
which should exist';

CREATE OR REPLACE
FUNCTION blob_chunk(blob_refs, integer) RETURNS bytea AS $$
	SELECT chunk_ FROM blob_chunks c, blob_rows r
	WHERE r.ref = non_null($1, 'blob_chunk(blob_refs, integer)')
	AND c.hash_ = r.chunks[$2]::hashes
$$ LANGUAGE SQL;
COMMENT ON FUNCTION blob_chunk(blob_refs, integer) IS
'return contents of specified chunk of specified blob which must exist';

CREATE OR REPLACE
FUNCTION try_get_blob_chunk(bytea) RETURNS hashes AS $$
	DECLARE
		_hash hashes := hash($1);
		_length integer := octet_length($1);
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_blob_chunk(bytea)';
	BEGIN
		IF  _length > max_blob_chunk_size() THEN
			RAISE EXCEPTION '%: length % > %!', this, _length, max_blob_chunk_size();
		END IF;
		LOOP
			PERFORM chunk_ FROM blob_chunks WHERE hash_ = _hash;
			IF FOUND THEN RETURN _hash; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with %', this, _hash;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO blob_chunks(hash_, chunk_) VALUES(_hash, $1);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % raised %!', this, _hash, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT VOLATILE;

CREATE OR REPLACE
FUNCTION get_blob_chunk(bytea) RETURNS hashes AS $$
	SELECT non_null( try_get_blob_chunk($1),	'get_blob_chunk(bytea)' )
$$ LANGUAGE sql;

COMMENT ON FUNCTION get_blob_chunk(bytea) IS
'return unique hash associated with typea argument
in the blob_chunks table, creating it if necessary;
the chunk must be within max_blob_chunk_size()';

CREATE OR REPLACE FUNCTION split_bytea(
	bytea, _max_ integer = max_blob_chunk_size()
) RETURNS bytea[] AS $$
	SELECT ARRAY(
		SELECT substring($1 from n for _max_)
		FROM generate_series(1, octet_length($1), _max_) n
	)
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION get_blob_chunks(bytea) RETURNS hash_arrays AS $$
	SELECT ARRAY(
		SELECT get_blob_chunk(chunk)::uuid
		FROM unnest(split_bytea($1)) chunk
	)::hash_arrays
$$ LANGUAGE sql;

COMMENT ON FUNCTION get_blob_chunks(bytea) IS
'return array of hashes indexing the chunk(s) of the
supplied argument, splitting and creating as necessary;
are we good with catching any NULLs??';

CREATE OR REPLACE
FUNCTION try_get_blob(bytea) RETURNS blob_refs AS $$
	DECLARE
		_hash hashes := hash($1);
		_ref blob_refs := NULL; -- unchecked_ref_null();
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_blob(bytea)';
	BEGIN
		LOOP
			SELECT ref INTO _ref FROM blob_rows WHERE hash_ = _hash;
			IF FOUND THEN RETURN _ref; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with %', this, _hash;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO blob_rows(hash_, chunks) VALUES(_hash, get_blob_chunks($1));
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % raised %!', this, _hash, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_blob(bytea) RETURNS blob_refs AS $$
	SELECT non_null(	try_get_blob($1),	'get_blob(bytea)'	)
$$ LANGUAGE sql;

COMMENT ON FUNCTION get_blob(bytea) IS
'return ref associated with blob, creating row
and chunks as necessary';

-- *** testing blobs a bit

DELETE FROM blob_rows;
DELETE FROM blob_chunks;

CREATE OR REPLACE FUNCTION bytea_copies(
	n integer, b bytea
) RETURNS bytea AS $$
	SELECT CASE
		WHEN n <= 0 THEN	''::bytea
		WHEN n = 1 THEN b
		ELSE (
			SELECT db || db || bytea_copies(n - half - half, b)
			FROM bytea_copies(half, b) db
	 )
	END FROM COALESCE( n / 2 ) half
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION deadbeef(
	n integer = 8, b bytea = 'deadbeef'
) RETURNS bytea AS $$
	SELECT bytea_copies( _div, b ) ||	substring(b FROM 1 FOR _mod)	FROM
		octet_length(b) nb,
		COALESCE( n / nb ) _div,
		mod( n, nb ) _mod
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION deadbeef(integer, bytea)
IS 'return $1 bytes from bytea value "deadbeef"
duplicating the value as necessary to get enough bytes;
intended for use in testing bytea storage stragegies';

SELECT blob_rows_ref(
	'deadbeef', get_blob( deadbeef(8) )
)::refs;

SELECT test_func(
	'blob_length(blob_refs)', 8::bigint,
	blob_length(blob_rows_ref('deadbeef'))
);

SELECT test_func(
	'blob_num_chunks(blob_refs)', 1,
	blob_num_chunks(blob_rows_ref('deadbeef'))
);

SELECT test_func(
	'blob_bytes(blob_refs)', deadbeef(8),
	blob_bytes(blob_rows_ref('deadbeef'))
);

SELECT blob_rows_ref(
	'deadbeef-max', get_blob( deadbeef(max_blob_chunk_size()) )
)::refs;

SELECT test_func(
	'blob_length(blob_refs)', max_blob_chunk_size()::bigint,
	blob_length(blob_rows_ref('deadbeef-max'))
);

SELECT test_func(
	'blob_num_chunks(blob_refs)', 1,
	blob_num_chunks(blob_rows_ref('deadbeef-max'))
);

SELECT test_func(
	'blob_bytes(blob_refs)', deadbeef(max_blob_chunk_size()),
	blob_bytes(blob_rows_ref('deadbeef-max'))
);

SELECT blob_rows_ref(
	'deadbeef-max+1', get_blob( deadbeef(max_blob_chunk_size()+1) )
)::refs;

SELECT test_func(
	'blob_length(blob_refs)', (max_blob_chunk_size() + 1)::bigint,
	blob_length(blob_rows_ref('deadbeef-max+1'))
);

SELECT test_func(
	'blob_num_chunks(blob_refs)', 2,
	blob_num_chunks(blob_rows_ref('deadbeef-max+1'))
);

SELECT test_func(
	'blob_bytes(blob_refs)', deadbeef(max_blob_chunk_size()+1),
	blob_bytes(blob_rows_ref('deadbeef-max+1'))
);

-- *** registering blob methods

SELECT type_class_op_method(
	'blob_refs', 'blob_rows',
	'ref_text_op(refs)', 'blob_text(blob_refs)'
);

SELECT type_class_op_method(
	'blob_refs', 'blob_rows',
	'ref_length_op(refs)', 'blob_length(blob_refs)'
);

-- ** TABLE text_join_tree_rows

-- +++ text_join_tree_text(text_refs) -> text
CREATE OR REPLACE
FUNCTION text_join_tree_text(text_refs) RETURNS text AS $$
	SELECT  array_to_string( ARRAY(
	SELECT ref_text_op(item) FROM unnest(branches) item
	), join_ ) FROM text_join_tree_rows
	WHERE ref = non_null($1, 'text_join_tree_text(text_refs)')
$$ LANGUAGE SQL VOLATILE;
COMMENT ON FUNCTION text_join_tree_text(text_refs) IS
'compute the text value; needs to be volatile in order to
access newly-created elements of the branches!';

-- +++ text_join_tree_to_len(text_refs) -> text
CREATE OR REPLACE
FUNCTION text_join_tree_length(text_refs) RETURNS bigint AS $$
	SELECT length_ FROM text_join_tree_rows
	WHERE ref = non_null($1, 'text_join_tree_text(text_refs)')
$$ LANGUAGE SQL STABLE;
COMMENT ON FUNCTION text_join_tree_length(text_refs) IS
'return length of text_join_tree associated with ref,
which should exist, in bytes';

CREATE OR REPLACE
FUNCTION try_get_text_join_tree( _join text, _branches refs[])
RETURNS text_refs AS $$
	DECLARE
		_length bigint := 0;
		branches_length integer := array_length(_branches);
		maybe RECORD;
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_text_join_tree(text, refs[])';
	BEGIN
		FOR i IN array_lower(_branches, 1) .. array_upper(_branches, 1)
		LOOP
			IF _branches[i] IS NULL THEN
					RAISE EXCEPTION '% branch % IS NULL!', this, i;
			END IF;
			_length := _length + ref_length_op( _branches[i] );
		END LOOP;
		IF ( branches_length > 1 ) THEN
			_length := _length + (branches_length - 1) * octet_length(_join);
		END IF;
		LOOP
			SELECT * INTO maybe FROM text_join_tree_rows
			WHERE join_ = _join AND branches = _branches;
			IF FOUND THEN RETURN maybe.ref; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with % %', this, $1, $2;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO text_join_tree_rows(length_, join_, branches)
				VALUES (_length, _join, _branches);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_text_join_tree( _join text, VARIADIC _branches refs[])
RETURNS text_refs AS $$
	SELECT non_null(
		try_get_text_join_tree($1, $2), 'get_text_join_tree(text, refs[])'
	)
$$ LANGUAGE sql;

-- ** TABLE text_format_tree_rows

-- +++ text_format_tree_text(text_refs) -> text
CREATE OR REPLACE
FUNCTION text_format_tree_text(text_refs)
RETURNS text AS $$
	SELECT
		array_join( ARRAY(
			SELECT
				CASE i % 2
					WHEN 1 THEN formats[(i+1)/2]
					WHEN 0 THEN ref_text_op(branches[i/2])
				END
			FROM generate_series(
				1, array_length(formats) + array_length(branches)
			) i
		), '' )
	FROM text_format_tree_rows, text_tree_formats
	WHERE ref=non_null($1, 'text_format_tree_text(text_refs)')
		AND id=format_id
$$ LANGUAGE SQL;
COMMENT ON FUNCTION text_format_tree_text(text_refs) IS
'When the format element and the value elements are of equal number,
which should come out first??  Right now it''s the value elements.';

-- +++ text_format_tree_to_len(text_refs) -> text
CREATE OR REPLACE
FUNCTION text_format_tree_length(text_refs) RETURNS bigint AS $$
	SELECT length_ FROM text_format_tree_rows
	WHERE ref=non_null($1, 'text_format_tree_length(text_refs)')
$$ LANGUAGE SQL;
COMMENT ON FUNCTION text_format_tree_length(text_refs) IS
'return length of text_format_tree associated with ref,
which should exist, in bytes';

CREATE OR REPLACE
FUNCTION try_text_format_length(format_id integer)
RETURNS integer AS $$
	SELECT octet_length( array_to_string(formats, '') )
	FROM text_tree_formats WHERE id = $1
$$ LANGUAGE SQL STRICT STABLE;

CREATE OR REPLACE
FUNCTION text_format_length(format_id integer)
RETURNS integer AS $$
	SELECT non_null(
		try_text_format_length($1), 'text_format_length(integer)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_get_text_format(text[]) RETURNS integer AS $$
	DECLARE
		maybe RECORD;
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_text_format(text[])';
	BEGIN
		LOOP
			SELECT * INTO maybe FROM text_tree_formats WHERE formats = $1;
			IF FOUND THEN RETURN maybe.id; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with %', this, $1;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO text_tree_formats(formats) VALUES ($1);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_text_format(VARIADIC text[]) RETURNS integer AS $$
	SELECT non_null(
		try_get_text_format($1), 'get_text_format(text[])'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION try_get_text_format_tree(
	_format_id integer, _branches refs[]
) RETURNS text_refs AS $$
	DECLARE
		_length integer := text_format_length(_format_id);
		maybe RECORD;
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_text_format_tree(integer, refs[])';
	BEGIN
		FOR i IN array_lower(_branches,1)..array_upper(_branches,1)
		LOOP
			_length := _length + ref_length_op( _branches[i] );
		END LOOP;
		LOOP
			SELECT * INTO maybe FROM text_format_tree_rows
				WHERE format_id = _format_id AND branches = _branches;
			IF FOUND THEN RETURN maybe.ref; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with % %', this, $1, $2;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO text_format_tree_rows(length_, format_id, branches)
				VALUES (_length, _format_id, _branches);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_text_format_tree( integer, VARIADIC refs[])
RETURNS text_refs AS $$
	SELECT non_null(
		try_get_text_format_tree($1, $2),
		'get_text_format_tree( integer, refs[])'
	)
$$ LANGUAGE sql;

-- * register class text_join_tree_rows

-- SELECT type_class_out(
-- 	'text_refs', 'text_join_tree_rows',
-- 	'text_join_tree_text(text_refs)'
-- );

SELECT type_class_op_method(
	'text_refs', 'text_join_tree_rows',
	'ref_text_op(refs)', 'text_join_tree_text(text_refs)'
);

SELECT type_class_op_method(
	'text_refs', 'text_join_tree_rows',
	'ref_length_op(refs)', 'text_join_tree_length(text_refs)'
);

-- * register class text_format_tree_rows

-- SELECT type_class_out(
-- 	'text_refs', 'text_format_tree_rows',
-- 	'text_format_tree_text(text_refs)'
-- );

SELECT type_class_op_method(
	'text_refs', 'text_format_tree_rows',
	'ref_text_op(refs)', 'text_format_tree_text(text_refs)'
);

SELECT type_class_op_method(
	'text_refs', 'text_format_tree_rows',
	'ref_length_op(refs)', 'text_format_tree_length(text_refs)'
);

-- * text_refs_ready

CREATE OR REPLACE
FUNCTION text_refs_ready() RETURNS void AS $$
BEGIN
	PERFORM s1_refs.ensure_schema_ready();
-- Check sufficient elements of the Text_Refs
-- dependency tree that we can be assured that
-- all of its modules have been loaded.
--	PERFORM require_module('s3_more.text_refs-code');
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION text_refs_ready() IS '
	Ensure that all modules of the text_refs schema
	are present and initialized.
';

CREATE OR REPLACE
FUNCTION ensure_schema_ready() RETURNS regprocedure AS $$
	SELECT text_refs_ready();
	SELECT 'text_refs_ready()'::regprocedure
$$ LANGUAGE sql;
