-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('text_refs-schema.sql', '$Id');

--	Wicci Project Virtual Text Schema

-- ** Copyright

--	Copyright (c) 2005, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Text and Bytea Values, Size Limits & Hashes

-- See text_refs-notes.text for more information.

-- A Text Value is either a Leaf or some kind of Tree.
-- All Leaf objects can cheaply compute their length

-- Some Great Things no longer exist here as the
-- evolution of the WIcci no longer required them:
-- Molecules, i.e. text templates which can be
-- instatiated with value vectors to fulfill the
-- contracts on template slots.
-- Richer Text, i.e. Text Values with embedded
-- Environment references giving context for
-- rendering and interpreting the text.

-- ** Media Types

-- We need to know, for any hunk of bytes that is part of a document,
-- what kind of thing it represents, how it is encoded (this is often layered)
-- how we're supposed to refer to its type on output and how we're
-- supposed to recognize its type when we read it.

-- Syntax of Media Type:
-- top-level type name / [ tree. ] subtype name [ +suffix ] [ ; parameters ]

-- Example syntax in an HTTP header:
-- Content-Type: text/html; charset=ISO-8859-4

-- Example in a web page:
-- <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />

-- We should be able to greatly simplify the representations internally by
-- undoing some transfer encodings, e.g. hex, cgi-encoded text, etc.
-- leaving some transfer-encoded values uninterpreted
-- converting all text formats to utf8

DROP TYPE IF EXISTS media_type_major CASCADE;

CREATE TYPE media_type_major AS ENUM (
  '_',													-- none, nil
  'application', 'audio', 'example', 'image', 'message',
	'model', 'multipart', 'text', 'video'
);

DROP TYPE IF EXISTS media_type_tree CASCADE;

CREATE TYPE media_type_tree AS ENUM (
  '_',													-- none, nil
  'standard',										-- not shown
  'vendor',										-- vnd. tree
  'personal',									-- aka vanity
  'unregistered'							-- x. tree
);

COMMENT ON TYPE media_type_tree IS
'Do we need "_" as well as "standard"??';

DROP TYPE IF EXISTS media_type_suffix CASCADE;

CREATE TYPE media_type_suffix AS ENUM (
  '_',													-- none, nil
  'xml', 'json', 'ber', 'der', 'fastinfoset',
  'wbxml', 'zip', 'cbor'
);

DROP TYPE IF EXISTS pg_text_encodings CASCADE;

-- pg really should have an official enum for this!
CREATE TYPE pg_text_encodings AS ENUM (
	'_',			-- none, nil
  'BIG5',				-- 	Big Five, Traditional Chinese, WIN950, Windows950
  'EUC_CN',		-- 	Extended UNIX Code-CN, Simplified Chinese
  'EUC_JP',			-- 	Extended UNIX Code-JP, Japanese
  'EUC_JIS_2004',	-- 	Extended UNIX Code-JP, JIS X 0213,	Japanese
  'EUC_KR',			-- 	Extended UNIX Code-KR, Korean
  'EUC_TW',			-- 	Extended UNIX Code-TW,	Traditional Chinese, Taiwanese
  'GB18030',		-- 	National Standard,	Chinese
  'GBK',			-- 	Extended National Standard, Simplified Chinese, WIN936, Windows936
  'ISO_8859_5',		-- 	ISO 8859-5, ECMA 113, Latin/Cyrillic
  'ISO_8859_6',		-- 	ISO 8859-6, ECMA 114, Latin/Arabic
  'ISO_8859_7',		-- 	ISO 8859-7, ECMA 118, Latin/Greek
  'ISO_8859_8',		-- 	ISO 8859-8, ECMA 121, Latin/Hebrew
  'JOHAB',			-- 	JOHAB 	Korean (Hangul)
  'KOI8R',			-- 	KOI8-R 	Cyrillic (Russian), 	KOI8
  'KOI8U',			-- 	KOI8-U 	Cyrillic (Ukrainian)
  'LATIN1',		-- 	ISO 8859-1, ECMA 94 	Western European
  'LATIN2',		-- 	ISO 8859-2, ECMA 94 	Central European
  'LATIN3',		-- 	ISO 8859-3, ECMA 94 	South European
  'LATIN4',		-- 	ISO 8859-4, ECMA 94 	North European
  'LATIN5',		-- 	ISO 8859-9, ECMA 128 	Turkish
  'LATIN6',		-- 	ISO 8859-10, ECMA 144 	Nordic
  'LATIN7',		-- 	ISO 8859-13 	Baltic
  'LATIN8',		-- 	ISO 8859-14 	Celtic
  'LATIN9',		-- 	ISO 8859-15 	LATIN1 with Euro and accents
  'LATIN10',	-- 	ISO 8859-16, ASRO SR 14111 	Romanian
  'MULE_INTERNAL',	-- 	Mule internal code 	Multilingual Emacs
  'SJIS',			-- 	Shift JIS, 	Japanese, Mskanji, ShiftJIS, WIN932, Windows932
  'SHIFT_JIS_2004',	-- 	Shift JIS, JIS X 0213, 	Japanese
  'SQL_ASCII',		-- 	interpretation of any non-7-bit values unspecified
  'UHC',			-- 	Unified Hangul Code, Korean,	WIN949, Windows949
  'UTF8',			-- 	Unicode, 8-bit encoded
  'WIN866',			-- 	Windows CP866, Cyrillic
  'WIN874',			-- 	Windows CP874, Thai
  'WIN1250',		-- 	Windows CP1250, Central European
  'WIN1251',		-- 	Windows CP1251, Cyrillic
  'WIN1252',		-- 	Windows CP1252, Western European
  'WIN1253',		-- 	Windows CP1253, Greek
  'WIN1254',		-- 	Windows CP1254, Turkish
  'WIN1255',		-- 	Windows CP1255, Hebrew
  'WIN1256',		-- 	Windows CP1256, Arabic
  'WIN1257',		-- 	Windows CP1257, Baltic
  'WIN1258'		-- 	Windows CP1258, Vietnamese,	ABC, TCVN, TCVN5712, VSCII
);

SELECT create_ref_type('media_type_refs');

CREATE TABLE IF NOT EXISTS media_type_rows (
	ref media_type_refs PRIMARY KEY,
	major_ media_type_major NOT NULL,	
	tree_ media_type_tree NOT NULL,	
	minor_ text NOT NULL,						-- depends on tree_
  suffix_ media_type_suffix NOT NULL,
  charset_ text NOT NULL,
  encoding_ pg_text_encodings NOT NULL,
  misc_ hstore NOT NULL,
	UNIQUE(major_, tree_, minor_, suffix_, charset_, encoding_, misc_)
);

COMMENT ON TABLE media_type_rows IS '
  A Media Type for, e.g. HTTP & HTML as well as
  the PostgreSQL character encoding when the
  representation is text.
';

COMMENT ON COLUMN media_type_rows.minor_ IS '
  A subtype name dependent on the major_ type
  and the registration tree_
';

COMMENT ON COLUMN media_type_rows.misc_ IS
'field_name (w/o _) => non-standard value of that field,
	regular field value should be nil;
params => parameter(s) other than charset
';

SELECT declare_ref_class_with_funcs('media_type_rows');
SELECT create_simple_serial('media_type_rows');

INSERT INTO media_type_rows ( ref, major_, tree_, minor_, suffix_, charset_, encoding_, misc_ )
VALUES(media_type_nil(), '_', '_', '', '_', '', '_', '');

-- ** Size Limits

-- While PostgreSQL allows text and bytea values to be
-- very large, if they're more than a third of a buffer page
-- they can't be indexed!!
-- Is there a portable way of obtaining that cutoff size???

CREATE OR REPLACE
FUNCTION max_indexable_field_size() RETURNS integer AS $$
	SELECT 2712
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION max_indexable_field_size()
IS 'PostgreSQL does not allow btree indices on fields above 1/3 of
a buffer page, i.e. 2712 bytes.';

CREATE OR REPLACE
FUNCTION max_blob_chunk_size() RETURNS integer AS $$
	SELECT max_indexable_field_size() -- adjust for best performance
$$ LANGUAGE SQL IMMUTABLE;

COMMENT ON FUNCTION max_blob_chunk_size()
IS 'Large text or bytea values are broken up into chunks of
at most this size; adjust for best performance.';

-- ** Hashes

-- text or bytea fields larger than max_indexable_field_size() need
-- to be indexed indirectly through hashes:

/*
 Blobs can be text or binary data and are always encoded as bytea.
 Whoever stores something in a blob needs to know what it
 represents!!  If it's really just text, recover it with
	encode(bytea_value, 'escape') --> text
 and backslash codes will quote non-printing characters.
 */

/* From https://stackoverflow.com/questions/15982737/postgresql-data-type-for-md5-message-digest
md5('my_string') --> 32 hex characters of text
decode(md5('my_string'), 'hex') --> 16 bytes of bytea
digest('my_string', 'md5') same as last but requires:
create extension pgcrypto;

To avoid bytea one byte overhead + padding to eight bytes
we can (kludge-alert!!) use the uuid type, also 16 bytes.
"uuid"s will print with dashes when cast to text, so:
md5('my_string')::uuid -> uuid
REPLACE(md5_uuid::text, '-', '') -> text
REPLACE(md5_uuid::text, '-', '')::bytea -> bytea
See the hash functions in text-ref-code.sql
*/

-- CREATE DOMAIN hashes AS char(32); -- extra overhead
-- CREATE DOMAIN hashes AS bytea;  -- extra overhead
CREATE DOMAIN hashes AS uuid; -- efficient & convenient kludge??
CREATE DOMAIN hash_arrays AS uuid[]; -- efficient & convenient kludge??

CREATE OR REPLACE
FUNCTION hash_nil()
RETURNS hashes AS $$
	SELECT '00000000000000000000000000000000'::uuid::hashes
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION hash(bytea) RETURNS hashes AS $$
	SELECT md5($1)::uuid::hashes
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION hash(text) RETURNS hashes AS $$
	SELECT md5($1)::uuid::hashes
$$ LANGUAGE SQL;

-- Text is coming soon, but first: Blobs!

-- ** Blobs - Binary Large Objects

-- blob_refs manage sequence of bytes, much like
-- bytea, without running afoul of PostgreSQL's
-- max_indexable_field_size().  LIke bytea they avoid
-- the prohibition of certain characters, e.g. ASCII NUL,
-- and the complexities of character set encodings.
-- Blobs cannot be directly rendered as text.
-- From the viewpoint of the Wicci, Blobs are
-- opaque values which are passed to clients
-- in binary chunks when requested.

-- It would be great to be able to associate
-- a mime type with blob rows and for text
-- types, a character encoding.

SELECT create_ref_type('blob_refs');

CREATE TABLE IF NOT EXISTS blob_rows (
	ref blob_refs PRIMARY KEY,
	hash_ hashes NOT NULL UNIQUE,
	chunks hash_arrays NOT NULL -- CHECK(array_length(chunks, 1) > 0) -- ???
);
COMMENT ON TABLE blob_rows IS '
	unique typed text blobs with unique refs;
	their refs may not be shared with other processes;
	they may be aggressively garbage collected
';
COMMENT ON COLUMN blob_rows.hash_ IS '
	The nil_blob() should have a nil ref, no chunks, value of '''', hash_('''') -- ???
  When length(chunks) == 1, it''s just chunks[1]->hash_;
  Otherwise it''s a hash of the contents of the chunks array.
	Hmm, would it be better to have it be a hash of the
	whole byte value of the blob???  This might be more
	stable over the evolution of this code???
';

SELECT create_handles_for('blob_rows');

CREATE TABLE IF NOT EXISTS blob_chunks (
	hash_ hashes PRIMARY KEY,
	chunk_ bytea NOT NULL,				-- indirectly unique!
	CHECK ( length(chunk_) <= max_blob_chunk_size() )
);

COMMENT ON TABLE blob_chunks IS '
	unique byte array blobs indexed by their hashes;
	not too big to efficiently transmit to clients;
	can be part of larger blobs	referenced	by blob_rows.
';

SELECT declare_ref_class_with_funcs('blob_rows');
SELECT create_simple_serial('blob_rows');

INSERT INTO blob_rows (ref, hash_, chunks) VALUES(blob_nil(), hash(''), '{}');

-- ** type text_refs

SELECT create_ref_type('text_refs');

-- * key table and abstract base classes

CREATE TABLE IF NOT EXISTS text_keys (
	key text_refs PRIMARY KEY
);

SELECT create_handles_for('text_keys');
SELECT create_key_trigger_functions_for('text_keys');

-- **  TABLE abstract_text_rows(ref text_refs) -- ABSTRACT BASE
CREATE TABLE IF NOT EXISTS abstract_text_rows (
	ref text_refs
);
COMMENT ON TABLE abstract_text_rows IS
'unique references for any kind of data,
which can be cheaply rendered as text;
this is an abstract base class';

SELECT declare_abstract('abstract_text_rows');
SELECT declare_ref_type_class('text_refs', 'abstract_text_rows');

-- * id management

CREATE OR REPLACE
FUNCTION unchecked_text_from_class_id(regclass, ref_ids)
RETURNS text_refs AS $$
	SELECT unchecked_ref('text_refs', $1, $2)::text_refs
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION text_nil() RETURNS text_refs AS $$
	SELECT unchecked_text_from_class_id(
		'abstract_text_rows',  0
	)
$$ LANGUAGE SQL IMMUTABLE;

INSERT INTO text_keys VALUES (text_nil());

DROP SEQUENCE IF EXISTS text_id_seq CASCADE;

CREATE SEQUENCE text_id_seq
	OWNED BY abstract_text_rows.ref
	MINVALUE 1 MAXVALUE :RefIdMax CYCLE;

CREATE OR REPLACE
FUNCTION next_text(regclass) RETURNS text_refs AS $$
	SELECT unchecked_text_from_class_id(
		$1, nextval('text_id_seq')::ref_ids
	)
$$ LANGUAGE SQL;

-- ** abstract_text_string_rows

CREATE TABLE IF NOT EXISTS abstract_text_string_rows (
	PRIMARY KEY (ref),
	string_ TEXT NOT NULL
) INHERITS(abstract_text_rows);
COMMENT ON TABLE abstract_text_string_rows IS '
	unique typed text strings with unique refs;
	their refs may not be shared with other processes;
	they may be aggressively garbage collected
';

SELECT declare_abstract('abstract_text_string_rows');

-- * Concrete Leaf Classes

-- ** TABLE small_text_string_rows(ref text_refs,  string_ text)

CREATE TABLE IF NOT EXISTS small_text_string_rows (
	PRIMARY KEY (ref),
	UNIQUE(string_),
	CHECK ( length(string_) <= max_indexable_field_size() )
) INHERITS(abstract_text_string_rows);
COMMENT ON TABLE small_text_string_rows IS '
	Unique Text strings no larger than max_indexable_field_size()
';

ALTER TABLE small_text_string_rows ALTER COLUMN ref
	SET DEFAULT next_text( 'small_text_string_rows' );

SELECT create_key_triggers_for('small_text_string_rows', 'text_keys');
SELECT declare_ref_class('small_text_string_rows');

-- ** TABLE big_text_string_rows(ref text_refs,  string_ text)

CREATE TABLE IF NOT EXISTS big_text_string_rows (
	PRIMARY KEY (ref),
	hash_ hashes NOT NULL UNIQUE,
	CHECK ( length(string_) > max_indexable_field_size() )
) INHERITS(abstract_text_string_rows);
COMMENT ON TABLE big_text_string_rows IS '
	Text strings larger than max_indexable_field_size()
	Indirectly unique via md5 hashes.
';

ALTER TABLE big_text_string_rows ALTER COLUMN ref
	SET DEFAULT next_text( 'big_text_string_rows' );

SELECT create_key_triggers_for('big_text_string_rows', 'text_keys');
SELECT declare_ref_class('big_text_string_rows');

-- *  Text_Refs Tree Classes

-- consider changing branches to be refs[] with
-- the constraint of supporting ref_text!!!

CREATE OR REPLACE
FUNCTION text_branches_check(refs[]) RETURNS boolean AS $$
	SELECT CASE WHEN x IS NULL THEN false
	ELSE refs_op_tag_to_method(
		'ref_text_op(refs)', ref_tag(x)
	) IS NOT NULL
	END
	FROM unnest($1) x
$$ LANGUAGE SQL;

-- ** TABLE abstract_text_tree_rows(ref)
CREATE TABLE IF NOT EXISTS abstract_text_tree_rows (
	length_ bigint,
--  branches text_refs[] NOT NULL CHECK( array_has_no_nulls(branches) )
	branches refs[] NOT NULL CHECK( text_branches_check(branches) )
) INHERITS(abstract_text_rows);

SELECT declare_abstract('abstract_text_tree_rows');

-- * text_join_tree_rows

-- ** TABLE text_join_tree_rows(ref, length_, branches _text, join_ text_refs)
CREATE TABLE IF NOT EXISTS text_join_tree_rows (
	PRIMARY KEY (ref),
	join_ text NOT NULL,
	UNIQUE(branches, join_)
) INHERITS(abstract_text_tree_rows);
COMMENT ON TABLE text_join_tree_rows IS
'represents a text value by an array of text values along with a
string to join them';

ALTER TABLE text_join_tree_rows ALTER COLUMN ref
	SET DEFAULT next_text( 'text_join_tree_rows' );

SELECT create_key_triggers_for('text_join_tree_rows', 'text_keys');
SELECT declare_ref_class('text_join_tree_rows');

-- * text_format_tree_rows

CREATE TABLE IF NOT EXISTS text_tree_formats (
	id serial PRIMARY KEY,
	formats text[] UNIQUE NOT NULL
	CHECK( array_has_no_nulls(formats) )
);

SELECT declare_monotonic('text_tree_formats');
SELECT create_handles_for('text_tree_formats');

CREATE OR REPLACE FUNCTION text_format_dim_ok(
	format_id integer, num_branches integer
) RETURNS boolean AS $$
	SELECT array_length(formats) - $2 <= 1
	FROM text_tree_formats WHERE id=$1
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION text_format_dim_ok(integer, integer) IS
'Are there enough and not too many format elements to format the
branches?';

-- ** TABLE text_format_tree_rows(ref, length_, branches, format_id)
CREATE TABLE IF NOT EXISTS text_format_tree_rows (
	PRIMARY KEY (ref),
	format_id integer NOT NULL REFERENCES text_tree_formats,
	CONSTRAINT text_format_tree_rows_correspondence
		 CHECK( text_format_dim_ok(format_id, array_length(branches)) ),
	UNIQUE(branches, format_id)
) INHERITS(abstract_text_tree_rows);
COMMENT ON TABLE text_format_tree_rows IS
'branches  interleaved with the format array';

ALTER TABLE text_format_tree_rows ALTER COLUMN ref
	SET DEFAULT next_text( 'text_format_tree_rows' );

SELECT create_key_triggers_for('text_format_tree_rows', 'text_keys');
SELECT declare_ref_class('text_format_tree_rows');

-- * Operations

-- oftd !!!
CREATE OR REPLACE FUNCTION oftd_ref_env_crefs_length_op(
	regprocedure, refs[], refs[], refs, refs, env_refs, crefs
) RETURNS :WordIntsPG
AS 'spx.so', 'oftd_ref_env_crefs_etc_scalar_op'
LANGUAGE c STABLE;

-- oftd !!!
CREATE OR REPLACE FUNCTION oftd_ref_env_crefs_chiln_length_op(
	regprocedure, refs[], refs[], refs, refs, env_refs, crefs, refs[]
) RETURNS :WordIntsPG
AS 'spx.so', 'oftd_ref_env_crefs_etc_scalar_op'
LANGUAGE c STABLE;

CREATE OR REPLACE
FUNCTION env_length_op(refs, env_refs) RETURNS :WordIntsPG
AS 'spx.so', 'call_scalar_method'  LANGUAGE c STABLE;

SELECT declare_op_fallback(
	'env_length_op(refs, env_refs)',
	'ref_length_op(refs)'
);

CREATE OR REPLACE
FUNCTION ref_env_crefs_length_op(refs, env_refs, crefs)
RETURNS :WordIntsPG
AS 'spx.so', 'ref_env_crefs_etc_scalar_op'
LANGUAGE c STABLE;

SELECT declare_op_fallback(
	'ref_env_crefs_length_op(refs, env_refs, crefs)',
	'env_length_op(refs, env_refs)'
);

CREATE OR REPLACE FUNCTION ref_env_crefs_chiln_length_op(
	refs, env_refs, crefs, refs[]
) RETURNS :WordIntsPG
AS 'spx.so', 'ref_env_crefs_etc_scalar_op'
LANGUAGE c STABLE;

SELECT declare_op_fallback(
	'ref_env_crefs_chiln_length_op(refs, env_refs, crefs, refs[])',
	'ref_env_crefs_length_op(refs, env_refs, crefs)'
);
