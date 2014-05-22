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

-- +++ text_string_to_len(text_refs) -> text
CREATE OR REPLACE
FUNCTION text_string_length(text_refs) RETURNS integer AS $$
	SELECT octet_length(string_) FROM text_string_rows
	WHERE ref = non_null($1, 'text_string_length(text_refs)')
$$ LANGUAGE SQL;
COMMENT ON FUNCTION text_string_length(text_refs) IS
'return length of text_string associated with ref,
which should exist, in bytes';

-- +++ text_string_text(text_refs) -> text
CREATE OR REPLACE
FUNCTION text_string_text(text_refs) RETURNS text AS $$
	SELECT string_ FROM text_string_rows
	WHERE ref = non_null($1, 'text_string_text(text_refs)')
$$ LANGUAGE SQL;
COMMENT ON FUNCTION text_string_text(text_refs) IS
'return text associated with ref, which should exist';

CREATE OR REPLACE
FUNCTION try_text(text)  RETURNS text_refs AS $$
	SELECT ref FROM text_string_rows WHERE string_ = $1
$$ LANGUAGE sql VOLATILE STRICT;

CREATE OR REPLACE
FUNCTION find_text(text) RETURNS text_refs AS $$
	SELECT non_null(	try_text($1),	'find_text(text)' )
$$ LANGUAGE sql VOLATILE;
COMMENT ON FUNCTION find_text(text) IS
'return unique ref associated with text argument
in the text_string_rows table, or possibly one of the others;
an index on the text values of text_refs objects would be
very helpful here!!!';

CREATE OR REPLACE
FUNCTION try_get_text(text) RETURNS text_refs AS $$
	DECLARE
		string text_refs := NULL; -- unchecked_ref_null();
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_text(text)';
	BEGIN
		LOOP
			SELECT ref INTO string FROM text_string_rows WHERE string_ = $1;
			IF FOUND THEN RETURN string; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with %', this, $1;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO text_string_rows(string_) VALUES($1);
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
	'text_refs', 'text_string_rows',
	'ref_text_op(refs)', 'text_string_text(text_refs)'
);

SELECT type_class_op_method(
	'text_refs', 'text_string_rows',
	'ref_length_op(refs)', 'text_string_length(text_refs)'
);

-- *** blob_rows functions

CREATE OR REPLACE
FUNCTION try_get_chunks_hash(blob_hash_arrays) RETURNS blob_hashes AS $$
	SELECT	md5(
		array_to_string(
			ARRAY( SELECT replace(x::text, '-', '') FROM unnest($1) x ),
			'')
	)::uuid::blob_hashes
$$ LANGUAGE SQL STRICT;

COMMENT ON FUNCTION try_get_chunks_hash(blob_hash_arrays)
IS 'It would be better to use a hash of the entire content -
which can now be passed in to get_static_doc and
get_static_xfiles_page if doc-to-sql can be made to provide
it!!!';

CREATE OR REPLACE
FUNCTION get_chunks_hash(blob_hash_arrays) RETURNS blob_hashes AS $$
	SELECT non_null(
		try_get_chunks_hash($1), 'try_get_chunks_hash(blob_hash_arrays)'
	)
$$ LANGUAGE SQL;

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

-- +++ blob_text(blob_refs) -> text
CREATE OR REPLACE
FUNCTION blob_text(blob_refs) RETURNS text AS $$
	SELECT 'blob'::text WHERE false
$$ LANGUAGE SQL;
COMMENT ON FUNCTION blob_text(blob_refs) IS
'we need a convenient way to deal with blob values as a sequence';

DELETE FROM blob_chunks;
DELETE FROM blob_rows;

INSERT INTO blob_chunks(hash_, chunk_)
SELECT md5(x)::blob_hashes, x
FROM unnest(ARRAY(
	SELECT decode(h::text, 'hex'::text)
	FROM unnest(ARRAY[ 'dead', 'beef' ]) h
)) x;

INSERT INTO blob_rows (hash_, chunks)
SELECT blob_hash('deadbeef'::bytea), ARRAY(SELECT hash_::uuid FROM blob_chunks)::blob_hash_arrays;

CREATE OR REPLACE
FUNCTION blob_bytes(blob_refs) RETURNS bytea AS $$
	SELECT string_agg(x, ''::bytea)	FROM
		blob_rows r,
		unnest(ARRAY(
		SELECT c.chunk_ FROM blob_chunks c, blob_rows r, LATERAL unnest(r.chunks) h
		WHERE r.ref = $1 AND c.hash_ = h
	)) x
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
	AND c.hash_ = r.chunks[$2]::blob_hashes
$$ LANGUAGE SQL;
COMMENT ON FUNCTION blob_chunk(blob_refs, integer) IS
'return contents of specified chunk of specified blob which must exist';

DELETE FROM blob_chunks;
DELETE FROM blob_rows;

CREATE OR REPLACE
FUNCTION try_get_blob_chunk(bytea) RETURNS blob_hashes AS $$
	DECLARE
		hash blob_hashes := NULL;
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_blob_chunk(bytea)';
	BEGIN
		LOOP
			SELECT hash_ INTO hash FROM blob_chunks WHERE chunk_ = $1;
			IF FOUND THEN RETURN hash; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with %', this, $1;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO blob_chunks(hash_, chunk_) VALUES(blob_hash($1), $1);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT VOLATILE;
COMMENT ON FUNCTION try_get_text(text) IS
'return unique hash associated with typea argument
in the blob_chunks table, creating it if necessary';

CREATE OR REPLACE
FUNCTION try_get_blob(blob_hash_arrays) RETURNS blob_refs AS $$
	DECLARE
		blob blob_refs := NULL; -- unchecked_ref_null();
		kilroy_was_here boolean := false;
		this regprocedure := 'try_get_blob(blob_hash_arrays)';
	BEGIN
		LOOP
			SELECT ref INTO blob FROM blob_rows WHERE chunks = $1;
			IF FOUND THEN RETURN blob; END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping with %', this, $1;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO blob_rows(hash_, chunks) VALUES(get_chunks_hash($1), $1);
			EXCEPTION
				WHEN unique_violation THEN			-- another thread??
					RAISE NOTICE '% % raised %!', this, $1, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql STRICT VOLATILE;
COMMENT ON FUNCTION try_get_text(text) IS
'return unique ref associated with blob chunks array
in the blob_rows table, creating it if necessary';

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
				RAISE EXCEPTION '% looping with % %', this, $1;
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
	PERFORM refs_ready();
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
